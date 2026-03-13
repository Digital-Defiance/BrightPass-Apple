#!/bin/bash

# Update version number across all project files
# Usage: ./scripts/update-version.sh <new_version>
# Example: ./scripts/update-version.sh 1.0.2

set -e

if [ $# -eq 0 ]; then
    echo "Error: No version number provided"
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.2"
    exit 1
fi

NEW_VERSION="$1"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format. Expected format: x.y.z (e.g., 1.0.2)"
    exit 1
fi

echo "Updating version to $NEW_VERSION..."

# Detect current version from the build script's generated Info.plist pattern
# We look in 1-build-app.sh since it's the source of truth for the version
CURRENT_VERSION=$(grep "CFBundleShortVersionString" -A 1 scripts/1-build-app.sh | grep "<string>" | head -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not detect current version from scripts/1-build-app.sh"
    exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Update 1-build-app.sh (Info.plist template)
if [ -f "scripts/1-build-app.sh" ]; then
    echo "Updating scripts/1-build-app.sh..."
    sed -i '' "s|<string>$CURRENT_VERSION</string>|<string>$NEW_VERSION</string>|g" scripts/1-build-app.sh
fi

# Update run-macos.sh (dev Info.plist)
if [ -f "run-macos.sh" ]; then
    echo "Updating run-macos.sh..."
    sed -i '' "s|<string>$CURRENT_VERSION</string>|<string>$NEW_VERSION</string>|g" run-macos.sh
fi

# Update README.md
if [ -f "README.md" ]; then
    echo "Updating README.md..."
    sed -i '' "s|/v$CURRENT_VERSION)|/v$NEW_VERSION)|g" README.md 2>/dev/null || true
    sed -i '' "s|v$CURRENT_VERSION|v$NEW_VERSION|g" README.md 2>/dev/null || true
fi

echo ""
echo "✅ Version updated from $CURRENT_VERSION to $NEW_VERSION"
echo ""
echo "Don't forget to:"
echo "  1. Review changes: git diff"
echo "  2. Commit: git add -A && git commit -m 'Bump version to $NEW_VERSION'"
echo "  3. Tag: git tag v$NEW_VERSION"
echo "  4. Push: git push && git push --tags"
