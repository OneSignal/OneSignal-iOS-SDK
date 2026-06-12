#!/bin/bash
set -e

WORKING_DIR=$(pwd)

#Ask for the new release version number to be placed in the package URL
# echo -e "\033[1mEnter the new SDK release version number\033[0m"
# read VERSION_NUMBER
VERSION_NUMBER=$1

if [ -z "${VERSION_NUMBER}" ]; then
    echo "ERROR: release version argument is required (usage: $0 <version>)" >&2
    exit 1
fi

update_framework() {
    FRAMEWORK_FOLDER_NAME=$1

    FRAMEWORK_NAME=$2

    FRAMEWORK_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/${FRAMEWORK_NAME}.xcframework"

    FRAMEWORK_ZIP_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/${FRAMEWORK_NAME}.xcframework.zip"

    SIMULATOR_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/simulator.xcarchive"

    IOS_DEVICE_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/iOS.xcarchive"

    CATALYST_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/catalyst.xcarchive"

    SWIFT_PACKAGE_DIRECTORY="${WORKING_DIR}/../.."

    SWIFT_PACKAGE_PATH="${SWIFT_PACKAGE_DIRECTORY}/Package.swift"

    # Remove the old Zipped XCFramework and create a new Zip
    echo "Removing old Zipped XCFramework ${FRAMEWORK_ZIP_PATH}"
    rm -rf "${FRAMEWORK_ZIP_PATH}"
    echo "Creating new Zipped XCFramework ${FRAMEWORK_ZIP_PATH}"
    ditto -c -k --sequesterRsrc --keepParent "${FRAMEWORK_PATH}" "${FRAMEWORK_ZIP_PATH}" 

    # Compute the checksum for the Zipped framework
    echo "Computing package checksum and updating Package.swift ${SWIFT_PACKAGE_PATH}"
    CHECKSUM=$(swift package compute-checksum "${FRAMEWORK_ZIP_PATH}")
    if [ -z "${CHECKSUM}" ]; then
        echo "ERROR: empty checksum computed for ${FRAMEWORK_NAME}" >&2
        exit 1
    fi
    # Update this framework's .binaryTarget in place, located by the framework
    # name in its url line (NOT by hardcoded line number). Only the version in the
    # url and the hash in the following checksum line are rewritten; surrounding
    # structure/formatting is preserved. Matching by name keeps this correct even
    # when the manifest layout shifts -- the previous line-number approach silently
    # corrupted Package.swift once unrelated lines moved (broke 5.5.2 SPM).
    awk -v fw="${FRAMEWORK_NAME}" -v ver="${VERSION_NUMBER}" -v chk="${CHECKSUM}" '
        # This framework'"'"'s url line: bump only the version path segment.
        $0 ~ ("url: \"https://github.com/OneSignal/OneSignal-iOS-SDK/releases/download/[^/]*/" fw "\\.xcframework\\.zip\"") {
            sub("download/[^/]*/", "download/" ver "/")
            print
            expect_checksum = 1
            next
        }
        # The checksum must sit on the line IMMEDIATELY after that url (the
        # well-formed .binaryTarget layout). Only that one line is eligible, so a
        # reordered/stray/renamed checksum line can never be clobbered: if it is not
        # a checksum line nothing is rewritten and the post-run guard fails loudly.
        expect_checksum {
            expect_checksum = 0
            if ($0 ~ /^[[:space:]]*checksum: "[0-9a-fA-F]*"[[:space:]]*$/) {
                sub("checksum: \"[0-9a-fA-F]*\"", "checksum: \"" chk "\"")
            }
            print
            next
        }
        { print }
    ' "${SWIFT_PACKAGE_PATH}" > "${SWIFT_PACKAGE_PATH}.tmp"
    mv "${SWIFT_PACKAGE_PATH}.tmp" "${SWIFT_PACKAGE_PATH}"

    # Fail loudly if the entry was not found/updated, instead of silently leaving
    # the manifest stale or malformed.
    if ! grep -q "releases/download/${VERSION_NUMBER}/${FRAMEWORK_NAME}.xcframework.zip" "${SWIFT_PACKAGE_PATH}"; then
        echo "ERROR: could not find/update url for ${FRAMEWORK_NAME} in Package.swift" >&2
        exit 1
    fi
    if ! grep -q "checksum: \"${CHECKSUM}\"" "${SWIFT_PACKAGE_PATH}"; then
        echo "ERROR: could not update checksum for ${FRAMEWORK_NAME} in Package.swift" >&2
        exit 1
    fi
    #Open XCFramework folder to drag zip into new release
    open "${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}"
}

## OneSignal LiveActivities ##
update_framework "OneSignal_LiveActivities" "OneSignalLiveActivities"

## OneSignal Core ##
update_framework "OneSignal_Core" "OneSignalCore"

## OneSignal OSCore ##
update_framework "OneSignal_OSCore" "OneSignalOSCore"

## OneSignal Outcomes ##
update_framework "OneSignal_Outcomes" "OneSignalOutcomes"

## OneSignal Extension ##
update_framework "OneSignal_Extension" "OneSignalExtension"

## OneSignal Notifications ##
update_framework "OneSignal_Notifications" "OneSignalNotifications"

## OneSignal User ##
update_framework "OneSignal_User" "OneSignalUser"

## OneSignal Location ##
update_framework "OneSignal_Location" "OneSignalLocation"

## OneSignal InAppMessages ##
update_framework "OneSignal_InAppMessages" "OneSignalInAppMessages"

## OneSignal ##
update_framework "OneSignal_XCFramework" "OneSignalFramework"
