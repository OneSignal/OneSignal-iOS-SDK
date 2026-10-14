#!/usr/bin/env bash
# Fault-injection harness for manually testing SDK request retries in the demo app.
# Run `./retry-test.sh help` or see README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${RETRY_TEST_STATE_DIR:-$SCRIPT_DIR/.state}"
RULES="$STATE_DIR/rules.json"
ATTEMPTS="$STATE_DIR/attempts.jsonl"
PROXY_LOG="$STATE_DIR/proxy.log"
PID_FILE="$STATE_DIR/proxy.pid"
SAVED_PROXY="$STATE_DIR/saved-proxy"
PORT="${RETRY_TEST_PORT:-8899}"
# `system` points the Mac's HTTP(S) proxy at mitmproxy (the simulator uses the Mac's settings).
# `local` uses mitmproxy's local capture of the `App` process instead, which needs its macOS
# network extension approved once, but leaves the Mac's proxy alone.
# `manual` only listens; point a physical device's Wi-Fi proxy at this Mac yourself.
PROXY_MODE="${RETRY_TEST_PROXY_MODE:-system}"
BUNDLE_ID="${RETRY_TEST_BUNDLE_ID:-com.onesignal.example}"
# Other demos (Cordova, Capacitor, ...) share the bundle ID, so give the harness its own simulator.
DEVICE_NAME="${RETRY_TEST_DEVICE:-OneSignal Retry Test}"
IV_APP_ID="${RETRY_TEST_IV_APP_ID:-}"
IV_KEY="${RETRY_TEST_IV_KEY:-}"
CA_CERT="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"

export RETRY_TEST_STATE_DIR="$STATE_DIR"
mkdir -p "$STATE_DIR"

die() { echo "error: $*" >&2; exit 1; }

# Sets DEVICE to the UDID of DEVICE_NAME (a simulator name or UDID), booting it if needed.
resolve_device() {
  DEVICE="$(xcrun simctl list devices -j | python3 -c '
import json, sys
want = sys.argv[1]
devices = [d for r in json.load(sys.stdin)["devices"].values() for d in r if d.get("isAvailable")]
match = [d for d in devices if want in (d["udid"], d["name"])]
print(" ".join((match[0]["udid"], match[0]["state"])) if match else "")
' "$DEVICE_NAME")"
  [[ -n "$DEVICE" ]] || die "no simulator named '$DEVICE_NAME'. Create it with: xcrun simctl create '$DEVICE_NAME' 'iPhone 17'"
  local state="${DEVICE#* }"
  DEVICE="${DEVICE%% *}"
  if [[ "$state" != "Booted" ]]; then
    xcrun simctl boot "$DEVICE"
    open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
  fi
}

route_rule() {
  # Prints "<method> <path regex>" for a route name. Paths are relative to https://api.onesignal.com/.
  case "$1" in
    create-user)    echo "POST ^apps/[^/]+/users$" ;;
    fetch-user)     echo "GET ^apps/[^/]+/users/by/[^/]+/[^/]+$" ;;
    update-user)    echo "PATCH ^apps/[^/]+/users/by/[^/]+/[^/]+$" ;;
    identity)       echo "PATCH /identity$" ;;
    remove-alias)   echo "DELETE /identity/[^/]+$" ;;
    create-sub)     echo "POST /subscriptions$" ;;
    update-sub)     echo "PATCH ^apps/[^/]+/subscriptions/[^/]+$" ;;
    delete-sub)     echo "DELETE ^apps/[^/]+/subscriptions/[^/]+$" ;;
    identity-by-sub) echo "GET /user/identity$" ;;
    custom-events)  echo "POST /custom_events$" ;;
    all)            echo "- ." ;;
    *) die "unknown route '$1'. Routes: create-user fetch-user update-user identity remove-alias create-sub update-sub delete-sub identity-by-sub custom-events all" ;;
  esac
}

proxy_running() { [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }

network_service() {
  local iface
  iface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
  [[ -n "$iface" ]] || die "no default network route"
  networksetup -listnetworkserviceorder | awk -v dev="$iface" '
    /^\([0-9]+\)/ { sub(/^\([0-9]+\) /, ""); name = $0 }
    $0 ~ "Device: " dev "\\)" { print name; exit }'
}

set_system_proxy() {
  local service
  service="$(network_service)"
  [[ -n "$service" ]] || die "could not map the default interface to a network service"
  {
    echo "$service"
    networksetup -getwebproxy "$service" | awk -F': ' '/^(Enabled|Server|Port)/ {print $2}' | paste -sd' ' -
    networksetup -getsecurewebproxy "$service" | awk -F': ' '/^(Enabled|Server|Port)/ {print $2}' | paste -sd' ' -
  } > "$SAVED_PROXY"
  networksetup -setwebproxy "$service" 127.0.0.1 "$PORT"
  networksetup -setsecurewebproxy "$service" 127.0.0.1 "$PORT"
  echo "Pointed '$service' HTTP(S) proxy at 127.0.0.1:$PORT (restored by 'stop')."
}

restore_system_proxy() {
  [[ -f "$SAVED_PROXY" ]] || return 0
  local service web secure
  { read -r service; read -r web; read -r secure; } < "$SAVED_PROXY"
  restore_one() {
    local kind="$1" enabled server port
    read -r enabled server port <<< "$2"
    if [[ "$enabled" == "Yes" && -n "$server" ]]; then
      networksetup "-set${kind}" "$service" "$server" "$port"
    else
      networksetup "-set${kind}state" "$service" off
    fi
  }
  restore_one webproxy "$web"
  restore_one securewebproxy "$secure"
  rm -f "$SAVED_PROXY"
  echo "Restored '$service' proxy settings."
}

install_ca() {
  for _ in $(seq 1 50); do [[ -f "$CA_CERT" ]] && break; sleep 0.1; done
  [[ -f "$CA_CERT" ]] || die "mitmproxy CA not generated at $CA_CERT"
  resolve_device
  xcrun simctl keychain "$DEVICE" add-root-cert "$CA_CERT"
  echo "Trusted the mitmproxy CA on '$DEVICE_NAME'."
}

cmd_start() {
  command -v mitmdump >/dev/null || die "mitmdump not found. Install with: brew install mitmproxy"
  proxy_running && die "proxy already running (pid $(cat "$PID_FILE")). Run '$0 stop' first."
  : > "$ATTEMPTS"
  [[ -f "$RULES" ]] || echo "[]" > "$RULES"
  # Loopback only, unless a physical device has to reach it.
  local mode_args=(--listen-host 127.0.0.1 --listen-port "$PORT")
  [[ "$PROXY_MODE" == "manual" ]] && mode_args=(--listen-port "$PORT")
  [[ "$PROXY_MODE" == "local" ]] && mode_args=(--mode "local:App")
  # Only onesignal.com is decrypted; everything else on the Mac is tunnelled untouched.
  mitmdump "${mode_args[@]}" \
    --allow-hosts '^(.+\.)?onesignal\.com(:443)?$' \
    --set connection_strategy=lazy \
    --set termlog_verbosity=warn \
    -s "$SCRIPT_DIR/fault_proxy.py" > "$PROXY_LOG" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1
  proxy_running || { cat "$PROXY_LOG"; die "mitmdump exited"; }
  echo "mitmdump running (pid $(cat "$PID_FILE")), log: $PROXY_LOG"
  case "$PROXY_MODE" in
    system) set_system_proxy; install_ca ;;
    local) install_ca ;;
    manual)
      echo "Set the device's Wi-Fi HTTP proxy to $(ipconfig getifaddr en0 2>/dev/null || echo '<this Mac>'):$PORT,"
      echo "then open http://mitm.it on the device to install and trust the CA." ;;
    *) die "unknown RETRY_TEST_PROXY_MODE '$PROXY_MODE'" ;;
  esac
  echo "Relaunch the demo app so it picks up the proxy: $0 relaunch"
}

cmd_stop() {
  if proxy_running; then
    kill "$(cat "$PID_FILE")" && echo "Stopped mitmdump."
  fi
  rm -f "$PID_FILE"
  restore_system_proxy
}

write_rules() {
  # write_rules <json array>; written atomically so the addon never reads a partial file.
  echo "$1" > "$RULES.tmp" && mv "$RULES.tmp" "$RULES"
}

cmd_fail() {
  local route="${1:-}" status="${2:-}"
  [[ -n "$route" && -n "$status" ]] || die "usage: $0 fail <route> <status|0> [--times N] [--retry-after S] [--add]"
  shift 2
  local times="null" retry_after="null" add=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --times) times="$2"; shift 2 ;;
      --retry-after) retry_after="\"$2\""; shift 2 ;;
      --add) add=true; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  local method path
  read -r method path <<< "$(route_rule "$route")"
  [[ "$method" == "-" ]] && method=""
  python3 - "$RULES" "$add" "$route" "$method" "$path" "$status" "$times" "$retry_after" > "$RULES.tmp" <<'PY'
import json, sys
rules_path, add, route, method, path, status, times, retry_after = sys.argv[1:]
rules = json.load(open(rules_path)) if add == "true" else []
rules.append({"route": route, "method": method or None, "path": path, "status": int(status),
              "times": json.loads(times), "retry_after": json.loads(retry_after)})
print(json.dumps(rules))
PY
  mv "$RULES.tmp" "$RULES"
  echo "Rules now: $(cat "$RULES")"
}

cmd_clear() {
  write_rules "[]"
  echo "Cleared all rules; requests pass through."
}

cmd_reset_log() { : > "$ATTEMPTS"; echo "Cleared recorded attempts."; }

cmd_network_flap() {
  # NWPathMonitor in the simulator follows the Mac's interfaces, so turning Wi-Fi off and on
  # exercises the "network returned while foregrounded" trigger.
  local seconds="${1:-10}" device
  device="$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/ {getline; print $2}')"
  [[ -n "$device" ]] || die "no Wi-Fi interface found"
  echo "Wi-Fi ($device) off for ${seconds}s..."
  networksetup -setairportpower "$device" off
  sleep "$seconds"
  networksetup -setairportpower "$device" on
  echo "Wi-Fi back on."
}

cmd_fresh() {
  # Wipes the demo's data and app-group containers so the SDK starts as a new install (Create
  # User and so on), without uninstalling, so an already granted notification permission is kept
  # and the permission prompt does not hold the app inactive.
  local data group plist
  resolve_device
  data="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)" || die "demo app not installed on '$DEVICE_NAME'. Run '$0 install'."
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  # Preferences go through the simulator's cfprefsd, which would write its cached copy back.
  for plist in "$data"/Library/Preferences/*.plist; do
    [[ -f "$plist" ]] && xcrun simctl spawn "$DEVICE" defaults delete "${plist%.plist}" 2>/dev/null || true
  done
  rm -rf "${data:?}/Documents/"* "${data:?}/Library/Caches/"* "${data:?}/Library/Preferences/"* "${data:?}/tmp/"*
  while read -r _ group; do
    [[ -d "$group" ]] || continue
    for plist in "$group"/Library/Preferences/*.plist; do
      [[ -f "$plist" ]] && xcrun simctl spawn "$DEVICE" defaults delete "${plist%.plist}" 2>/dev/null || true
    done
    rm -rf "${group:?}/"*
  done < <(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" groups 2>/dev/null)
  echo "Cleared demo app data."
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
}

cmd_install() {
  resolve_device
  local root="$SCRIPT_DIR/../../../.." derived="$STATE_DIR/DerivedData"
  xcodebuild build -quiet \
    -workspace "$root/iOS_SDK/OneSignalSDK.xcworkspace" -scheme App -configuration Debug \
    -destination "id=$DEVICE" -derivedDataPath "$derived"
  xcrun simctl install "$DEVICE" "$derived/Build/Products/Debug-iphonesimulator/App.app"
  echo "Installed the demo app on '$DEVICE_NAME'. Next: $0 fresh, then $0 tap allow-notifications"
}

cmd_tap() {
  # Drives the demo's UI through Maestro flows in flows/, using the demo's accessibility IDs.
  command -v maestro >/dev/null || die "maestro not found. Install with: brew install mobile-dev-inc/tap/maestro"
  local action="${1:-}" env=()
  case "$action" in
    add-tag|add-alias) [[ $# -eq 3 ]] || die "usage: $0 tap $action <key> <value>"; env=(-e "KEY=$2" -e "VALUE=$3") ;;
    add-email) [[ $# -eq 2 ]] || die "usage: $0 tap $action <value>"; env=(-e "VALUE=$2") ;;
    login)
      [[ $# -eq 2 || $# -eq 3 ]] || die "usage: $0 tap login <external id> [jwt]"
      local jwt="${3:-}"
      [[ -z "$jwt" && -n "$IV_KEY" ]] && { jwt="$(cmd_jwt "$2")" || exit 1; }
      env=(-e "VALUE=$2" -e "JWT=$jwt") ;;
    update-jwt)
      [[ $# -eq 2 || $# -eq 3 ]] || die "usage: $0 tap update-jwt <external id> [jwt]"
      local token="${3:-}"
      [[ -n "$token" ]] || { token="$(cmd_jwt "$2")" || exit 1; }
      env=(-e "KEY=$2" -e "VALUE=$token") ;;
    logout|toggle-push|pause-iams|allow-notifications) ;;
    *) die "usage: $0 tap <add-tag|add-alias|add-email|login|update-jwt|logout|toggle-push|pause-iams|allow-notifications> [args]" ;;
  esac
  resolve_device
  MAESTRO_CLI_NO_ANALYTICS=1 MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true \
    maestro --device "$DEVICE" test ${env[@]+"${env[@]}"} "$SCRIPT_DIR/flows/$action.yaml" \
    | grep -E '^ *(>|[A-Z].*(COMPLETED|FAILED|WARNED))' || true
}

cmd_jwt() {
  [[ -n "$IV_APP_ID" && -n "$IV_KEY" ]] || die "set RETRY_TEST_IV_APP_ID and RETRY_TEST_IV_KEY (path to the app's private key)"
  [[ -r "$IV_KEY" ]] || die "can't read $IV_KEY"
  python3 "$SCRIPT_DIR/make_jwt.py" "$IV_KEY" "$IV_APP_ID" "$@"
}

cmd_logs() {
  resolve_device
  xcrun simctl spawn "$DEVICE" log stream --level debug --style compact \
    --predicate 'process == "App" AND (eventMessage CONTAINS[c] "request" OR eventMessage CONTAINS[c] "retry" OR eventMessage CONTAINS[c] "re-attempt")'
}

usage() {
  cat <<EOF
Usage: $0 <command>

Proxy
  start                     Start mitmproxy, point the proxy at it, trust its CA on the simulator
  stop                      Stop mitmproxy and restore proxy settings
  trust-ca                  Trust the mitmproxy CA on the simulator

Faults (take effect immediately, no relaunch needed)
  fail <route> <status> [--times N] [--retry-after S] [--add]
                            Fail matching SDK requests. Status 0 drops the connection.
                            --times N: fail N times, then pass. Default: until cleared.
                            --add: keep existing rules instead of replacing them.
  clear                     Remove all rules
  rules                     Show current rules

Observe
  watch                     Follow every SDK request as it passes the proxy
  report [route regex]      Gaps between attempts per route vs. the expected backoff
  reset-log                 Forget recorded attempts
  logs                      Stream the demo app's SDK request/retry logs

App / environment
  install                   Build the demo app and install it on the simulator
  tap <action> [args]       Drive the demo's UI with Maestro:
                              add-tag <key> <value>, add-alias <label> <id>, add-email <email>,
                              login <external id> [jwt], update-jwt <external id> [jwt], logout,
                              toggle-push, pause-iams, allow-notifications
                            With RETRY_TEST_IV_KEY set, login and update-jwt sign a JWT when none is given.
  jwt <external id> [label=id] [email:addr] [sms:number]
                            Print an Identity Verification JWT claiming those aliases and subscriptions
  relaunch                  Kill and relaunch the demo app
  fresh                     Wipe the demo app's data (new SDK user) and relaunch, keeping the
                            notification permission. Allow the prompt once after installing.
  background | foreground   Send the demo app to the background, or bring it back
  network-flap [seconds]    Turn the Mac's Wi-Fi off and back on (default 10s)

Routes: create-user fetch-user update-user identity remove-alias create-sub update-sub
        delete-sub identity-by-sub custom-events all
Env: RETRY_TEST_DEVICE ($DEVICE_NAME), RETRY_TEST_PORT ($PORT),
     RETRY_TEST_PROXY_MODE ($PROXY_MODE), RETRY_TEST_BUNDLE_ID ($BUNDLE_ID),
     RETRY_TEST_IV_APP_ID and RETRY_TEST_IV_KEY (Identity Verification app and its private key path)
EOF
}

case "${1:-help}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  trust-ca) install_ca ;;
  fail) shift; cmd_fail "$@" ;;
  clear) cmd_clear ;;
  rules) cat "$RULES" 2>/dev/null || echo "[]" ;;
  watch) tail -n +1 -F "$PROXY_LOG" | grep --line-buffered '^\[fault\]' ;;
  report) shift; python3 "$SCRIPT_DIR/report.py" "$ATTEMPTS" "$@" ;;
  reset-log) cmd_reset_log ;;
  logs) cmd_logs ;;
  fresh) cmd_fresh ;;
  install) cmd_install ;;
  tap) shift; cmd_tap "$@" ;;
  jwt) shift; cmd_jwt "$@" ;;
  relaunch) resolve_device; xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true; xcrun simctl launch "$DEVICE" "$BUNDLE_ID" ;;
  background) resolve_device; xcrun simctl launch "$DEVICE" com.apple.Preferences >/dev/null && echo "Demo app backgrounded." ;;
  foreground) resolve_device; xcrun simctl launch "$DEVICE" "$BUNDLE_ID" >/dev/null && echo "Demo app foregrounded." ;;
  network-flap) shift; cmd_network_flap "$@" ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
