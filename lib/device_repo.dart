import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/painting.dart';

import 'dates.dart';
import 'models.dart';
import 'repo.dart';
import 'skins.dart';
import 'tags.dart';
import 'theme.dart';

/// 실제 기기 캘린더(iOS 캘린더, 구글 캘린더 등)를 읽고 쓰는 저장소
class DeviceRepo implements CalendarRepo {
  DeviceRepo() : _plugin = DeviceCalendar.instance;

  final DeviceCalendar _plugin;
  Map<String, CalInfo> _cal = <String, CalInfo>{};

  static List<Color> get _fallback => Skin.current.events;

  @override
  bool get isDemo => false;

  PermState _map(CalendarPermissionStatus s) {
    if (s == CalendarPermissionStatus.granted) return PermState.granted;
    if (s == CalendarPermissionStatus.writeOnly) return PermState.writeOnly;
    if (s == CalendarPermissionStatus.restricted) return PermState.restricted;
    if (s == CalendarPermissionStatus.denied) return PermState.denied;
    return PermState.unknown;
  }

  @override
  Future<PermState> permission() async => _map(await _plugin.hasPermissions());

  @override
  Future<PermState> requestPermission() async =>
      _map(await _plugin.requestPermissions());

  @override
  Future<void> openSettings() => _plugin.openAppSettings();

  @override
  Future<List<CalInfo>> calendars() async {
    final list = await _plugin.listCalendars();
    final out = <CalInfo>[];
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      if (c.hidden) continue;
      out.add(CalInfo(
        id: c.id,
        name: c.name,
        color: c.color == null ? _fallback[i % _fallback.length] : calmColor(c.color!),
        readOnly: c.readOnly,
        isPrimary: c.isPrimary,
        account: c.accountName,
      ));
    }
    _cal = {for (final c in out) c.id: c};
    return out;
  }

  /// 시간대 없이 "날짜만" 쓰는 값(종일 일정)은 UTC 로 올 수 있어서 숫자 그대로 읽어요.
  static DateTime _floating(DateTime d) =>
      d.isUtc ? DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second) : d;

  @override
  Future<List<Ev>> events(DateTime from, DateTime to) async {
    if (_cal.isEmpty) await calendars();
    final list = await _plugin.listEvents(from, to);
    final out = <Ev>[];
    for (final e in list) {
      final cal = _cal[e.calendarId];
      final calName = cal?.name ?? '';
      DateTime s;
      DateTime t;
      if (e.isAllDay) {
        final sd = _floating(e.startDate);
        final ed = _floating(e.endDate);
        s = dayOnly(sd);
        final edDay = dayOnly(ed);
        final midnight = ed.hour == 0 && ed.minute == 0 && ed.second == 0;
        if (midnight && edDay.isAfter(s)) {
          t = edDay;
        } else {
          t = addDays(edDay.isBefore(s) ? s : edDay, 1);
        }
      } else {
        s = e.startDate.toLocal();
        t = e.endDate.toLocal();
        if (t.isBefore(s)) t = s;
      }
      final rawTitle = e.title.trim();
      final parts = splitTags(rawTitle);
      out.add(Ev(
        id: e.eventId,
        instanceId: e.instanceId,
        calendarId: e.calendarId,
        calendarName: calName,
        title: rawTitle.isEmpty ? '(제목 없음)' : parts.title,
        tags: rawTitle.isEmpty ? const <String>[] : parts.tags,
        start: s,
        end: t,
        allDay: e.isAllDay,
        color: e.color != null ? calmColor(e.color!) : (cal?.color ?? _fallback[0]),
        location: e.location,
        note: e.description,
        attendees: e.attendees?.length ?? 0,
        recurring: e.isRecurring,
        readOnly: cal?.readOnly ?? false,
        holiday: isHolidayName(calName),
        reminders: e.reminders ?? const <Duration>[],
      ));
    }
    return out;
  }

  @override
  Future<void> create({
    String? calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? location,
    List<String> tags = const <String>[],
    Repeat? repeat,
  }) async {
    var cid = calendarId;
    if (cid == null) {
      if (_cal.isEmpty) await calendars();
      for (final c in _cal.values) {
        if (c.readOnly) continue;
        cid = c.id;
        if (c.isPrimary) break;
      }
    }
    if (cid == null) throw StateError('쓸 수 있는 캘린더가 없어요');
    await _plugin.createEvent(
      calendarId: cid,
      title: joinTags(title, tags),
      startDate: start,
      endDate: end,
      isAllDay: allDay,
      location: location,
      recurrenceRule: _rule(repeat),
    );
  }

  /// 앱의 반복 설정을 기기 캘린더의 반복 규칙으로 바꿔요. (끝나는 날은 그날 23:59:59 까지 포함)
  static RecurrenceRule? _rule(Repeat? r) {
    if (r == null) return null;
    final u = r.until;
    final DateTime? untilUtc =
        u == null ? null : DateTime(u.year, u.month, u.day, 23, 59, 59).toUtc();
    if (r.kind == RepeatKind.daily) {
      return DailyRecurrence(end: untilUtc == null ? null : UntilEnd(untilUtc));
    }
    final b = StringBuffer('FREQ=WEEKLY');
    if (r.kind == RepeatKind.weekdays) b.write(';BYDAY=MO,TU,WE,TH,FR');
    if (untilUtc != null) {
      b.write(
        ';UNTIL=${untilUtc.year}${two(untilUtc.month)}${two(untilUtc.day)}'
        'T${two(untilUtc.hour)}${two(untilUtc.minute)}${two(untilUtc.second)}Z',
      );
    }
    final rule = RecurrenceRule.fromRruleString(b.toString());
    if (rule == null) throw StateError('반복 규칙을 만들지 못했어요');
    return rule;
  }

  @override
  Future<void> move(Ev e, DateTime start, DateTime end) async {
    await _plugin.updateEvent(
      instanceId: e.instanceId,
      startDate: start,
      endDate: end,
    );
  }

  static Patch<String> _text(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? const Patch<String>.clear() : Patch<String>.set(t);
  }

  @override
  Future<void> update(
    Ev e, {
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String? location,
    String? note,
    List<String> tags = const <String>[],
  }) async {
    await _plugin.updateEvent(
      instanceId: e.instanceId,
      title: joinTags(title, tags),
      startDate: start,
      endDate: end,
      isAllDay: allDay,
      location: _text(location),
      description: _text(note),
    );
  }

  @override
  Future<void> setTags(Ev e, List<String> tags) async {
    final title = joinTags(e.title, tags);
    if (e.recurring) {
      // 반복 일정은 시리즈 전체의 제목을 고쳐요.
      await _plugin.updateRecurring(e.instanceId, EventSpan.allEvents, title: title);
    } else {
      await _plugin.updateEvent(instanceId: e.instanceId, title: title);
    }
  }

  @override
  Future<void> delete(Ev e) async {
    await _plugin.deleteEvent(instanceId: e.instanceId);
  }

  @override
  Future<void> openEditor(Ev e) async {
    await _plugin.showEventModal(e.id, edit: true);
  }
}
