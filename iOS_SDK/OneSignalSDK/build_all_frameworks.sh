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

    xcodebuild archive ONLY_ACTIVE_ARCH=NO -scheme ${BUILD_SCHEME} -destination="generic/platform=iOS Simulator" -archivePath "${SIMULATOR_ARCHIVE_PATH}" -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES ENABLE_BITCODE=NO

    xcodebuild archive -scheme ${BUILD_SCHEME} -destination="generic/platform=iOS" -archivePath "${IOS_DEVICE_ARCHIVE_PATH}" -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES ENABLE_BITCODE=NO

    xcodebuild archive -scheme ${BUILD_SCHEME} -destination='generic/platform=macOS,variant=Mac Catalyst' -archivePath "${CATALYST_ARCHIVE_PATH}" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES ENABLE_BITCODE=NO

    xcodebuild -create-xcframework -framework ${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -framework ${IOS_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -framework ${CATALYST_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -output "${FRAMEWORK_PATH}"

    rm -rf "${SIMULATOR_ARCHIVE_PATH}"
    rm -rf "${IOS_DEVICE_ARCHIVE_PATH}"
    rm -rf "${CATALYST_ARCHIVE_PATH}"
}

## BUILD ONESIGNAL CORE ##
create_xcframework "OneSignal_Core" "OneSignalCore" "OneSignalCore"

## BUILD ONESIGNAL OUTCOMES ##
create_xcframework "OneSignal_Outcomes" "OneSignalOutcomes" "OneSignalOutcomes"

## BUILD ONESIGNAL EXTENSION ##
create_xcframework "OneSignal_Extension" "OneSignalExtension" "OneSignalExtension"

## BUILD ONESIGNAL ##
create_xcframework "OneSignal_XCFramework" "OneSignal" "OneSignalFramework"

open "${WORKING_DIR}"
