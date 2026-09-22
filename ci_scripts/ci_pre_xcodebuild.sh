#!/bin/sh
#
#  ci_pre_xcodebuild.sh
#  KitchenOS
#
#  Xcode Cloud owns the build number. Without this, every CI archive reuses
#  whatever CURRENT_PROJECT_VERSION is committed in the pbxproj, and App Store
#  Connect rejects the upload with "The bundle version must be higher than the
#  previously uploaded version" as soon as that number has been used once.
#
#  https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds
#
#  CI_BUILD_NUMBER increments per Xcode Cloud build but starts low, so it is
#  offset past the highest build already uploaded by hand (41, on 2026-09-21).
#  Raise BUILD_NUMBER_OFFSET only if a build is ever uploaded outside CI again.
#

set -eu

BUILD_NUMBER_OFFSET=41

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
    echo "⚠️  CI_BUILD_NUMBER is not set — not running in Xcode Cloud. Leaving the build number alone."
    exit 0
fi

BUILD_NUMBER=$((CI_BUILD_NUMBER + BUILD_NUMBER_OFFSET))

# The script runs inside ci_scripts/, and agvtool needs the directory holding
# the .xcodeproj — which is the repository root, one level up.
cd ..

echo "🔢 Setting build number to ${BUILD_NUMBER} (CI_BUILD_NUMBER=${CI_BUILD_NUMBER} + offset ${BUILD_NUMBER_OFFSET})"
agvtool new-version -all "${BUILD_NUMBER}"

echo "✅ Build number set to ${BUILD_NUMBER}"
