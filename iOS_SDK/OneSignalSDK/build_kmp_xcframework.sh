#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KMP_REPO="$SCRIPT_DIR/../../OneSignal-KMP-SDK"
KMP_TASK="${1:-:kmp:verifyOneSignalKMPXCFramework}"

if [[ ! -f "$KMP_REPO/gradlew" ]]; then
  echo "OneSignal-KMP-SDK is missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

case "$KMP_TASK" in
  :kmp:assembleOneSignalKMPReleaseXCFramework|:kmp:verifyOneSignalKMPXCFramework) ;;
  *)
    echo "Unsupported KMP XCFramework task: $KMP_TASK" >&2
    exit 1
    ;;
esac

"$KMP_REPO/gradlew" \
  -p "$KMP_REPO" \
  "$KMP_TASK" \
  --console=plain
