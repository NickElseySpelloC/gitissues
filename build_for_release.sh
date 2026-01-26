#!/bin/bash
set -e

# Configuration
PROJECT_DIR="$HOME/dev/gitissues/GitIssues"

cd "$PROJECT_DIR"

echo "Building GitIssues for release..."

# Build with minimal output (only warnings and errors)
xcodebuild archive \
  -project GitIssues.xcodeproj \
  -scheme GitIssues \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "Build/GitIssues.xcarchive" \
  -quiet \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO

# Check if build succeeded
if [[ $? -ne 0 ]]; then
  echo "Error: Build failed!"
  exit 1
fi

echo "Build succeeded!"

ARCHIVE="Build/GitIssues.xcarchive"
APP_SRC="$ARCHIVE/Products/Applications/GitIssues.app"

# Verify the app was created
if [[ ! -d "$APP_SRC" ]]; then
  echo "Error: GitIssues.app not found at expected location"
  exit 1
fi

mkdir -p Build/Release
ditto "$APP_SRC" "Build/Release/GitIssues.app"

# Zip it (keeps macOS bundle metadata correctly)
ditto -c -k --sequesterRsrc --keepParent \
  "Build/Release/GitIssues.app" \
  "Build/Release/GitIssues.zip"

echo "Release build complete: Build/Release/GitIssues.app"

# Ask if user wants to install to Applications
read -p "Copy GitIssues.app to /Applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf /Applications/GitIssues.app
  cp -R "Build/Release/GitIssues.app" /Applications/
  echo "Installed to /Applications/GitIssues.app"
fi
