#!/bin/zsh
set -euo pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project BookBuddy.xcodeproj -scheme BookBuddy -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/bookbuddy-evals CODE_SIGNING_ALLOWED=NO test
