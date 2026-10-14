"""
Prints each SDK route's attempts from attempts.jsonl with the gap since the previous attempt, and
the gap the SDK should have waited. Usage: report.py <attempts.jsonl> [route regex]

Expected gaps model the SDK's two retry layers:
  - OneSignalClient re-sends a 5xx or status 0 up to 4 times itself (5, 15, 45, 135s). The count
    lives on the request object, so a request only gets those once per run.
  - Then the executor backs off: 5s doubling to 300s, times jitter in [0.5, 1]. Retry-After, or
    60s for a 429 without one, is the minimum. Executors resend on the operation repo's 5s poll,
    so up to 5s more is allowed.
Attempts are grouped by method and path with IDs stripped, so separate requests on one route in
the same window (two logins, a session update and a tag) share one series.
A foreground or network return ends an executor backoff early, so short gaps after those are fine.
"""

import json
import re
import sys
from collections import OrderedDict

CLIENT_DELAYS = [5, 15, 45, 135]
POLL_SLACK = 5.5
CLOCK_SLACK = 1.0
# Login's Identify User shares PATCH .../identity with Add Aliases, so it is labeled a repo executor.
USER_EXECUTOR = re.compile(r"^POST apps/[^/]+/users$|^GET apps/[^/]+/users/by/[^/]+/[^/]+$|^GET apps/[^/]+/subscriptions/[^/]+/user/identity$")
# Leaves out the in-app message fetch under users/by/, which has retries of its own.
EXECUTOR_ROUTE = re.compile(r"^(?!.*/iams$)apps/[^/]+/(users(/by/.*)?|subscriptions/[^/]+(/user/identity)?|custom_events)$")
ID_SEGMENT = re.compile(r"(by/[^/]+/|subscriptions/)[^/]+")


def route_key(entry):
    path = ID_SEGMENT.sub(r"\1:id", entry["path"])
    return f"{entry['method']} {path}"


def is_user_executor(entry):
    return bool(USER_EXECUTOR.search(f"{entry['method']} {entry['path']}"))


def executor_window(failures, status, retry_after):
    exponential = min(5 * 2 ** (failures - 1), 300)
    low, high = exponential * 0.5, exponential
    floor = None
    if retry_after is not None:
        try:
            floor = min(max(float(retry_after), 0), 3600)
        except ValueError:
            floor = 60
    elif status == 429:
        floor = 60
    if floor is not None:
        low, high = max(low, floor), max(high, floor)
    return low, high, floor is not None


def main():
    path = sys.argv[1]
    route_filter = re.compile(sys.argv[2]) if len(sys.argv) > 2 else None
    groups = OrderedDict()
    with open(path) as f:
        for line in f:
            if line.strip():
                entry = json.loads(line)
                groups.setdefault(route_key(entry), []).append(entry)

    if not groups:
        print("No SDK requests recorded yet.")
        return

    for key, entries in groups.items():
        if route_filter and not route_filter.search(key):
            continue
        if not EXECUTOR_ROUTE.search(entries[0]["path"]):
            continue
        repo = not is_user_executor(entries[0])
        print(f"\n{key}  ({'repo executor' if repo else 'User executor'})")
        print(f"  {'#':>3} {'time':>8} {'status':>6} {'body':>8} {'gap':>8} {'expected':>16}  note")
        client_retries = 0
        executor_failures = 0
        expected = None
        start = entries[0]["t"]
        for i, entry in enumerate(entries):
            gap = entry["t"] - entries[i - 1]["t"] if i else None
            note = ""
            if expected and gap is not None:
                low, high, kind = expected
                if gap < low - CLOCK_SLACK:
                    note = f"EARLY ({kind})"
                    if kind.startswith("executor") and not kind.endswith("Retry-After"):
                        note += "; fine if right after a foreground or network return"
                elif gap > high + CLOCK_SLACK:
                    note = f"LATE ({kind})"
                else:
                    note = kind
            elif gap is not None:
                note = "new attempt after success"
            expected_text = f"{expected[0]:.1f}-{expected[1]:.1f}s" if expected else ""
            gap_text = f"{gap:.1f}s" if gap is not None else ""
            mark = "*" if entry["injected"] else " "
            print(f"  {i + 1:>3} {entry['t'] - start:>7.1f}s {entry['status']:>5}{mark} {entry.get('body', ''):>8} {gap_text:>8} {expected_text:>16}  {note}")

            status = entry["status"]
            if 200 <= status < 300:
                client_retries = executor_failures = 0
                expected = None
            elif status in (400, 401, 402, 403, 404, 409, 410):
                expected = None
            elif (status >= 500 or status == 0) and client_retries < len(CLIENT_DELAYS):
                delay = CLIENT_DELAYS[client_retries]
                client_retries += 1
                expected = (delay, delay, "client reattempt")
            else:
                executor_failures += 1
                low, high, has_floor = executor_window(executor_failures, status, entry.get("retry_after"))
                high += POLL_SLACK
                kind = f"executor backoff #{executor_failures}"
                expected = (low, high, kind + (", Retry-After" if has_floor else ""))
    print("\n* = failure injected by the proxy")


if __name__ == "__main__":
    main()
