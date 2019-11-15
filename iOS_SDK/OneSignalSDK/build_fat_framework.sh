#!/bin/bash
set -e

WORKING_DIR=$(pwd)
DERIVED_DATA_RELATIVE_DIR=temp
BUILD_CONFIG="Debug"
BUILD_TYPE="staticlib"
BUILD_SCHEME="OneSignalFramework"
BUILD_PROJECT="OneSignal.xcodeproj"

# NOTE: Once Apple drops support for Xcode 10, we can edit this to use same xcodebuild version for all three build commands
XCODEBUILD_OLDEST_SUPPORTED=/Applications/Xcode10.1.app/Contents/Developer/usr/bin/xcodebuild
XCODEBUILD_11_0=/Applications/Xcode11.0.app/Contents/Developer/usr/bin/xcodebuild

# For backwards compatible bitcode we need to build iphonesimulator + iphoneos with 3 versions behind the latest.
#       However variant=Mac Catalyst needs to be be Xcode 11.0
$XCODEBUILD_OLDEST_SUPPORTED -configuration ${BUILD_CONFIG} MACH_O_TYPE=${BUILD_TYPE} -sdk "iphonesimulator" ARCHS="x86_64" -project ${BUILD_PROJECT} -scheme ${BUILD_SCHEME} SYMROOT="${DERIVED_DATA_RELATIVE_DIR}/"
$XCODEBUILD_OLDEST_SUPPORTED -configuration ${BUILD_CONFIG} MACH_O_TYPE=${BUILD_TYPE} -sdk "iphoneos" ARCHS="armv7 armv7s arm64 arm64e i386"  -project ${BUILD_PROJECT} -scheme ${BUILD_SCHEME} SYMROOT="${DERIVED_DATA_RELATIVE_DIR}/"
$XCODEBUILD_11_0 -configuration ${BUILD_CONFIG} ARCHS="x86_64h" -destination 'platform=macOS,variant=Mac Catalyst' MACH_O_TYPE=${BUILD_TYPE} -project ${BUILD_PROJECT} -scheme ${BUILD_SCHEME} SYMROOT="${DERIVED_DATA_RELATIVE_DIR}/"

USER=$(id -un)
DERIVED_DATA_ONESIGNAL_DIR="${WORKING_DIR}/${DERIVED_DATA_RELATIVE_DIR}"

# Use Debug configuration to expose symbols
CATALYST_DIR="${DERIVED_DATA_ONESIGNAL_DIR}/Debug-maccatalyst"
SIMULATOR_DIR="${DERIVED_DATA_ONESIGNAL_DIR}/Debug-iphonesimulator"
IPHONE_DIR="${DERIVED_DATA_ONESIGNAL_DIR}/Debug-iphoneos"

CATALYST_OUTPUT_DIR=${CATALYST_DIR}/OneSignal.framework
SIMULATOR_OUTPUT_DIR=${SIMULATOR_DIR}/OneSignal.framework
IPHONE_OUTPUT_DIR=${IPHONE_DIR}/OneSignal.framework

UNIVERSAL_DIR=${DERIVED_DATA_ONESIGNAL_DIR}/Debug-universal
FINAL_FRAMEWORK=${UNIVERSAL_DIR}/OneSignal.framework

rm -rf "${UNIVERSAL_DIR}"
mkdir "${UNIVERSAL_DIR}"

echo "> Making Final OneSignal with all Architecture. iOS, iOS Simulator(x86_64), Mac Catalyst(x86_64h)"
lipo -create -output "$UNIVERSAL_DIR"/OneSignal "${IPHONE_OUTPUT_DIR}"/OneSignal "${SIMULATOR_OUTPUT_DIR}"/OneSignal "${CATALYST_OUTPUT_DIR}"/OneSignal

echo "> Copying Framework Structure to Universal Output Directory"
cp -a ${IPHONE_OUTPUT_DIR} ${UNIVERSAL_DIR}

cd $UNIVERSAL_DIR
echo "> Moving OneSignal fat binary to Final Framework"
mv OneSignal OneSignal.framework

cd $FINAL_FRAMEWORK

declare -a files=("Headers" "Modules" "OneSignal")

# Create the Versions folders
mkdir Versions
mkdir Versions/A
mkdir Versions/A/Resources

# Move the framework files/folders
for name in "${files[@]}"; do
   mv ${name} Versions/A/${name}
done

# Create symlinks at the root of the framework
for name in "${files[@]}"; do
   ln -s Versions/A/${name} ${name}
done

# move info.plist into Resources and create appropriate symlinks
mv Info.plist Versions/A/Resources/Info.plist
ln -s Versions/A/Resources Resources

# Create a symlink directory for 'Versions/A' called 'Current'
cd Versions
ln -s A Current

# Copy the built product to the final destination in {repo}/iOS_SDK/OneSignalSDK/Framework
rm -rf "${WORKING_DIR}/Framework/OneSignal.framework"
cp -a "${FINAL_FRAMEWORK}" "${WORKING_DIR}/Framework/OneSignal.framework"

echo "Opening final release framework in Finder:${WORKING_DIR}/Framework/OneSignal.framework"
open ${WORKING_DIR}/Framework

echo "Done"
