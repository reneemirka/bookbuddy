#!/bin/zsh
set -euo pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BookBuddy.xcodeproj -scheme BookBuddy -sdk iphonesimulator -configuration Debug -derivedDataPath /private/tmp/bookbuddy-evals CODE_SIGNING_ALLOWED=NO build
