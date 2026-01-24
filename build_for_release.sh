cd ~/dev/gitissues/GitIssues

xcodebuild archive \
  -project GitIssues.xcodeproj \
  -scheme GitIssues \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "build/GitIssues.xcarchive" \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO

ls -l ~/dev/gitissues/GitIssues/build

ARCHIVE="build/GitIssues.xcarchive"
APP_SRC="$ARCHIVE/Products/Applications/GitIssues.app"

mkdir -p build/Release
ditto "$APP_SRC" "build/Release/GitIssues.app"

# Zip it (keeps macOS bundle metadata correctly)
ditto -c -k --sequesterRsrc --keepParent \
  "build/Release/GitIssues.app" \
  "build/Release/GitIssues.zip"
