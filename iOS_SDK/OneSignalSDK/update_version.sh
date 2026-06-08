#!/bin/bash
set -e

# Script to update the SDK version across the codebase
# Updates: .podspec files and ONESIGNAL_VERSION
# Usage: ./update_version.sh <version>

if [ -z "$1" ]; then
    echo "Error: Version number is required"
    echo "Usage: ./update_version.sh <version>"
    exit 1
fi

VERSION=$1

WORKING_DIR=$(pwd)
REPO_ROOT="${WORKING_DIR}/../.."

# Validate version format (supports X.Y.Z or X.Y.Z-suffix)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]; then
    echo "Error: Version must be in format X.Y.Z or X.Y.Z-suffix (e.g., 5.2.15 or 5.2.3-beta-01)"
    exit 1
fi

# Convert semantic version to numeric version
# Examples: "5.2.15" -> "050215", "5.2.3-beta-01" -> "050203-beta-01"
convert_to_numeric() {
    local version=$1
    local version_part=""
    local suffix=""

    # Split by dash to separate version and suffix
    if [[ $version == *"-"* ]]; then
        version_part="${version%%-*}"
        suffix="-${version#*-}"
    else
        version_part="$version"
    fi

    # Split version by dots and pad each part to 2 digits
    IFS='.' read -r major minor patch <<< "$version_part"
    printf "%02d%02d%02d%s" "$major" "$minor" "$patch" "$suffix"
}

VERSION_NUMERIC=$(convert_to_numeric "$VERSION")

ONESIGNAL_PODSPEC="${REPO_ROOT}/OneSignal.podspec"
ONESIGNAL_XCFRAMEWORK_PODSPEC="${REPO_ROOT}/OneSignalXCFramework.podspec"
ONESIGNAL_COMMON_DEFINES="${WORKING_DIR}/OneSignalCore/Source/OneSignalCommonDefines.h"

echo "Updating version to ${VERSION}..."

# Update OneSignal.podspec
if [ -f "$ONESIGNAL_PODSPEC" ]; then
    sed -i '' "s/s\.version[[:space:]]*=[[:space:]]*\"[^\"]*\"/s.version          = \"${VERSION}\"/" "$ONESIGNAL_PODSPEC"
    echo "✓ Updated OneSignal.podspec"
else
    echo "Error: OneSignal.podspec not found at ${ONESIGNAL_PODSPEC}"
    exit 1
fi

# Update OneSignalXCFramework.podspec
if [ -f "$ONESIGNAL_XCFRAMEWORK_PODSPEC" ]; then
    sed -i '' "s/s\.version[[:space:]]*=[[:space:]]*\"[^\"]*\"/s.version          = \"${VERSION}\"/" "$ONESIGNAL_XCFRAMEWORK_PODSPEC"
    echo "✓ Updated OneSignalXCFramework.podspec"
else
    echo "Error: OneSignalXCFramework.podspec not found at ${ONESIGNAL_XCFRAMEWORK_PODSPEC}"
    exit 1
fi

# Update OneSignalCommonDefines.h
if [ -f "$ONESIGNAL_COMMON_DEFINES" ]; then
    sed -i '' "s/^#define ONESIGNAL_VERSION[[:space:]]*@\"[^\"]*\"/#define ONESIGNAL_VERSION                                                   @\"${VERSION_NUMERIC}\"/" "$ONESIGNAL_COMMON_DEFINES"
    echo "✓ Updated ONESIGNAL_VERSION in OneSignalCommonDefines.h to ${VERSION_NUMERIC}"
else
    echo "Error: OneSignalCommonDefines.h not found at ${ONESIGNAL_COMMON_DEFINES}"
    exit 1
fi

echo "Successfully updated version to ${VERSION} (numeric: ${VERSION_NUMERIC}) in all files"
