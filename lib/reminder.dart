import 'dates.dart';
import 'l10n.dart';

/// 일정 알림 시점. 기기 캘린더의 알림(일정 시작보다 몇 분 앞)으로 저장돼서,
/// 앱을 꺼 둬도 아이폰이 알려줘요.
enum Reminder { atTime, min10, hour1, morning, eveningBefore, morningBefore }

/// 아침·저녁 알림 시각
const int reminderMorningHour = 8;
const int reminderEveningHour = 18;

extension ReminderX on Reminder {
  /// 일정 종류에 따라 고를 수 있는 목록. 종일 일정은 시작이 0시라 "전날"만 있어요.
  static List<Reminder> options({required bool allDay}) => allDay
      ? const <Reminder>[Reminder.eveningBefore, Reminder.morningBefore]
      : const <Reminder>[
          Reminder.atTime,
          Reminder.min10,
          Reminder.hour1,
          Reminder.morning,
          Reminder.eveningBefore,
        ];

  String get label => switch (this) {
        Reminder.atTime => tl('정각'),
        Reminder.min10 => tl('10분 전'),
        Reminder.hour1 => tl('1시간 전'),
        Reminder.morning => tl('당일 아침'),
        Reminder.eveningBefore => tl('전날 저녁'),
        Reminder.morningBefore => tl('전날 아침'),
      };

  /// 알림이 울리는 때
  DateTime fireAt(DateTime start) => switch (this) {
        Reminder.atTime => start,
        Reminder.min10 => start.subtract(const Duration(minutes: 10)),
        Reminder.hour1 => start.subtract(const Duration(hours: 1)),
        Reminder.morning => DateTime(start.year, start.month, start.day, reminderMorningHour),
        Reminder.eveningBefore => DateTime(start.year, start.month, start.day - 1, reminderEveningHour),
        Reminder.morningBefore => DateTime(start.year, start.month, start.day - 1, 9),
      };

  /// 일정 시작보다 얼마나 앞서 울리는지. 시작보다 늦게 울려야 하면(예: 오전 7시 일정의 "당일 아침") null.
  Duration? offset(DateTime start) {
    final d = start.difference(fireAt(start));
    if (d.isNegative) return null;
    if (this == Reminder.morning && d.inMinutes <= 0) return null;
    return d;
  }

  /// 기기에 저장할 알림 목록 (없으면 빈 목록)
  static List<Duration> toList(Reminder? r, DateTime start) {
    final d = r?.offset(start);
    return d == null ? const <Duration>[] : <Duration>[d];
  }

  /// 기기에 저장돼 있던 알림이 위 선택지 중 어느 것인지 (없으면 null)
  static Reminder? match(List<Duration> list, DateTime start, {required bool allDay}) {
    for (final r in options(allDay: allDay)) {
      final o = r.offset(start);
      if (o == null) continue;
      for (final d in list) {
        if (d.inMinutes == o.inMinutes) return r;
      }
    }
    return null;
  }

  /// 선택지에 없는 알림을 읽기 좋게 ("30분 전", "2시간 전", "1일 전")
  static String describe(Duration d) {
    final m = d.inMinutes.abs();
    if (m == 0) return tl('정각');
    if (m < 60) return tl('{0}분 전 알림', [m]);
    if (m < 24 * 60) {
      final h = m ~/ 60;
      final r = m % 60;
      return r == 0 ? tl('{0}시간 전 알림', [h]) : tl('{0}시간 {1}분 전 알림', [h, r]);
    }
    return tl('{0}일 전 알림', [m ~/ (24 * 60)]);
  }

  /// 편집 화면에 보일 한 줄. 고른 선택지가 있으면 그 이름, 아니면 기기에 있던 알림 설명.
  static String summary(Reminder? picked, List<Duration> existing, {required bool touched}) {
    if (picked != null) return picked.label;
    if (touched || existing.isEmpty) return tl('없음');
    return describe(existing.first) + (existing.length > 1 ? tl(' 외') : '');
  }

  /// 알림이 울릴 때를 한 줄로 ("10월 27일 화 오후 2:00")
  static String fireText(Reminder r, DateTime start) {
    final f = r.fireAt(start);
    return '${dateChip(dayOnly(f))} ${ampm(f)}';
  }
}
