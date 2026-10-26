import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../skins.dart';
import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import '../travel.dart';
import 'common.dart';
import 'sheets.dart';
import 'travel_sheet.dart';
import 'tag_dialog.dart';
import '../l10n.dart';

/// 일정 편집 화면. 저장하면 고친 일정을 돌려줘요. (취소하면 null)
class EventEditPage extends StatefulWidget {
  const EventEditPage({super.key, required this.event});

  final Ev event;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  late final Ev _o = widget.event;
  late final TextEditingController _title = TextEditingController(text: _o.title);
  late final TextEditingController _loc = TextEditingController(text: _o.location ?? '');
  late final TextEditingController _note = TextEditingController(text: _o.note ?? '');

  late bool _allDay = _o.allDay;

  /// 종일이면 첫날(날짜만), 아니면 시작 시각
  late DateTime _start = _o.allDay ? _o.firstDay : _o.start;

  /// 종일이면 마지막 날(날짜만, 그날 포함), 아니면 끝 시각
  late DateTime _end = _o.allDay ? _o.lastDay : _o.end;

  late List<String> _tags = [..._o.tags];
  Color? _color;
  bool _colorTouched = false;
  bool _saving = false;

  /// 종일을 켰다 끌 때 돌아갈 시각 (분)
  late int _m0 = _o.allDay ? 9 * 60 : _o.start.hour * 60 + _o.start.minute;
  late int _m1 = _o.allDay ? 10 * 60 : _o.end.hour * 60 + _o.end.minute;

  /// 이 일정이 들어 있는 프로젝트 (없으면 null)
  String? _projectId;

  /// 이동시간 (갈 때 / 올 때)
  Travel _travel = Travel.none;
  bool _travelTouched = false;

  late final String _sig0;

  @override
  void initState() {
    super.initState();
    _color = StoreScope.read(context).customColorOf(_o);
    _projectId = StoreScope.read(context).projectOf(_o)?.id;
    _travel = StoreScope.read(context).travelOf(_o);
    _sig0 = _sig();
  }

  @override
  void dispose() {
    _title.dispose();
    _loc.dispose();
    _note.dispose();
    super.dispose();
  }

  String _sig() => [
        _title.text.trim(),
        _loc.text.trim(),
        _note.text.trim(),
        _allDay,
        _start.millisecondsSinceEpoch,
        _end.millisecondsSinceEpoch,
        _tags.join(','),
        _color?.toARGB32(),
        _projectId,
        _travel.before,
        _travel.after,
      ].join('|');

  bool get _dirty => _sig() != _sig0;

  bool get _valid => _allDay ? !_end.isBefore(_start) : _end.isAfter(_start);

  bool get _canSave => _title.text.trim().isNotEmpty && _valid && _dirty && !_saving;

  // ---------------------------------------------------------------- 값 바꾸기

  void _toggleAllDay(bool on) {
    setState(() {
      if (on) {
        _m0 = _start.hour * 60 + _start.minute;
        _m1 = _end.hour * 60 + _end.minute;
        final lastDay = _end.isAfter(_start) ? dayOnly(_end.subtract(const Duration(microseconds: 1))) : dayOnly(_start);
        _start = dayOnly(_start);
        _end = lastDay.isBefore(_start) ? _start : lastDay;
      } else {
        final s = dayOnly(_start).add(Duration(minutes: _m0));
        var e = dayOnly(_end).add(Duration(minutes: _m1));
        if (!e.isAfter(s)) e = s.add(const Duration(hours: 1));
        _start = s;
        _end = e;
      }
      _allDay = on;
    });
  }

  void _setStartDate(DateTime d) {
    if (_allDay) {
      final n = daysBetween(_start, _end);
      _start = dayOnly(d);
      _end = addDays(_start, n);
    } else {
      final dur = _end.difference(_start);
      _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
      _end = _start.add(dur);
    }
  }

  void _setStartTime(DateTime t) {
    final dur = _end.difference(_start);
    _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
    _end = _start.add(dur);
  }

  void _setEndDate(DateTime d) {
    if (_allDay) {
      _end = dayOnly(d).isBefore(_start) ? _start : dayOnly(d);
    } else {
      _end = DateTime(d.year, d.month, d.day, _end.hour, _end.minute);
    }
  }

  void _setEndTime(DateTime t) {
    _end = DateTime(_end.year, _end.month, _end.day, t.hour, t.minute);
  }

  Future<void> _pickStartDate() async {
    final d = await showDateSheet(context, initial: _start, title: tl('시작하는 날'));
    if (d != null && mounted) setState(() => _setStartDate(d));
  }

  Future<void> _pickStartTime() async {
    final t = await showTimeSheet(context, initial: _start, title: tl('시작 시각'));
    if (t != null && mounted) setState(() => _setStartTime(t));
  }

  Future<void> _pickEndDate() async {
    final d = await showDateSheet(
      context,
      initial: _end,
      first: dayOnly(_start),
      title: tl('끝나는 날'),
    );
    if (d != null && mounted) setState(() => _setEndDate(d));
  }

  Future<void> _pickEndTime() async {
    final t = await showTimeSheet(context, initial: _end, title: tl('끝나는 시각'));
    if (t != null && mounted) setState(() => _setEndTime(t));
  }

  Future<void> _editTags() async {
    final store = StoreScope.read(context);
    final r = await showTagDialog(
      context,
      initial: _tags,
      known: store.knownTags().take(12).toList(),
    );
    if (r != null && mounted) setState(() => _tags = r);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final store = StoreScope.read(context);
    final parts = splitTags(_title.text.trim());
    final tags = [..._tags];
    for (final t in parts.tags) {
      if (!tags.contains(t)) tags.add(t);
    }
    final start = _allDay ? dayOnly(_start) : _start;
    final end = _allDay ? addDays(dayOnly(_end), 1) : _end;
    setState(() => _saving = true);
    final ok = await store.updateEvent(
      _o,
      title: parts.title,
      start: start,
      end: end,
      allDay: _allDay,
      location: _loc.text,
      note: _note.text,
      tags: tags,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.error ?? tl('일정을 저장하지 못했어요'))),
      );
      return;
    }
    if (_colorTouched) await store.setEventColor(_o, _color);
    if (_projectId != store.projectOf(_o)?.id) await store.setEventProject(_o, _projectId);
    if (_travel != store.travelOf(_o)) await store.setEventTravel(_o, _allDay ? Travel.none : _travel);
    if (!mounted) return;
    final fresh = store.findEvent(_o.id, start: start) ?? _o.copyWith(start: start, end: end, tags: tags);
    Navigator.of(context).pop(fresh);
  }

  Future<void> _pickProject() async {
    final store = StoreScope.read(context);
    final list = store.projects;
    final r = await showAppSheet<_ProjPick>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        Widget row(String? id, String name, Color? dot) => Tap(
              onTap: () => Navigator.of(ctx).pop(_ProjPick(id)),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    if (dot != null) Dot(dot, size: 10) else const SizedBox(width: 10),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: ts(ctx, 16, weight: FontWeight.w600))),
                    if (_projectId == id) Icon(Icons.check_rounded, size: 20, color: p.ink),
                  ],
                ),
              ),
            );
        return SheetFrame(
          title: tl('프로젝트'),
          subtitle: tl('태그와는 별개로 이 일정을 프로젝트에 넣어요.'),
          child: Column(
            children: [
              row(null, tl('없음'), null),
              for (final pr in list) row(pr.id, pr.name, pr.color),
            ],
          ),
        );
      },
    );
    if (r == null || !mounted) return;
    setState(() => _projectId = r.id);
  }

  Future<void> _pickTravel() async {
    final r = await showTravelSheet(context, initial: _travel, place: _loc.text);
    if (r == null || !mounted) return;
    setState(() {
      _travel = r;
      _travelTouched = true;
    });
  }

  Future<void> _askDiscard() async {
    final yes = await showConfirmSheet(
      context,
      title: tl('고친 내용을 버릴까요?'),
      body: tl('저장하지 않은 변경은 사라져요.'),
      yes: tl('버리기'),
      no: tl('계속 고치기'),
      danger: true,
    );
    if (yes && mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- 화면

  String _dateText(DateTime d, DateTime today) {
    final y = d.year == today.year ? '' : '${yText(d.year)} ';
    return '$y${dateChip(d)}';
  }

  List<Ev> _conflicts(CalendarStore s) {
    if (_allDay || !_valid) return const <Ev>[];
    final day = dayOnly(_start);
    return s
        .eventsOn(day)
        .where((e) =>
            !e.allDay &&
            e.instanceId != _o.instanceId &&
            e.start.isBefore(_end) &&
            e.end.isAfter(_start))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final today = store.today;

    CalInfo? cal;
    for (final c in store.calendars) {
      if (c.id == _o.calendarId) cal = c;
    }
    final calColor = cal?.color ?? _o.color;
    final shownColor = _color ?? calColor;
    final cc = evColors(shownColor, p);

    final conflicts = _conflicts(store);
    String summary;
    Color summaryColor = p.muted;
    IconData? summaryIcon;
    if (!_valid) {
      summary = tl('끝나는 시각이 시작보다 빨라요');
      summaryColor = p.red;
      summaryIcon = Icons.error_outline_rounded;
    } else if (_allDay) {
      final n = daysBetween(_start, _end) + 1;
      summary = n > 1 ? tl('{0}일 동안', [n]) : tl('하루 종일');
    } else {
      final dur = durText(_end.difference(_start));
      if (conflicts.isNotEmpty) {
        summary = tl('{0} · 겹치는 일정 {1}개', [dur, conflicts.length]);
        summaryColor = p.red;
        summaryIcon = Icons.error_outline_rounded;
      } else if (sameDay(_start, _end)) {
        summary = tl('{0} · 겹치는 일정 없음', [dur]);
        summaryColor = p.good;
        summaryIcon = Icons.check_rounded;
      } else {
        summary = tl('{0} · 여러 날에 걸친 하나의 일정이에요 (매일 반복이 아니에요)', [dur]);
      }
    }

    Widget divider() => Container(
          margin: const EdgeInsets.only(left: 52),
          height: 1,
          color: p.line,
        );

    Widget pill(String text, VoidCallback onTap) => Tap(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text, style: ts(context, 15, weight: FontWeight.w600)),
          ),
        );

    Widget timeRow(String label, DateTime d, VoidCallback pickDate, VoidCallback pickTime) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 9, 14, 9),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(label, style: ts(context, 15, color: p.muted)),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      pill(_dateText(d, today), pickDate),
                      if (!_allDay) ...[
                        const SizedBox(width: 8),
                        pill(ampm(d), pickTime),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget card(List<Widget> kids) => Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
        );

    Widget iconRow(IconData icon, Widget child, {bool top = false}) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
            child: Row(
              crossAxisAlignment: top ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: top ? 2 : 0),
                  child: Icon(icon, size: 20, color: p.muted),
                ),
                const SizedBox(width: 14),
                Expanded(child: child),
              ],
            ),
          ),
        );

    InputDecoration deco(String hint) => InputDecoration.collapsed(
          hintText: hint,
          hintStyle: ts(context, 15, weight: FontWeight.w400, color: p.dash),
        );

    Widget swatch(Color? c) {
      final on = _color == c || (c != null && _color != null && _color!.toARGB32() == c.toARGB32());
      final fill = c ?? calColor;
      return Tap(
        onTap: () => setState(() {
          _color = c;
          _colorTouched = true;
        }),
        label: c == null ? tl('캘린더 색') : tl('색 고르기'),
        child: Container(
          width: c == null ? null : 34,
          height: 34,
          padding: c == null ? const EdgeInsets.symmetric(horizontal: 12) : null,
          alignment: c == null ? null : Alignment.center,
          decoration: BoxDecoration(
            color: c == null ? p.surface : fill,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: on ? p.ink : (c == null ? p.line : Colors.transparent),
              width: on ? 2 : 1,
            ),
          ),
          child: c == null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Dot(fill, size: 10),
                    const SizedBox(width: 6),
                    Text(tl('기본'), style: ts(context, 13, weight: FontWeight.w600)),
                  ],
                )
              : (on ? Icon(Icons.check_rounded, size: 18, color: evColors(fill, p).onSolid.withAlpha(230)) : null),
        ),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askDiscard();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8, top + 4, 12, 0),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Tap(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(tl('취소'), style: ts(context, 16)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(tl('일정 편집'), style: ts(context, 17, weight: FontWeight.w700)),
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Tap(
                          onTap: _canSave ? _save : null,
                          child: Opacity(
                            opacity: _canSave ? 1 : 0.35,
                            child: Pill(
                              height: 36,
                              color: p.ink,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                tl('저장'),
                                style: ts(context, 15, weight: FontWeight.w600, color: p.bg),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      child: TextField(
                        controller: _title,
                        minLines: 1,
                        maxLines: 3,
                        cursorColor: p.ink,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        style: ts(
                          context,
                          26,
                          weight: FontWeight.w600,
                          height: 36 / 26,
                          letterSpacing: -0.78,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: tl('제목'),
                          hintStyle: ts(
                            context,
                            26,
                            weight: FontWeight.w600,
                            height: 36 / 26,
                            letterSpacing: -0.78,
                            color: p.dash,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_o.calendarName.isNotEmpty)
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: cc.tint,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Dot(shownColor, size: 8),
                                  const SizedBox(width: 6),
                                  Text(
                                    _o.calendarName,
                                    style: ts(context, 13, weight: FontWeight.w600, color: cc.text),
                                  ),
                                ],
                              ),
                            ),
                          if (_o.recurring)
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: p.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat_rounded, size: 15, color: p.muted),
                                  const SizedBox(width: 6),
                                  Text(
                                    tl('반복 일정 · 이 일정만 바뀌어요'),
                                    style: ts(context, 13, weight: FontWeight.w600, color: p.muted),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    card([
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 20, color: p.muted),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(tl('종일'), style: ts(context, 16, weight: FontWeight.w600)),
                            ),
                            AppSwitch(value: _allDay, onChanged: _toggleAllDay, label: tl('종일')),
                          ],
                        ),
                      ),
                      divider(),
                      timeRow(tl('시작'), _start, _pickStartDate, _pickStartTime),
                      divider(),
                      timeRow(tl('끝'), _end, _pickEndDate, _pickEndTime),
                      divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                        child: Row(
                          children: [
                            if (summaryIcon != null) ...[
                              Icon(summaryIcon, size: 16, color: summaryColor),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                summary,
                                style: ts(context, 13, weight: FontWeight.w600, color: summaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    card([
                      iconRow(
                        Icons.place_outlined,
                        TextField(
                          controller: _loc,
                          cursorColor: p.ink,
                          textInputAction: TextInputAction.next,
                          onChanged: (v) => setState(() {
                            // 기억해 둔 장소면 이동시간을 저절로 채워요
                            if (!_travelTouched && _travel.isNone && v.trim().isNotEmpty) {
                              _travel = StoreScope.read(context).travelForPlace(v);
                            }
                          }),
                          style: ts(context, 15, weight: FontWeight.w500),
                          decoration: deco(tl('장소')),
                        ),
                      ),
                      divider(),
                      iconRow(
                        Icons.notes_rounded,
                        TextField(
                          controller: _note,
                          cursorColor: p.ink,
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          onChanged: (_) => setState(() {}),
                          style: ts(context, 15, weight: FontWeight.w500, height: 21 / 15),
                          decoration: deco(tl('메모')),
                        ),
                        top: true,
                      ),
                      if (!_allDay) ...[
                        divider(),
                        Tap(
                          onTap: _pickTravel,
                          label: tl('이동시간 정하기'),
                          child: iconRow(
                            Icons.directions_car_outlined,
                            Row(
                              children: [
                                Expanded(
                                  child: Text(tl('이동시간'), style: ts(context, 15, weight: FontWeight.w600)),
                                ),
                                Flexible(
                                  child: Text(
                                    _travel.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ts(context, 14, color: p.muted),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ]),
                    card([
                      iconRow(
                        Icons.tag_rounded,
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in _tags) TagPill(tag: t, on: true, height: 32, onTap: _editTags),
                            Tap(
                              onTap: _editTags,
                              label: tl('태그 바꾸기'),
                              child: DashedBox(
                                radius: 16,
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _tags.isEmpty ? tl('+ 태그 추가') : tl('편집'),
                                        style: ts(context, 13, weight: FontWeight.w600, color: p.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        top: true,
                      ),
                      divider(),
                      iconRow(
                        Icons.palette_outlined,
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            swatch(null),
                            for (final c in Skin.palette) swatch(c),
                          ],
                        ),
                        top: true,
                      ),
                      divider(),
                      Tap(
                        onTap: _pickProject,
                        label: tl('프로젝트 고르기'),
                        child: iconRow(
                          Icons.flag_outlined,
                          Row(
                            children: [
                              Expanded(
                                child: Text(tl('프로젝트'), style: ts(context, 15, weight: FontWeight.w600)),
                              ),
                              Text(
                                StoreScope.of(context).projectById(_projectId ?? '')?.name ?? tl('없음'),
                                style: ts(context, 14, color: p.muted),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjPick {
  const _ProjPick(this.id);
  final String? id;
}
