#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KMP_REPO="$SCRIPT_DIR/../../OneSignal-KMP-SDK"

if [[ ! -f "$KMP_REPO/gradlew" ]]; then
  echo "OneSignal-KMP-SDK is missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

"$KMP_REPO/gradlew" \
  -p "$KMP_REPO" \
  :kmp:verifyOneSignalKMPXCFramework \
  --console=plain
