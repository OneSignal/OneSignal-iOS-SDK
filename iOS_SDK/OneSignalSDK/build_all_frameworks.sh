#!/bin/bash
set -e

WORKING_DIR=$(pwd)

create_xcframework() {
    FRAMEWORK_FOLDER_NAME=$1

    FRAMEWORK_NAME=$2

    FRAMEWORK_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/${FRAMEWORK_NAME}.xcframework"

    BUILD_SCHEME=$3

    SIMULATOR_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/simulator.xcarchive"

    IOS_DEVICE_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/iOS.xcarchive"

    CATALYST_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/catalyst.xcarchive"

    rm -rf "${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}"
    echo "Deleted ${FRAMEWORK_FOLDER_NAME}"
    mkdir "${FRAMEWORK_FOLDER_NAME}"
    echo "Created ${FRAMEWORK_FOLDER_NAME}"
    echo "Archiving ${FRAMEWORK_NAME}"

    xcodebuild -list

    xcodebuild archive ONLY_ACTIVE_ARCH=NO -scheme ${BUILD_SCHEME} -destination="generic/platform=iOS Simulator" -archivePath "${SIMULATOR_ARCHIVE_PATH}" -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

    xcodebuild archive -scheme ${BUILD_SCHEME} -destination="generic/platform=iOS" -archivePath "${IOS_DEVICE_ARCHIVE_PATH}" -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

    xcodebuild archive -scheme ${BUILD_SCHEME} -destination='generic/platform=macOS,variant=Mac Catalyst' -archivePath "${CATALYST_ARCHIVE_PATH}" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

    xcodebuild -create-xcframework -framework ${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -debug-symbols ${SIMULATOR_ARCHIVE_PATH}/dSYMs/${FRAMEWORK_NAME}.framework.dSYM -framework ${IOS_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -debug-symbols ${IOS_DEVICE_ARCHIVE_PATH}/dSYMs/${FRAMEWORK_NAME}.framework.dSYM -framework ${CATALYST_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -debug-symbols ${CATALYST_ARCHIVE_PATH}/dSYMs/${FRAMEWORK_NAME}.framework.dSYM -output "${FRAMEWORK_PATH}"
    rm -rf "${SIMULATOR_ARCHIVE_PATH}"
    rm -rf "${IOS_DEVICE_ARCHIVE_PATH}"
    rm -rf "${CATALYST_ARCHIVE_PATH}"
}

# BUILD ONESIGNAL CORE ##
create_xcframework "OneSignal_Core" "OneSignalCore" "OneSignalCore"

## BUILD ONESIGNAL CORE ##
create_xcframework "OneSignal_OSCore" "OneSignalOSCore" "OneSignalOSCore"

## BUILD ONESIGNAL OUTCOMES ##
create_xcframework "OneSignal_Outcomes" "OneSignalOutcomes" "OneSignalOutcomes"

## BUILD ONESIGNAL EXTENSION ##
create_xcframework "OneSignal_Extension" "OneSignalExtension" "OneSignalExtension"

## BUILD ONESIGNAL EXTENSION ##
create_xcframework "OneSignal_Notifications" "OneSignalNotifications" "OneSignalNotifications"

## BUILD ONESIGNAL USER ##
create_xcframework "OneSignal_User" "OneSignalUser" "OneSignalUser"

## BUILD ONESIGNAL LIVE ACTIVITIES ##
create_xcframework "OneSignal_LiveActivities" "OneSignalLiveActivities" "OneSignalLiveActivities"

## BUILD ONESIGNAL USER ##
create_xcframework "OneSignal_Location" "OneSignalLocation" "OneSignalLocation"

## BUILD ONESIGNAL USER ##
create_xcframework "OneSignal_InAppMessages" "OneSignalInAppMessages" "OneSignalInAppMessages"

## BUILD ONESIGNAL ##
create_xcframework "OneSignal_XCFramework" "OneSignalFramework" "OneSignalFramework"

open "${WORKING_DIR}"
