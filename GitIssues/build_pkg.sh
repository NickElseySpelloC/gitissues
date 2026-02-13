#!/bin/bash

# Script to build and optionally notarize a .pkg installer for GitIssues
# Usage: ./build-pkg.sh /path/to/GitIssues.app [--submit]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set project home directory (where this script lives)
HomeDir=$(cd "$(dirname "$0")" && pwd)

# Load environment variables from .env if present (in HomeDir)
# Note: this "sources" the file, so it should contain simple KEY=VALUE lines.
EnvFile="$HomeDir/.env"
if [ -f "$EnvFile" ]; then
  echo -e "${YELLOW}Loading environment from $EnvFile ...${NC}"
  set -a
  # shellcheck disable=SC1090
  . "$EnvFile"
  set +a
fi

# Configuration - make sure all required variables are set
: "${APP_IDENTIFIER:?Error: APP_IDENTIFIER is not set}"
: "${INSTALLER_CERT:?Error: INSTALLER_CERT is not set}"
: "${KEYCHAIN_PROFILE:?Error: KEYCHAIN_PROFILE is not set}"

# Parse arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No app path provided${NC}"
    echo "Usage: $0 /path/to/GitIssues.app [--submit]"
    exit 1
fi

APP_PATH="$1"
SUBMIT_TO_APPLE=false

if [ "$2" == "--submit" ]; then
    SUBMIT_TO_APPLE=true
fi

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

# Get app name and directory
APP_NAME=$(basename "$APP_PATH" .app)
APP_DIR=$(dirname "$APP_PATH")


echo -e "${GREEN}=== Building .pkg for $APP_NAME ===${NC}"
echo "App path: $APP_PATH"
echo "Output directory: $APP_DIR"
echo ""

# Get app version from Info.plist
APP_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "1")
echo "App version: $APP_VERSION (build $BUILD_VERSION)"

# Verify app is signed
echo -e "${YELLOW}Verifying app signature...${NC}"
if ! codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo -e "${RED}Error: App is not properly signed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ App signature verified${NC}"

# Check for timestamp
if ! codesign -dvv "$APP_PATH" 2>&1 | grep -q "Timestamp"; then
    echo -e "${YELLOW}Warning: App signature does not include a timestamp${NC}"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo ""
echo -e "${YELLOW}Creating package structure in $TEMP_DIR${NC}"

# Create payload directory
mkdir -p "$TEMP_DIR/Applications"

# # Avoid creating those ._ AppleDouble files
export COPYFILE_DISABLE=1

# Copy the app using ditto to preserve permissions and avoid resource fork issues
ditto "$APP_PATH" "$TEMP_DIR/Applications/${APP_NAME}.app"

# Verify that the app was copied correctly
test -d "$TEMP_DIR/Applications/${APP_NAME}.app" && echo -e "${GREEN}✓ Staged app exists${NC}" || { echo -e "${RED}❌ Staged app missing${NC}"; exit 1; }

# Generate a component plist and force non-relocatable install
COMP_FILE="$TEMP_DIR/${APP_NAME}-component.plist"
pkgbuild --analyze --root "$TEMP_DIR" "$COMP_FILE"

# Set BundleIsRelocatable=false for all bundles in the component plist (safe for this use case)
# If you prefer, edit $COMP manually instead.
plutil -replace BundleIsRelocatable -bool NO "$COMP_FILE" 2>/dev/null || true


# Build signed pkg using the component plist
OUTPUT_PKG="$APP_DIR/${APP_NAME}-${APP_VERSION}.$(printf "%04d" "$BUILD_VERSION").pkg"

echo ""
echo -e "${YELLOW}Building component package: $OUTPUT_PKG${NC}"

pkgbuild \
  --root "$TEMP_DIR" \
  --install-location "/" \
  --component-plist "$COMP_FILE" \
  --identifier "$APP_IDENTIFIER" \
  --version "$APP_VERSION" \
  --sign "$INSTALLER_CERT" \
  "$OUTPUT_PKG"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Component package created${NC}"
else
    echo -e "${RED}Error: Failed to create component package${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓ Cleaned up temporary files${NC}"

# Verify package signature
echo ""
echo -e "${YELLOW}Verifying package signature...${NC}"
echo "----------------------------------------"
pkgutil --check-signature "$OUTPUT_PKG"
echo "----------------------------------------"

# Check with spctl (expected to fail until notarized)
echo ""
if spctl --assess --type install "$OUTPUT_PKG" 2>/dev/null; then
    echo -e "${GREEN}✓ Package passes Gatekeeper assessment${NC}"
else
    echo -e "${YELLOW}⚠ Package not yet notarized (this is expected)${NC}"
fi

echo ""
echo -e "${GREEN}=== Package Created Successfully ===${NC}"
echo "Location: $OUTPUT_PKG"
echo "Size: $(du -h "$OUTPUT_PKG" | cut -f1)"

# Submit to Apple if requested
if [ "$SUBMIT_TO_APPLE" = true ]; then
    echo ""
    echo -e "${YELLOW}=== Submitting to Apple for Notarization ===${NC}"
    echo "This may take a few minutes..."
    echo ""
    
    xcrun notarytool submit "$OUTPUT_PKG" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait
    
    NOTARIZATION_EXIT_CODE=$?
    
    if [ $NOTARIZATION_EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Notarization successful!${NC}"
        echo ""
        echo -e "${YELLOW}Stapling notarization ticket...${NC}"
        
        xcrun stapler staple "$OUTPUT_PKG"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Ticket stapled successfully${NC}"
            echo ""
            echo -e "${YELLOW}Final verification...${NC}"
            spctl --assess --type install "$OUTPUT_PKG"
            echo -e "${GREEN}✓ Package is ready for distribution!${NC}"
        else
            echo -e "${RED}Error: Failed to staple ticket${NC}"
            exit 1
        fi
    else
        echo ""
        echo -e "${RED}Notarization failed or is still in progress${NC}"
        echo "Check status with:"
        echo "  xcrun notarytool history --keychain-profile $KEYCHAIN_PROFILE"
        exit 1
    fi
else
    echo ""
    echo -e "${YELLOW}To submit for notarization, run:${NC}"
    echo "  xcrun notarytool submit \"$OUTPUT_PKG\" --keychain-profile \"$KEYCHAIN_PROFILE\" --wait"
    echo ""
    echo -e "${YELLOW}Or re-run this script with --submit flag:${NC}"
    echo "  $0 \"$APP_PATH\" --submit"
fi

echo ""
echo -e "${GREEN}Done!${NC}"