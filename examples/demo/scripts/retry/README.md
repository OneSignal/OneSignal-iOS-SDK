# Retry test harness

Injects failures into the SDK's requests from the demo app, so executor retries and backoff can be
watched and checked. A [mitmproxy](https://mitmproxy.org) addon fails only requests that carry the
SDK's `SDK-Version` header. The demo's own REST calls and all other traffic pass through. Only
`onesignal.com` traffic is decrypted.

```bash
brew install mitmproxy mobile-dev-inc/tap/maestro
cd examples/demo/scripts/retry
./retry-test.sh help
```

[Maestro](https://maestro.mobile.dev) drives the demo's UI (`tap`) through the flows in `flows/`.

## Setup

1. `xcrun simctl create "OneSignal Retry Test" "iPhone 17"`. The harness uses its own simulator
   (`RETRY_TEST_DEVICE`, by name or UDID) because the other OneSignal demos share the bundle ID.
2. `./retry-test.sh install` builds the demo and installs it there.
3. `./retry-test.sh start` starts mitmproxy on port 8899, points the Mac's Wi-Fi/Ethernet HTTP(S)
   proxy at it (the simulator uses the Mac's proxy), and trusts its CA on the simulator.
4. `./retry-test.sh fresh`, then `./retry-test.sh tap allow-notifications`. The permission prompt
   holds the app inactive, so foreground retries never fire while it is showing. `fresh` wipes the
   demo's data without reinstalling, so the permission is kept from then on.
5. In another terminal, `./retry-test.sh watch` follows each SDK request.
6. When done, **`./retry-test.sh stop`** restores the Mac's proxy settings.

Leave the Mac's proxy alone with `RETRY_TEST_PROXY_MODE=local` (mitmproxy captures the `App`
process, which needs its network extension approved once). For a physical device, use
`RETRY_TEST_PROXY_MODE=manual` and set the device's Wi-Fi proxy to the Mac, as `start` explains.

## Commands

| Command | Does |
| --- | --- |
| `fail <route> <status> [--times N] [--retry-after S] [--add]` | Fail matching requests. Status `0` drops the connection, like being offline. Without `--times` it fails until `clear`. `--add` keeps earlier rules. Applies right away. |
| `clear` / `rules` | Remove or show the rules |
| `report [regex]` | Per route: each attempt, the gap since the previous one, and the gap expected |
| `reset-log` | Forget recorded attempts, for example between scenarios |
| `tap <action> [args]` | Use the demo: `add-tag <key> <value>`, `add-alias <label> <id>`, `add-email <email>`, `login <external id> [jwt]`, `logout`, `toggle-push`, `allow-notifications`. With `RETRY_TEST_IV_KEY` set, `login` signs a JWT when none is given |
| `jwt <external id> [label=id] [email:addr] [sms:number]` | Print an Identity Verification JWT, valid for an hour, that claims those aliases and subscriptions |
| `install` | Build the demo and install it on the simulator |
| `fresh` / `relaunch` | New install without reinstalling / kill and relaunch |
| `background` / `foreground` | Background the demo by opening Settings / bring it back |
| `network-flap [s]` | Turn the Mac's Wi-Fi off for `s` seconds (default 10). Drops your Mac's connection too. |
| `logs` | Stream the demo's SDK request and retry logs |

Routes: `create-user`, `fetch-user`, `update-user` (tags, language, session data), `identity` (add
alias and login's Identify User share it), `remove-alias`, `create-sub`, `update-sub`,
`delete-sub`, `identity-by-sub`, `custom-events`, `all`.

## Reading `report`

```
POST apps/<app>/users  (User executor)
    #     time status     body      gap         expected  note
    1     0.0s   408* edc1f203
    2     2.8s   408* 8f1a8f24     2.8s         2.5-5.0s  executor backoff #1
    3    11.4s   408* d85e5a15     8.6s        5.0-10.0s  executor backoff #2
    4    31.0s   201  3a910c5a    19.6s       10.0-20.0s  executor backoff #3
```

What the SDK should do:

- **Executor backoff**: 5s, doubling to 300s, times a jitter of 0.5 to 1. `Retry-After` is the
  minimum wait (capped at 1h), and a 429 without one waits 60s.
- **Client reattempts first**: `OneSignalClient` itself re-sends a 5xx or status 0 four times
  (5, 15, 45, 135s) before the executor sees the failure. That count is kept per request for the
  run, so later failures of the same request go straight to the executor backoff. Use a
  retryable status the client does not reattempt, like **408**, to see the executor backoff right
  away. The client resends ignore foreground and network return, so after going offline, requests
  can wait for the next client resend (up to 135s).
- **Repo executors** (everything but the User executor) only resend on the 5s poll, so their window
  allows up to 5s more. The User executor wakes itself on time.
- **Foreground, and network return while in the foreground, end the executor backoff early**, but
  not `Retry-After`. `EARLY` right after those is expected. One case happens without you doing
  anything: at cold start, the first failure often lands just before the app goes active, so the
  second attempt follows within a second.
- `body` is a hash of the request body. A new hash on each attempt is normal, since bodies hold
  timestamps.

## Scenarios

Run `reset-log` before each one. Unless noted, the request should succeed after the last failure,
and nothing should need a relaunch.

1. **Exponential backoff, User executor**: `fail create-user 408 --times 4`, then `fresh`. Gaps
   should fall in the windows above, then 201.
2. **Repo executor**: `fail update-user 408 --times 3`, then `tap add-tag k v`. The PATCH
   retries on the next poll after each backoff.
3. **Retry-After**: `fail update-user 429 --times 2 --retry-after 20`, then `tap add-tag k v`. Gaps of at
   least 20s. `background` then `foreground` during the wait must not cut it short.
4. **429 without Retry-After**: `fail update-user 429 --times 1`, then `tap add-tag k v`. About 60s.
5. **5xx**: `fail update-user 503 --times 6`, then `tap add-tag k v`. Four client reattempts (5, 15, 45,
   135s), then executor backoff. Slow, about 3.5 minutes.
6. **Offline**: `fail all 0`, then `tap add-tag k v`, `tap add-alias l i` and `tap add-email e`.
   Wait for a few failures, then `clear`. Everything goes out by its next client resend or backoff.
7. **Foreground ends the backoff**: `fail create-user 408 --times 6`, then `fresh`. After about
   25s, `background`, wait, `foreground`. An attempt goes out right as the app becomes active.
8. **Network return**: as in 7, but `network-flap 5` with the app in the foreground. An attempt goes
   out when Wi-Fi comes back. Repeat with the app in the background: no attempt then.
9. **Order is kept**: `fail create-user 408 --times 3`, then `fresh` and `tap login <id>` during the
   failures. Identify User (PATCH `.../identity`) is not sent until Create User succeeds.
10. **Fetch User**: `fail fetch-user 408 --times 3`, then `tap login <id>`.
    Fetch User retries in the same run, and later user requests wait for it.
11. **Kill during backoff**: `fail update-user 408`, `tap add-tag k v`, wait for two failures, `clear`,
    then `relaunch`. The cached request is sent right after launch.
12. **Non-retryable is not retried**: `fail update-user 400 --times 1`, then `tap add-tag k v`. One attempt,
    no retries.
13. **Update Subscription no longer retries every 5s**: `fail update-sub 408 --times 4`, then
    `tap toggle-push`. Gaps grow instead of repeating every 5s.
14. **Login/logout while failing**: `fail all 408`, `tap login b`, `tap logout`, `tap login c`, then
    `clear`. Requests for each user go out in order, with no errors about the wrong user.
15. **Identity Verification**: needs an app with Identity Verification on and its ES256 private
    key. Ask the SDK team for both and keep the key outside the repo. Set the app's ID as
    `ONESIGNAL_APP_ID` in `examples/demo/App/Secrets.plist` and `install` again, then set
    `RETRY_TEST_IV_APP_ID=<app id>` and `RETRY_TEST_IV_KEY=<path to the key>`. `tap login <id>` now
    signs a JWT. No anonymous Create User is sent, so in 1 and 9 the Create User comes from the
    login. Repeat 1, 2, 6 and 9. In 6, log in first with a JWT that claims the alias and email:
    `tap login <id> "$(./retry-test.sh jwt <id> l=i email:e)"`.
