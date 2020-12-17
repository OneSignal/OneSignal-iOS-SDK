#!/bin/bash
set -e

WORKING_DIR=$(pwd)

FRAMEWORK_FOLDER_NAME="OneSignal_XCFramework"

FRAMEWORK_NAME="OneSignal"

FRAMEWORK_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/${FRAMEWORK_NAME}.xcframework"

FRAMEWORK_ZIP_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/${FRAMEWORK_NAME}.xcframework.zip"

BUILD_SCHEME="OneSignalFramework"

SIMULATOR_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/simulator.xcarchive"

IOS_DEVICE_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/iOS.xcarchive"

CATALYST_ARCHIVE_PATH="${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}/catalyst.xcarchive"

SWIFT_PACKAGE_PATH="../../Package.swift"

rm -rf "${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}"
echo "Deleted ${FRAMEWORK_FOLDER_NAME}"
mkdir "${FRAMEWORK_FOLDER_NAME}"
echo "Created ${FRAMEWORK_FOLDER_NAME}"
echo "Archiving ${FRAMEWORK_NAME}"

xcodebuild archive ONLY_ACTIVE_ARCH=NO -scheme ${BUILD_SCHEME} -destination="iOS Simulator" -arch i386 -arch x86_64 -arch arm64 -archivePath "${SIMULATOR_ARCHIVE_PATH}" -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

xcodebuild archive -scheme ${BUILD_SCHEME} -destination="iOS" -archivePath "${IOS_DEVICE_ARCHIVE_PATH}" -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

xcodebuild archive -scheme ${BUILD_SCHEME} -destination='platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath "${CATALYST_ARCHIVE_PATH}" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

xcodebuild -create-xcframework -framework ${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -framework ${IOS_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -framework ${CATALYST_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -output "${FRAMEWORK_PATH}"
# Remove the old Zipped XCFramework and create a new Zip
rm -rf "${FRAMEWORK_ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${FRAMEWORK_PATH}" "${FRAMEWORK_ZIP_PATH}" 

# Compute the checksum for the Zipped framework
CHECKSUM=$(swift package compute-checksum "${FRAMEWORK_ZIP_PATH}")
SWIFT_PM_CHECKSUM_LINE="          checksum: \"${CHECKSUM}\""
# Use sed to remove line 17 from the Swift.package and replace it with the new checksum
sed -i '' "17s/.*/$SWIFT_PM_CHECKSUM_LINE/" "${SWIFT_PACKAGE_PATH}"
#Ask for the new release version number to be placed in the package URL
echo -e "\033[1mEnter the new SDK release version number\033[0m"
read VERSION_NUMBER
SWIFT_PM_URL_LINE="          url: \"https:\/\/github.com\/OneSignal\/OneSignal-iOS-SDK\/releases\/download\/${VERSION_NUMBER}\/OneSignal.xcframework.zip\","
# Use sed to remove line 16 from the Swift.package and replace it with the new URL for the new release
sed -i '' "16s/.*/$SWIFT_PM_URL_LINE/" "${SWIFT_PACKAGE_PATH}"
#Open XCFramework folder to drag zip into new release
rm -rf "${SIMULATOR_ARCHIVE_PATH}"
rm -rf "${IOS_DEVICE_ARCHIVE_PATH}"
rm -rf "${CATALYST_ARCHIVE_PATH}"
open "${WORKING_DIR}/${FRAMEWORK_FOLDER_NAME}"

