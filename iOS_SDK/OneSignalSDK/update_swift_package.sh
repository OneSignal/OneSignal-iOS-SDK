#!/bin/bash
set -e

WORKING_DIR=$(pwd)

#Ask for the new release version number to be placed in the package URL
# echo -e "\033[1mEnter the new SDK release version number\033[0m"
# read VERSION_NUMBER
VERSION_NUMBER=$1

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
    SWIFT_PM_CHECKSUM_LINE="          checksum: \"${CHECKSUM}\""

    # Use sed to remove line from the Swift.package and replace it with the new checksum
    sed -i '' "$3s/.*/$SWIFT_PM_CHECKSUM_LINE/" "${SWIFT_PACKAGE_PATH}"
    SWIFT_PM_URL_LINE="          url: \"https:\/\/github.com\/OneSignal\/OneSignal-iOS-SDK\/releases\/download\/${VERSION_NUMBER}\/${FRAMEWORK_NAME}.xcframework.zip\","
    #Use sed to remove line from the Swift.package and replace it with the new URL for the new release
    sed -i '' "$4s/.*/$SWIFT_PM_URL_LINE/" "${SWIFT_PACKAGE_PATH}"
    #Open XCFramework folder to drag zip into new release
    open "${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}"
}

## OneSignal Core ##
update_framework "OneSignal_Core" "OneSignalCore" "149" "148"

## OneSignal OSCore ##
update_framework "OneSignal_OSCore" "OneSignalOSCore" "144" "143"

## OneSignal Outcomes ##
update_framework "OneSignal_Outcomes" "OneSignalOutcomes" "139" "138"

## OneSignal Extension ##
update_framework "OneSignal_Extension" "OneSignalExtension" "134" "133"

## OneSignal Notifications ##
update_framework "OneSignal_Notifications" "OneSignalNotifications" "129" "128"

## OneSignal User ##
update_framework "OneSignal_User" "OneSignalUser" "124" "123"

## OneSignal Location ##
update_framework "OneSignal_Location" "OneSignalLocation" "119" "118"

## OneSignal Location ##
update_framework "OneSignal_InAppMessages" "OneSignalInAppMessages" "114" "113"

## OneSignal ##
update_framework "OneSignal_XCFramework" "OneSignalFramework" "109" "108"
