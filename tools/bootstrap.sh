#!/usr/bin/env bash
# 처음 한 번만 실행해요.
#  1) Flutter 플랫폼 폴더(ios / android)를 만들고
#  2) 캘린더 권한 문구, 앱 이름, 최소 안드로이드 버전을 넣어요.
# 이미 만들어져 있어도 다시 실행해도 괜찮아요(같은 값으로 덮어써요).
set -euo pipefail
cd "$(dirname "$0")/.."

ORG="${ORG:-com.isla0x}"          # 번들 ID 앞부분. 앱스토어 등록 전에 꼭 확인해요.
APP_NAME="${APP_NAME:-여백}"        # 홈 화면에 보이는 이름
PROJECT="yeobaek"                    # 번들 ID 끝부분 (com.isla0x.yeobaek)

if [ ! -d ios ] || [ ! -d android ]; then
  flutter create --org "$ORG" --project-name "$PROJECT" --platforms=ios,android .
fi
# flutter create가 만드는 기본 테스트는 이 앱과 맞지 않아서 지워요.
rm -f test/widget_test.dart

# ---------- iOS ----------
PLIST="ios/Runner/Info.plist"
PB="/usr/libexec/PlistBuddy"
if [ -f "$PLIST" ] && [ -x "$PB" ]; then
  setstr() { "$PB" -c "Set :$1 \"$2\"" "$PLIST" 2>/dev/null || "$PB" -c "Add :$1 string \"$2\"" "$PLIST"; }
  setstr CFBundleDisplayName "$APP_NAME"
  setstr NSCalendarsUsageDescription "내 캘린더의 일정을 보여주고, 비는 시간을 찾아드리기 위해 접근해요."
  setstr NSCalendarsFullAccessUsageDescription "내 캘린더의 일정을 보여주고, 새 일정을 추가·수정하기 위해 접근해요."
  setstr NSCalendarsWriteOnlyAccessUsageDescription "새 일정을 내 캘린더에 추가하기 위해 접근해요."
  # 백업 파일을 고르는 화면(file_picker)이 사진·카메라·위치 접근 코드를 포함해서 문구가 꼭 필요해요.
  setstr NSPhotoLibraryUsageDescription "백업 파일을 불러올 때 사진 보관함에서 파일을 고를 수 있도록 접근해요."
  setstr NSCameraUsageDescription "백업 파일을 불러올 때 카메라를 쓰는 기능이 포함돼 있어요. 여백은 카메라를 따로 쓰지 않아요."
  setstr NSLocationWhenInUseUsageDescription "여백은 위치를 사용하지 않아요. 연결된 구성 요소가 요구하는 안내 문구예요."
  "$PB" -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" 2>/dev/null \
    || "$PB" -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
  echo "iOS Info.plist 수정 완료"
else
  echo "iOS Info.plist는 Mac에서 다시 실행하면 수정돼요(지금은 건너뜀)"
fi

# ---------- Android ----------
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ] && ! grep -q "READ_CALENDAR" "$MANIFEST"; then
  perl -0pi -e 's|(<manifest[^>]*>)|$1\n    <uses-permission android:name="android.permission.READ_CALENDAR"/>\n    <uses-permission android:name="android.permission.WRITE_CALENDAR"/>|' "$MANIFEST"
  echo "AndroidManifest 권한 추가 완료"
fi
# device_calendar_plus는 minSdk 24 이상이 필요해요.
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i.bak -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 24/' "$f"
  rm -f "$f.bak"
done

# ---------- 앱 아이콘 ----------
# assets/icon/icon.png 로 iOS·Android 아이콘을 만들어요.
flutter pub get
dart run flutter_launcher_icons

echo "부트스트랩 끝!"
