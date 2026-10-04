#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Answers Watch App..."

# 1. Identify booted or available watchOS simulator
WATCH_UDID=$(xcrun simctl list devices | grep -E "Apple Watch.*\(Booted\)" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

if [ -z "$WATCH_UDID" ]; then
    echo "No booted Apple Watch simulator found. Looking for an available watch..."
    WATCH_UDID=$(xcrun simctl list devices | grep -E "Apple Watch Series (12|9|8|7|SE)" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
    if [ -z "$WATCH_UDID" ]; then
        echo "Error: No Apple Watch simulator found in Xcode!"
        exit 1
    fi
    echo "Booting simulator ($WATCH_UDID)..."
    xcrun simctl boot "$WATCH_UDID" 2>/dev/null || true
else
    echo "Found running watch simulator: $WATCH_UDID"
fi

# 2. Open Simulator GUI or DeviceHub if available
if open -a Simulator 2>/dev/null; then
    echo "Opened Simulator app."
elif [ -d "/Applications/Xcode.app/Contents/Applications/DeviceHub.app" ]; then
    open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app" 2>/dev/null || true
fi

# 3. Build AnswersWatch app for the simulator
echo "Building AnswersWatch.app..."
xcodebuild -project AnswersWatch.xcodeproj \
    -scheme AnswersWatch \
    -destination "id=$WATCH_UDID" \
    CODE_SIGNING_ALLOWED=NO \
    build -quiet

# Locate built .app bundle
BUILD_DIR=$(xcodebuild -project AnswersWatch.xcodeproj -scheme AnswersWatch -destination "id=$WATCH_UDID" -showBuildSettings | grep " BUILD_ROOT =" | head -n 1 | awk '{print $3}')
APP_PATH="$BUILD_DIR/Debug-watchsimulator/AnswersWatch.app"

if [ ! -d "$APP_PATH" ]; then
    # Fallback to DerivedData default
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/AnswersWatch-*/Build/Products/Debug-watchsimulator/AnswersWatch.app -maxdepth 0 2>/dev/null | head -n 1)
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: AnswersWatch.app not found at $APP_PATH"
    exit 1
fi

echo "App built at: $APP_PATH"

# 4. Install onto simulator
echo "Installing app onto watch simulator..."
xcrun simctl install "$WATCH_UDID" "$APP_PATH"

# 5. Terminate previous session if active and launch fresh
echo "Launching Answers on Apple Watch..."
xcrun simctl terminate "$WATCH_UDID" com.learning.answers.watch 2>/dev/null || true
xcrun simctl launch "$WATCH_UDID" com.learning.answers.watch

echo "Answers running on watch."
