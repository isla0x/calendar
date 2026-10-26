#!/usr/bin/env bash
# iOS 홈 화면·잠금화면 위젯을 붙여요. Mac에서 한 번 실행하면 돼요 (여러 번 해도 괜찮아요).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d ios/Runner.xcodeproj ]; then
  echo "ios 폴더가 없어서 먼저 만들어요…"
  bash tools/bootstrap.sh
fi

# xcodeproj 는 CocoaPods 와 함께 깔려 있어요. 못 찾으면 한 번 설치해 봐요.
if ! ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
  gem install xcodeproj --user-install >/dev/null 2>&1 || sudo gem install xcodeproj >/dev/null
fi

ruby tools/add_widgets.rb
