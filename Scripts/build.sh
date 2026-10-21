#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project ZeldaMacStudio.xcodeproj -scheme ZeldaMacStudio -configuration Release -derivedDataPath build/DerivedData build
printf '\nBuilt app: %s/build/DerivedData/Build/Products/Release/ZeldaMacStudio.app\n' "$PWD"
