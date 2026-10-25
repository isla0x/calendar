# 여백

한눈에 보이고, 비는 시간까지 알려주는 캘린더 앱. Flutter, iOS·Android.

- 월간: 일정 막대 + 바쁜 날일수록 진한 배경
- 오늘: 남은 여유 시간, 지난 일정 접기, 비는 시간 칸
- 주간: 7일을 가로 막대로 쌓아 한눈에 비교
- 한 줄 입력: "내일 오후 3시 치과 30분" 처럼 쓰면 날짜·시간·길이를 읽어요
- 기기 캘린더(iOS 캘린더 / 구글 캘린더 등)를 그대로 읽고 씁니다

## 처음 한 번

```bash
bash tools/bootstrap.sh     # ios / android 폴더를 만들고 권한 문구를 넣어요
flutter pub get
flutter run                 # 아이폰을 연결하고 실행
```

- 권한을 허용하기 전에는 "샘플로 먼저 둘러보기"로 데모 데이터를 볼 수 있어요.
- 앱 이름은 `lib/app_info.dart` 와 `tools/bootstrap.sh` 의 `APP_NAME` 두 곳이에요.
- 번들 ID 는 `com.isla0x.yeobaek` 예요(`tools/bootstrap.sh` 의 `ORG`, `PROJECT`). 앱스토어에 올리기 전에 꼭 확정해요.

## 구조

```
lib/
  app_info.dart      앱 이름
  main.dart          시작 + 테마 + 앱 상태 연결
  theme.dart         색(라이트/다크), 글자, 일정 색 만들기
  dates.dart         날짜·시간 도우미
  models.dart        일정(Ev), 캘린더(CalInfo)
  repo.dart          저장소 인터페이스
  device_repo.dart   기기 캘린더 연동 (device_calendar_plus)
  demo_repo.dart     샘플 데이터
  store.dart         앱 상태, 비는 시간·바쁨 단계 계산
  parser.dart        한 줄 입력 읽기
  ui/                화면들
```
