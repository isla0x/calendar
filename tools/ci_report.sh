#!/usr/bin/env bash
# CI에서 명령을 실행하고, 실패하면 출력 마지막 부분을 GitHub 주석(annotation)으로 남겨요.
# 사용법: bash tools/ci_report.sh <제목> <명령...>
title="$1"
shift
set +e
"$@" > ci_out.txt 2>&1
code=$?
cat ci_out.txt
if [ "$code" -ne 0 ]; then
  msg=$(python3 -c "
t = open('ci_out.txt', encoding='utf-8', errors='replace').read()
t = t.replace('%', '%25').replace('\r', '').replace('\n', '%0A')
print(t[-30000:])
")
  echo "::error title=${title}::${msg}"
fi
exit "$code"
