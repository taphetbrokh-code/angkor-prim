#!/usr/bin/env bash
# Generates the Android project (if missing) and applies ANGKOR PRIM settings.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  flutter create --platforms=android --org com.angkorprim --project-name angkor_prim .
  # flutter create adds a sample test that doesn't match this app
  rm -f test/widget_test.dart
fi

cp tool/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
mkdir -p android/app/src/main/res/drawable
cp tool/android/ic_notification.xml android/app/src/main/res/drawable/ic_notification.xml

# Keep resources used only by name from Dart (notification icon).
mkdir -p android/app/src/main/res/raw
cat > android/app/src/main/res/raw/keep.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
XML

# minSdk 21+ is required by audio_service; Flutter's default is already >= 21.
echo "Android project ready."
