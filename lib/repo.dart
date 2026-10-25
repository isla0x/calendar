import 'models.dart';

enum PermState { unknown, granted, denied, writeOnly, restricted }

/// 일정을 읽고 쓰는 곳. 실제 기기 캘린더(DeviceRepo) 또는 샘플(DemoRepo).
abstract class CalendarRepo {
  bool get isDemo;

  Future<PermState> permission();
  Future<PermState> requestPermission();
  Future<void> openSettings();

  Future<List<CalInfo>> calendars();

  /// from ~ to 와 겹치는 일정
  Future<List<Ev>> events(DateTime from, DateTime to);

  Future<void> create({
    String? calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    List<String> tags = const <String>[],
    Repeat? repeat,
  });

  Future<void> move(Ev e, DateTime start, DateTime end);

  /// 일정을 고쳐서 저장해요 (제목·날짜·시간·종일·장소·메모·태그). 반복 일정은 이 일정 하나만 바뀌어요.
  /// 종일 일정의 [end] 는 마지막 날의 다음 날 00:00 (끝 미포함) 이에요.
  Future<void> update(
    Ev e, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String? location,
    String? note,
    List<String> tags = const <String>[],
  });

  Future<void> delete(Ev e);

  /// 일정의 태그를 바꿔요 (기기 캘린더에서는 제목 끝의 "#태그" 를 고쳐요).
  Future<void> setTags(Ev e, List<String> tags);

  /// 기기 기본 일정 편집 화면을 열어요.
  Future<void> openEditor(Ev e);
}
