# Generates a universal/fat framework that can be used in multiple architectures (x86_64 and arm64) to support both simulator and actual devices.
# Note: When complete, this build script takes the fat framework and moves it to the {project root}/iOS_SDK/OneSignalSDK/Framework folder
# 
# INPUT ENVIRONMENTAL VARIABLES (set in Xcode project settings for our Aggregate targets)
#     $ONESIGNAL_DESTINATION_PATH: The path where the final fat framework should be copied to
#            eg: ${SRCROOT}/Framework
#
#     $ONESIGNAL_OUTPUT_NAME: The name of the framework produced (ie. {OneSignal}.framework)
#
#     $ONESIGNAL_TARGET_NAME: The name of the actual Xcode target that produces the framework
#
#     #ONESIGNAL_MACH_O_TYPE: Determines if the project is build as a static or dynamic library

set -e
set -o pipefail

# Build x86 based framework to support iOS simulator 
xcodebuild -configuration "${CONFIGURATION}" -project "${PROJECT_NAME}.xcodeproj" -target ${ONESIGNAL_TARGET_NAME} -sdk "iphonesimulator${SDK_VERSION}" "${ACTION}" ONLY_ACTIVE_ARCH=NO BITCODE_GENERATION_MODE=bitcode RUN_CLANG_STATIC_ANALYZER=NO CLANG_ENABLE_MODULE_DEBUGGING=NO BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" SYMROOT="${SYMROOT}" MACH_O_TYPE=${ONESIGNAL_MACH_O_TYPE} -UseModernBuildSystem=NO

# Build arm based framework to support actual iOS devices
xcodebuild -configuration "${CONFIGURATION}" -project "${PROJECT_NAME}.xcodeproj" -target ${ONESIGNAL_TARGET_NAME} -sdk "iphoneos${SDK_VERSION}" "${ACTION}" ONLY_ACTIVE_ARCH=NO BITCODE_GENERATION_MODE=bitcode RUN_CLANG_STATIC_ANALYZER=NO CLANG_ENABLE_MODULE_DEBUGGING=NO BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" SYMROOT="${SYMROOT}" MACH_O_TYPE=${ONESIGNAL_MACH_O_TYPE} -UseModernBuildSystem=NO

CURRENTCONFIG_DEVICE_DIR=${SYMROOT}/${CONFIGURATION}-iphoneos/${ONESIGNAL_OUTPUT_NAME}.framework
CURRENTCONFIG_SIMULATOR_DIR=${SYMROOT}/${CONFIGURATION}-iphonesimulator/${ONESIGNAL_OUTPUT_NAME}.framework
CREATING_UNIVERSAL_DIR=${SYMROOT}/${CONFIGURATION}-universal
FINAL_FRAMEWORK_LOCATION=${CREATING_UNIVERSAL_DIR}/${ONESIGNAL_OUTPUT_NAME}.framework
EXECUTABLE_DESTINATION=${FINAL_FRAMEWORK_LOCATION}/${ONESIGNAL_OUTPUT_NAME}

rm -rf "${CREATING_UNIVERSAL_DIR}"
mkdir "${CREATING_UNIVERSAL_DIR}"

# copy the device framework to the location
# when we use lipo to merge device/sim frameworks, it only 
# merges the actual binary. Thus, we need to copy all of the
# Framework files (such as headers and modulemap)
cp -a "${CURRENTCONFIG_DEVICE_DIR}" "${FINAL_FRAMEWORK_LOCATION}"

# This file gets replaced by lipo when building the fat/universal binary
rm "${FINAL_FRAMEWORK_LOCATION}/${ONESIGNAL_OUTPUT_NAME}"

# Combine results
# use lipo to combine device & simulator binaries into one
lipo -create -output "${EXECUTABLE_DESTINATION}" "${CURRENTCONFIG_DEVICE_DIR}/${ONESIGNAL_OUTPUT_NAME}" "${CURRENTCONFIG_SIMULATOR_DIR}/${ONESIGNAL_OUTPUT_NAME}"

# Move framework files to the location Versions/A/* and create
# symlinks at the root of the framework, and Versions/Current
cd $FINAL_FRAMEWORK_LOCATION

declare -a files=("Headers" "Modules" "${ONESIGNAL_OUTPUT_NAME}")

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
rm -rf "${ONESIGNAL_DESTINATION_PATH}/${ONESIGNAL_OUTPUT_NAME}.framework"
cp -a "${FINAL_FRAMEWORK_LOCATION}" "${ONESIGNAL_DESTINATION_PATH}/${ONESIGNAL_OUTPUT_NAME}.framework"