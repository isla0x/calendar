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
  });

  Future<void> move(Ev e, DateTime start, DateTime end);

  Future<void> delete(Ev e);

  /// 기기 기본 일정 편집 화면을 열어요.
  Future<void> openEditor(Ev e);
}
