import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../parser.dart';
import '../projects.dart';
import '../skins.dart';
import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';
import 'project_pages.dart';
import 'sheets.dart';
import 'tag_dialog.dart';

/// 입력한 글에서 읽힌 날짜·시간·길이에 배경색을 입혀 보여주는 입력 컨트롤러
class ParsedController extends TextEditingController {
  ParsedController({super.text});

  QuickParse Function(String text)? parser;
  Color highlight = const Color(0xFFECEAE3);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    final parse = parser;
    final hits = (parse == null || t.isEmpty) ? const <Hit>[] : parse(t).hits;
    final comp = (withComposing && value.isComposingRangeValid) ? value.composing : TextRange.empty;
    if (hits.isEmpty && comp.isCollapsed) {
      return TextSpan(style: style, text: t);
    }

    final cuts = <int>{0, t.length};
    for (final h in hits) {
      cuts.add(h.start);
      cuts.add(h.end);
    }
    if (!comp.isCollapsed) {
      cuts.add(comp.start);
      cuts.add(comp.end);
    }
    final pts = cuts.where((i) => i >= 0 && i <= t.length).toList()..sort();

    final base = style ?? const TextStyle();
    final spans = <InlineSpan>[];
    for (var i = 0; i + 1 < pts.length; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (a == b) continue;
      var st = base;
      for (final h in hits) {
        if (h.start <= a && b <= h.end) {
          st = st.merge(TextStyle(backgroundColor: highlight));
          break;
        }
      }
      if (!comp.isCollapsed && comp.start <= a && b <= comp.end) {
        st = st.merge(const TextStyle(decoration: TextDecoration.underline));
      }
      spans.add(TextSpan(text: t.substring(a, b), style: st));
    }
    return TextSpan(style: style, children: spans);
  }
}

class _ColorPick {
  const _ColorPick(this.color);
  final Color? color;
}

class _TimeResult {
  const _TimeResult(this.allDay, this.startMin, this.minutes);
  final bool allDay;
  final int startMin;
  final int minutes;
}

List<Ev> _conflicts(CalendarStore store, QuickParse q) {
  if (q.allDay) return const <Ev>[];
  final day = dayOnly(q.start);
  return store
      .eventsOn(day)
      .where((e) => !e.allDay && e.start.isBefore(q.end) && e.end.isAfter(q.start))
      .toList();
}

/// "새 일정" 화면: 한 줄로 쓰면 날짜·시간·길이를 읽어서 보여줘요.
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key, this.initialText = '', this.project});

  final String initialText;

  /// 이 프로젝트 안에 일정을 추가할 때
  final Project? project;

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  /// 이 일정에만 따로 고른 색 (없으면 캘린더 색)
  Color? _color;

  /// 이 프로젝트 안에 추가하는 중 (✕ 로 뺄 수 있어요)
  late Project? _into = widget.project;

  /// 체크포인트로도 표시할지 (프로젝트 안에 추가할 때)
  bool _asCheckpoint = false;

  /// 이 일정으로 새 프로젝트를 만들지, 그때 고른 것들
  bool _projectOn = false;
  ProjectDraft? _draft;

  final ParsedController _ctl = ParsedController();
  final FocusNode _focus = FocusNode();
  String? _calId;
  String _location = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctl.text = widget.initialText;
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  QuickParse _parse(CalendarStore s) =>
      parseQuick(_ctl.text, now: s.now, defaultDay: s.selected);

  List<CalInfo> _writable(CalendarStore s) =>
      s.calendars.where((c) => !c.readOnly && !isHolidayName(c.name)).toList();

  CalInfo? _calendar(CalendarStore s) {
    final list = _writable(s);
    if (list.isEmpty) return null;
    for (final c in list) {
      if (c.id == _calId) return c;
    }
    for (final c in list) {
      if (c.isPrimary) return c;
    }
    return list.first;
  }

  // ---------------------------------------------------------------- 글 고치기

  void _rewrite(Set<HitKind> kinds, String insert) {
    final store = StoreScope.of(context);
    final q = _parse(store);
    final t = rewriteHits(_ctl.text, q.hits, kinds, insert);
    _ctl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
    setState(() {});
  }

  void _setDate(DateTime d) {
    final t = StoreScope.of(context).today;
    final text = (d.year == t.year && !d.isBefore(t))
        ? '${d.month}월 ${d.day}일'
        : '${d.year}년 ${d.month}월 ${d.day}일';
    _rewrite({HitKind.date}, text);
  }

  /// "9월 18일~10월 28일" 처럼 기간 글을 만들어요. 다시 읽어도 같은 날짜가 나오는 짧은 글을 쓰고,
  /// 아니면 연도까지 써요.
  String _rangeText(DateTime a, DateTime b) {
    final store = StoreScope.of(context);
    final short = '${a.month}월 ${a.day}일~${b.month}월 ${b.day}일';
    final r = parseQuick(short, now: store.now, defaultDay: store.selected);
    final last = r.lastDay;
    if (last != null && sameDay(r.start, a) && sameDay(last, b)) return short;
    return '${a.year}년 ${a.month}월 ${a.day}일~${b.year}년 ${b.month}월 ${b.day}일';
  }

  void _setRange(DateTime a, DateTime b) {
    if (!b.isAfter(a)) {
      _setDate(a);
      return;
    }
    _rewrite({HitKind.date}, _rangeText(a, b));
  }

  void _removeRange(int a, int b) {
    final t = _ctl.text;
    final nt = (t.substring(0, a) + t.substring(b)).replaceAll(RegExp(r' {2,}'), ' ').trim();
    _ctl.value = TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: nt.length),
    );
    setState(() {});
  }

  void _addTags(List<String> add) {
    if (add.isEmpty) return;
    final q = _parse(StoreScope.of(context));
    var t = _ctl.text.trimRight();
    for (final tag in add) {
      if (q.tags.contains(tag)) continue;
      t = t.isEmpty ? '#$tag' : '$t #$tag';
    }
    _ctl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
    setState(() {});
  }

  void _setTime(int startMin, int minutes) {
    final ins = '${timeWords(startMin ~/ 60, startMin % 60)}, ${durText(Duration(minutes: minutes))}';
    final store = StoreScope.of(context);
    final q = _parse(store);
    final targets = q.hits
        .where((h) => h.kind == HitKind.time || h.kind == HitKind.duration)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (targets.isEmpty) {
      _rewrite({HitKind.time, HitKind.duration}, ins);
      return;
    }
    // 시각·길이 글자와 그 사이의 쉼표를 걷어내고 새 글자를 한 번만 넣어요. (끌 때마다 쉼표가 쌓이지 않게)
    final t = _ctl.text;
    final left = t.substring(0, targets.first.start).trimRight();
    final mid = StringBuffer();
    for (var i = 1; i < targets.length; i++) {
      final seg = t.substring(targets[i - 1].end, targets[i].start);
      if (seg.replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) mid.write(seg);
    }
    final rest = (mid.toString() + t.substring(targets.last.end))
        .replaceFirst(RegExp(r'^[\s,]+'), '')
        .trim();
    final nt = [left, ins, rest].where((x) => x.isNotEmpty).join(' ');
    _ctl.value = TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: nt.length),
    );
    setState(() {});
  }

  Future<void> _pickDate(QuickParse q) async {
    final d = await showDateSheet(context, initial: dayOnly(q.start), title: '날짜');
    if (d == null || !mounted) return;
    final last = q.lastDay;
    if (last != null) {
      _setRange(d, last.isBefore(d) ? d : last);
    } else {
      _setDate(d);
    }
  }

  /// 끝나는 날을 골라서 기간 일정으로 만들어요. 시작과 같은 날을 고르면 하루짜리로 돌아가요.
  Future<void> _pickEnd(QuickParse q) async {
    final first = dayOnly(q.start);
    final d = await showDateSheet(
      context,
      initial: q.lastDay ?? first,
      first: first,
      title: '끝나는 날',
    );
    if (d != null && mounted) _setRange(first, d);
  }

  Future<void> _askTag() async {
    final store = StoreScope.of(context);
    final r = await showTagDialog(context, known: store.knownTags().take(12).toList());
    if (r == null || !mounted) return;
    _addTags(r);
  }

  Future<void> _pickTime(QuickParse q) async {
    final r = await showAppSheet<_TimeResult>(
      context: context,
      builder: (_) => _TimeSheet(
        allDay: q.allDay,
        startMin: q.allDay ? 9 * 60 : q.start.hour * 60 + q.start.minute,
        minutes: q.allDay ? 60 : math.max(15, q.end.difference(q.start).inMinutes),
      ),
    );
    if (r == null || !mounted) return;
    if (r.allDay) {
      _rewrite({HitKind.time, HitKind.duration}, '종일');
    } else {
      _setTime(r.startMin, r.minutes);
    }
  }

  Future<void> _pickColor(Color? calColor) async {
    final r = await showAppSheet<_ColorPick>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        Widget swatch(Color? c) {
          final on = _color == c ||
              (c != null && _color != null && _color!.toARGB32() == c.toARGB32());
          final fill = c ?? calColor ?? p.soft;
          return Tap(
            onTap: () => Navigator.of(ctx).pop(_ColorPick(c)),
            label: c == null ? '캘린더 색' : '색 고르기',
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: on ? p.ink : p.line, width: on ? 2.5 : 1),
              ),
              child: c == null
                  ? Icon(Icons.block_rounded, size: 18, color: p.ink.withValues(alpha: 0.55))
                  : (on ? Icon(Icons.check_rounded, size: 20, color: p.ink) : null),
            ),
          );
        }

        return SheetFrame(
          title: '일정 색',
          subtitle: '이 일정만 다른 색으로 보여요. 첫 번째 칸은 캘린더 색이에요.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [swatch(null), for (final c in Skin.palette) swatch(c)],
          ),
        );
      },
    );
    if (r == null || !mounted) return;
    setState(() => _color = r.color);
  }

  Future<void> _pickRepeat(QuickParse q) async {
    final cur = q.repeat;
    final r = await showAppSheet<String>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        Widget row(String key, String label, String? sub, bool on) => Tap(
              onTap: () => Navigator.of(ctx).pop(key),
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: ts(ctx, 16, weight: FontWeight.w600)),
                          if (sub != null)
                            Text(sub, style: ts(ctx, 12, color: p.muted, height: 16 / 12)),
                        ],
                      ),
                    ),
                    if (on) Icon(Icons.check_rounded, size: 22, color: p.ink),
                  ],
                ),
              ),
            );
        return SheetFrame(
          title: '반복',
          subtitle: '끝나는 날을 적으면 그날까지만 반복해요 (예: 10/26~11/13)',
          child: Column(
            children: [
              row('none', '반복 안 함', null, cur == null),
              row('daily', '매일', '예) 매일 9시~6시', cur == RepeatKind.daily),
              row('weekdays', '평일마다', '월~금', cur == RepeatKind.weekdays),
              row('weekly', '매주', '시작하는 날의 요일마다', cur == RepeatKind.weekly),
            ],
          ),
        );
      },
    );
    if (r == null || !mounted) return;
    final hit = q.hits.where((h) => h.kind == HitKind.repeat).toList();
    if (r == 'none') {
      if (hit.isNotEmpty) _removeRange(hit.first.start, hit.first.end);
      // 기간 + 시각은 자동으로 "매일" 이라서, 반복을 끄려면 종일(기간)로 바꿔요.
      return;
    }
    final word = r == 'daily' ? '매일' : (r == 'weekdays' ? '평일마다' : '매주');
    _rewrite({HitKind.repeat}, word);
  }

  Future<void> _pickCalendar(List<CalInfo> list, CalInfo? current) async {
    final id = await showCalendarSheet(context, list: list, currentId: current?.id);
    if (id != null && mounted) setState(() => _calId = id);
  }

  Future<void> _askLocation() async {
    final r = await showTextSheet(
      context,
      title: '장소',
      subtitle: '어디서 만나나요?',
      hint: '예) 강남역 2번 출구',
      initial: _location,
      icon: Icons.place_outlined,
    );
    if (r != null && mounted) setState(() => _location = r);
  }

  void _applySlot(Slot s) {
    _setDate(s.start);
    _setTime(s.start.hour * 60 + s.start.minute, s.end.difference(s.start).inMinutes);
  }

  // ---------------------------------------------------------------- 저장

  Future<void> _toggleProject(QuickParse q) async {
    if (_projectOn) {
      setState(() => _projectOn = false);
      return;
    }
    final last = q.lastDay;
    if (last == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기간("10/26~11/13")이나 "매일 …까지"처럼 끝나는 날이 있는 일정만 프로젝트로 볼 수 있어요')),
      );
      return;
    }
    final r = await showProjectOptionsSheet(
      context,
      name: q.title.isEmpty ? '새 일정' : q.title,
      start: dayOnly(q.start),
      end: last,
      initial: _draft,
    );
    if (r == null || !mounted) return;
    setState(() {
      _draft = r;
      _projectOn = true;
    });
  }

  /// 쉬는 요일에 맞춰 반복 방식을 바꿔요 (매일 / 평일마다 / 고른 요일마다)
  Repeat? _repeatFor(Repeat? r, Set<int> rest) {
    if (r == null || (r.kind != RepeatKind.daily && r.kind != RepeatKind.weekdays)) return r;
    if (rest.isEmpty) return Repeat(RepeatKind.daily, until: r.until);
    if (rest.length == 2 && rest.contains(6) && rest.contains(7)) {
      return Repeat(RepeatKind.weekdays, until: r.until);
    }
    return Repeat(
      RepeatKind.days,
      until: r.until,
      days: {for (var i = 1; i <= 7; i++) if (!rest.contains(i)) i},
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final store = StoreScope.of(context);
    if (_ctl.text.trim().isEmpty) return;
    final q = _parse(store);
    final cal = _calendar(store);
    final into = _into;
    final makeProject = _projectOn && _draft != null && q.lastDay != null && into == null;
    final rest = makeProject ? _draft!.rest : const <int>{};

    // 프로젝트 기간 밖이거나 쉬는 요일이면 한 번 물어봐요.
    if (into != null) {
      final day = dayOnly(q.start);
      String? why;
      if (!into.contains(day)) {
        why = '프로젝트 기간(${into.start.month}/${into.start.day} – ${into.end.month}/${into.end.day}) 밖이에요';
      } else if (into.isRestDay(day)) {
        why = '${wdFull(day)}은 쉬는 요일이에요';
      }
      if (why != null) {
        final yes = await showConfirmSheet(
          context,
          title: why,
          body: '그래도 이 프로젝트에 추가할까요?',
          yes: '그래도 추가',
          no: '다시 정할게요',
        );
        if (!yes || !mounted) return;
      }
    }

    var start = q.start;
    var end = q.end;
    var repeat = q.repeatRule;
    if (makeProject && repeat != null) {
      repeat = _repeatFor(repeat, rest);
      // 첫날이 쉬는 요일이면 다음 근무일부터 시작해요.
      var shift = 0;
      while (rest.contains(addDays(start, shift).weekday) && shift < 7) {
        shift++;
      }
      if (shift > 0) {
        final ns = DateTime(start.year, start.month, start.day + shift, start.hour, start.minute);
        end = ns.add(end.difference(start));
        start = ns;
      }
    }

    setState(() => _saving = true);
    final ok = await store.addEvent(
      calendarId: cal?.id,
      title: q.title.isEmpty ? '새 일정' : q.title,
      start: start,
      end: end,
      allDay: q.allDay,
      location: _location.isEmpty ? null : _location,
      tags: q.tags,
      repeat: repeat,
      color: _color,
    );
    if (!mounted) return;
    if (ok) {
      final id = store.lastCreatedId;
      if (id != null && into != null) {
        await store.addEventIdsToProject(into.id, {id});
        if (_asCheckpoint) {
          final fresh = store.projectById(into.id);
          if (fresh != null) {
            final cps = [
              ...fresh.checkpoints,
              Checkpoint(
                id: 'c${DateTime.now().microsecondsSinceEpoch}',
                title: q.title.isEmpty ? '새 일정' : q.title,
                date: dayOnly(q.start),
              ),
            ]..sort((a, b) => a.date.compareTo(b.date));
            await store.saveProject(fresh.copyWith(checkpoints: cps));
          }
        }
      } else if (id != null && makeProject) {
        final String prefix;
        if (q.allDay) {
          prefix = '';
        } else if (rest.isEmpty) {
          prefix = '매일 ';
        } else if (rest.length == 2 && rest.contains(6) && rest.contains(7)) {
          prefix = '평일 ';
        } else {
          prefix = '';
        }
        final firstDay = dayOnly(start);
        await store.saveProject(
          Project(
            id: store.newProjectId(),
            name: q.title.isEmpty ? '새 프로젝트' : q.title,
            start: firstDay,
            end: q.lastDay!,
            colorValue: (_color ?? cal?.color ?? Skin.palette.first).toARGB32(),
            rest: rest,
            checkpoints: _draft!.checkpoints,
            eventIds: {id},
            timeText: q.allDay ? '종일' : '$prefix${hm(start)} – ${hm(end)}',
            cells: !q.allDay,
          ),
        );
      }
      if (!mounted) return;
      // 기간 일정이 오늘을 지나고 있으면 오늘로, 아니면 시작일로 가요.
      final last = q.lastDay;
      final t = store.today;
      final inside = last != null && !t.isBefore(q.start) && !t.isAfter(last);
      store.select(inside ? t : q.start);
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.error ?? '일정을 저장하지 못했어요')),
      );
    }
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;

    _ctl.parser = (t) => parseQuick(t, now: store.now, defaultDay: store.selected);
    _ctl.highlight = p.soft;

    final q = _parse(store);
    final hasText = _ctl.text.trim().isNotEmpty;
    final cal = _calendar(store);
    final writable = _writable(store);
    final title = q.title.isEmpty ? '새 일정' : q.title;
    final conflicts = hasText ? _conflicts(store, q) : const <Ev>[];
    final calColors = cal == null ? null : evColors(cal.color, p);
    final last = q.lastDay;
    final tagHits = q.hits.where((h) => h.kind == HitKind.tag).toList();

    String hint;
    if (!hasText) {
      hint = '날짜 · 시간 · 길이를 같이 쓰면 자동으로 읽어요';
    } else {
      final parts = <String>[];
      if (q.hasDate) parts.add(q.isRange ? '기간' : '날짜');
      if (q.hasTime) parts.add('시간');
      if (q.hasDuration) parts.add('길이');
      if (q.allDay) parts.add('종일');
      if (q.repeat != null) parts.add('반복');
      hint = parts.isEmpty ? '' : '${parts.join(' · ')} 자동으로 읽었어요';
    }

    final suggestions = (hasText && !q.allDay)
        ? store
            .suggestAcrossDays(q.end.difference(q.start), dayOnly(q.start))
            .where((s) => s.start != q.start)
            .toList()
        : const <Slot>[];

    return Scaffold(
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
                    width: 76,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Tap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text('취소', style: ts(context, 16)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('새 일정', style: ts(context, 17, weight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Tap(
                        onTap: (hasText && !_saving) ? _save : null,
                        child: Opacity(
                          opacity: (hasText && !_saving) ? 1 : 0.35,
                          child: Pill(
                            height: 36,
                            color: p.ink,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '추가',
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
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _ctl,
                          focusNode: _focus,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          minLines: 1,
                          maxLines: 4,
                          cursorColor: p.ink,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _save(),
                          style: ts(
                            context,
                            26,
                            weight: FontWeight.w600,
                            height: 38 / 26,
                            letterSpacing: -0.78,
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: '내일 오후 3시 치과 30분',
                            hintStyle: ts(
                              context,
                              26,
                              weight: FontWeight.w600,
                              height: 38 / 26,
                              letterSpacing: -0.78,
                              color: p.dash,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hint,
                          style: ts(context, 13, color: p.muted, height: 17 / 13),
                        ),
                      ],
                    ),
                  ),
                  if (_into != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Chip(
                            dot: _into!.color,
                            icon: Icons.close_rounded,
                            text: _into!.name,
                            onTap: () => setState(() {
                              _into = null;
                              _asCheckpoint = false;
                            }),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('체크포인트로 표시', style: ts(context, 14, weight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              AppSwitch(
                                value: _asCheckpoint,
                                label: '체크포인트로 표시',
                                onChanged: (v) => setState(() => _asCheckpoint = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          icon: Icons.calendar_today_rounded,
                          text: last == null
                              ? dateChip(q.start)
                              : '${q.start.month}월 ${q.start.day}일 ~ ${last.month}월 ${last.day}일',
                          onTap: () => _pickDate(q),
                        ),
                        if (q.allDay)
                          _Chip(
                            icon: Icons.date_range_rounded,
                            text: last == null ? '끝나는 날' : '${daysBetween(q.start, q.end)}일 동안',
                            dashed: last == null,
                            onTap: () => _pickEnd(q),
                          ),
                        _Chip(
                          icon: Icons.schedule_rounded,
                          text: q.allDay ? '종일' : rangeText(q.start, q.end),
                          onTap: !q.isRange ? () => _pickTime(q) : null,
                        ),
                        _Chip(
                          icon: Icons.repeat_rounded,
                          text: q.repeatRule?.label ?? '반복',
                          dashed: q.repeat == null,
                          onTap: () => _pickRepeat(q),
                        ),
                        _Chip(
                          dot: _color,
                          icon: _color == null ? Icons.palette_outlined : null,
                          text: _color == null ? '색' : '색 고름',
                          dashed: _color == null,
                          onTap: () => _pickColor(cal?.color),
                        ),
                        if (cal != null && calColors != null)
                          _Chip(
                            dot: cal.color,
                            text: cal.name,
                            fill: calColors.tint,
                            fg: calColors.text,
                            onTap: writable.length > 1 ? () => _pickCalendar(writable, cal) : null,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          icon: Icons.place_outlined,
                          text: _location.isEmpty ? '장소' : _location,
                          dashed: _location.isEmpty,
                          onTap: _askLocation,
                        ),
                        if (_into == null)
                          _Chip(
                            icon: _projectOn ? Icons.close_rounded : Icons.flag_outlined,
                            text: _projectOn ? '프로젝트로 보기' : '프로젝트',
                            dashed: !_projectOn,
                            onTap: () => _toggleProject(q),
                          ),
                        for (final h in tagHits)
                          _Chip(
                            icon: Icons.close_rounded,
                            text: _ctl.text.substring(h.start, h.end),
                            fg: tagColor(_ctl.text.substring(h.start + 1, h.end), dark: p.dark),
                            fill: Color.alphaBlend(
                              tagColor(_ctl.text.substring(h.start + 1, h.end), dark: p.dark)
                                  .withAlpha(34),
                              p.surface,
                            ),
                            onTap: () => _removeRange(h.start, h.end),
                          ),
                        _Chip(
                          icon: Icons.tag_rounded,
                          text: '태그',
                          dashed: true,
                          onTap: _askTag,
                        ),
                      ],
                    ),
                  ),
                  if (hasText)
                    _Preview(q: q, title: title, conflicts: conflicts, onTime: _setTime),
                  if (suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conflicts.isNotEmpty ? '이 시간이 어렵다면' : '비어 있는 다른 시간',
                            style: ts(context, 13, weight: FontWeight.w600, color: p.muted, height: 17 / 13),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in suggestions)
                                Tap(
                                  onTap: () => _applySlot(s),
                                  child: Pill(
                                    height: 36,
                                    ring: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      _slotLabel(store, s),
                                      style: ts(context, 14, weight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _slotLabel(CalendarStore store, Slot s) {
    final far = daysBetween(store.today, s.start) >= 7;
    final head = far ? '${s.start.month}/${s.start.day} ' : '';
    return '$head${wd(s.start)} ${hm(s.start)}';
  }
}

/// 날짜·시간·캘린더·장소 칩
class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.onTap,
    this.icon,
    this.dot,
    this.fill,
    this.fg,
    this.dashed = false,
  });

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? dot;
  final Color? fill;
  final Color? fg;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final color = fg ?? (dashed ? p.muted : p.ink);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 16, color: color),
        if (dot != null) Dot(dot!, size: 8),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(context, 14, weight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
    final Widget body = dashed
        ? DashedBox(
            radius: 18,
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: row,
            ),
          )
        : Container(
            height: 36,
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: fill ?? p.surface,
              borderRadius: BorderRadius.circular(18),
              border: fill == null ? Border.all(color: p.line) : null,
            ),
            child: row,
          );
    return Tap(onTap: onTap, child: body);
  }
}

/// 그날의 모습과 겹치는 일정 확인
class _Preview extends StatefulWidget {
  const _Preview({
    required this.q,
    required this.title,
    required this.conflicts,
    required this.onTime,
  });

  final QuickParse q;
  final String title;
  final List<Ev> conflicts;

  /// 시간 바를 손으로 끌면 (시작 분, 길이 분) 으로 알려줘요.
  final void Function(int startMin, int minutes) onTime;

  @override
  State<_Preview> createState() => _PreviewState();
}

enum _Grab { move, start, end }

class _PreviewState extends State<_Preview> {
  QuickParse get q => widget.q;
  String get title => widget.title;
  List<Ev> get conflicts => widget.conflicts;

  static const int _rs = 9 * 60;
  static const int _re = 22 * 60;
  static const int _snap = 15;

  // 끌기 상태
  _Grab _grab = _Grab.move;
  double _x0 = 0;
  int _s0 = 0;
  int _e0 = 0;
  double _w = 1;

  int _minAt(double x) => _rs + (x / _w * (_re - _rs)).round();
  int _snapped(int m) => (m / _snap).round() * _snap;

  void _dragStart(double x, int sMin, int eMin) {
    _s0 = sMin;
    _e0 = eMin;
    _x0 = x;
    final l = (math.max(_rs, math.min(_re, sMin)) - _rs) / (_re - _rs) * _w;
    final r = (math.max(_rs, math.min(_re, eMin)) - _rs) / (_re - _rs) * _w;
    const edge = 24.0;
    if ((x - l).abs() <= edge && (x - l).abs() <= (x - r).abs()) {
      _grab = _Grab.start;
    } else if ((x - r).abs() <= edge) {
      _grab = _Grab.end;
    } else if (x > l && x < r) {
      _grab = _Grab.move;
    } else {
      // 바깥을 누르면 그 자리로 옮겨요 (길이는 그대로)
      _grab = _Grab.move;
      final len = eMin - sMin;
      _s0 = _snapped(_minAt(x) - len ~/ 2);
      _e0 = _s0 + len;
      _x0 = x;
      _apply(x);
    }
  }

  void _apply(double x) {
    final d = ((x - _x0) / _w * (_re - _rs)).round();
    var s = _s0;
    var e = _e0;
    switch (_grab) {
      case _Grab.move:
        final len = _e0 - _s0;
        s = _snapped(_s0 + d).clamp(_rs, math.max(_rs, _re - len)).toInt();
        e = s + len;
      case _Grab.start:
        s = _snapped(_s0 + d).clamp(_rs, math.max(_rs, _e0 - _snap)).toInt();
      case _Grab.end:
        e = _snapped(_e0 + d).clamp(_s0 + _snap, math.max(_s0 + _snap, _re)).toInt();
    }
    if (s != q.start.hour * 60 + q.start.minute || e - s != q.end.difference(q.start).inMinutes) {
      widget.onTime(s, e - s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final day = dayOnly(q.start);
    final others = store.eventsOn(day).where((e) => !e.allDay).toList();
    final bad = conflicts.isNotEmpty;
    final last = q.lastDay;

    Widget status;
    if (q.allDay) {
      final String msg;
      if (last != null) {
        msg = '${daysBetween(q.start, q.end)}일 동안';
      } else {
        msg = others.isEmpty ? '이 날은 일정이 없어요' : '이 날 일정 ${others.length}개';
      }
      status = Text(
        msg,
        style: ts(context, 13, weight: FontWeight.w600, color: p.muted),
      );
    } else {
      final c = bad ? p.red : p.good;
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bad ? Icons.error_outline_rounded : Icons.check_rounded, size: 16, color: c),
          const SizedBox(width: 4),
          Text(
            bad ? '겹치는 일정 ${conflicts.length}개' : '겹치는 일정 없음',
            style: ts(context, 13, weight: FontWeight.w600, color: c),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                last == null
                    ? '${wdFull(day)} ${day.day}일'
                    : '${q.start.month}월 ${q.start.day}일 – ${last.month}월 ${last.day}일',
                style: ts(context, 15, weight: FontWeight.w700),
              ),
              status,
            ],
          ),
          if (!q.allDay) ...[
            const SizedBox(height: 40),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                double fx(int min) {
                  final v = math.max(_rs, math.min(_re, min));
                  return (v - _rs) / (_re - _rs) * w;
                }

                final kids = <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ];
                for (final h in const [12, 15, 18, 21]) {
                  kids.add(Positioned(
                    left: fx(h * 60),
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: p.line),
                  ));
                }
                for (final e in others) {
                  final l = fx(minOfDay(e.start, day));
                  final r = fx(minOfDay(e.end, day));
                  if (r - l < 2) continue;
                  kids.add(Positioned(
                    left: l,
                    top: 5,
                    width: r - l,
                    height: 26,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: e.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ));
                }
                final sMin = minOfDay(q.start, day);
                final eMin = minOfDay(q.end, day);
                final l = fx(sMin);
                final bw = math.max(12.0, fx(eMin) - l);
                kids.add(Positioned(
                  left: math.min(l, w - bw),
                  top: -3,
                  width: bw,
                  height: 42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: p.ink, width: 2),
                    ),
                  ),
                ));
                final cx = math.max(48.0, math.min(w - 48, l + bw / 2));
                kids.add(Positioned(
                  left: cx,
                  top: -34,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Container(
                      height: 24,
                      constraints: const BoxConstraints(maxWidth: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '$title ${hm(q.start)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(context, 12, weight: FontWeight.w600, color: p.bg),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
                _w = w;
                // 손잡이: 양 끝을 끌면 시작·끝이, 가운데를 끌면 통째로 움직여요.
                for (final hx in [math.min(l, w - bw) + 6, math.min(l, w - bw) + bw - 9]) {
                  kids.add(Positioned(
                    left: hx,
                    top: 8,
                    width: 3,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.dash,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ));
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) {
                    final s0 = q.start.hour * 60 + q.start.minute;
                    _dragStart(d.localPosition.dx, s0, s0 + q.end.difference(q.start).inMinutes);
                  },
                  onHorizontalDragUpdate: (d) => _apply(d.localPosition.dx),
                  onTapDown: (d) {
                    final x = d.localPosition.dx;
                    final s0 = q.start.hour * 60 + q.start.minute;
                    final e0 = s0 + q.end.difference(q.start).inMinutes;
                    _dragStart(x, s0, e0);
                  },
                  child: SizedBox(
                    height: 36,
                    child: Stack(clipBehavior: Clip.none, children: kids),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final st = ts(context, 11, color: p.muted, height: 14 / 11);
                Widget at(int hour) => Positioned(
                      left: w * (hour * 60 - _rs) / (_re - _rs),
                      top: 0,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Text('$hour시', style: st),
                      ),
                    );
                return SizedBox(
                  height: 14,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [at(9), at(12), at(15), at(18), at(21)],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 시간 고르기 시트: 종일 / 시작·끝 시각 / 빠른 길이
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.allDay, required this.startMin, required this.minutes});

  final bool allDay;
  final int startMin;
  final int minutes;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  static const List<int> _durs = [15, 30, 45, 60, 90, 120, 180];

  late bool _allDay = widget.allDay;
  late int _startMin = widget.startMin;
  late int _minutes = widget.minutes;

  bool _badEnd = false;

  Future<void> _pickStart() async {
    final base = DateTime(2000, 1, 1, (_startMin ~/ 60) % 24, _startMin % 60);
    final t = await showTimeSheet(context, initial: base, title: '시작 시각');
    // 시작을 옮기면 길이는 그대로 두고 끝도 같이 움직여요.
    if (t != null && mounted) {
      setState(() {
        _startMin = t.hour * 60 + t.minute;
        _badEnd = false;
      });
    }
  }

  Future<void> _pickEnd() async {
    final e = _startMin + _minutes;
    final base = DateTime(2000, 1, 1, (e ~/ 60) % 24, e % 60);
    final t = await showTimeSheet(context, initial: base, title: '끝나는 시각');
    if (t == null || !mounted) return;
    final total = t.hour * 60 + t.minute;
    setState(() {
      if (total <= _startMin) {
        _badEnd = true; // 같은 날 안에서 시작보다 뒤여야 해요
      } else {
        _badEnd = false;
        _minutes = total - _startMin;
      }
    });
  }

  Widget _timePill(String label, String text, VoidCallback onTap) {
    final p = Pal.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
          const SizedBox(height: 8),
          Tap(
            onTap: onTap,
            child: Pill(
              height: 44,
              ring: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(text, style: ts(context, 16, weight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final endMin = _startMin + _minutes;
    return SheetFrame(
      title: '시간',
      footer: BigButton(
        label: '적용',
        onTap: () => Navigator.of(context).pop(_TimeResult(_allDay, _startMin, _minutes)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('종일', style: ts(context, 16, weight: FontWeight.w600))),
              AppSwitch(value: _allDay, onChanged: (v) => setState(() => _allDay = v), label: '종일'),
            ],
          ),
          if (!_allDay) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timePill(
                  '시작',
                  timeWords((_startMin ~/ 60) % 24, _startMin % 60),
                  _pickStart,
                ),
                const SizedBox(width: 12),
                _timePill(
                  '끝',
                  '${endMin >= 1440 ? '다음날 ' : ''}${timeWords((endMin ~/ 60) % 24, endMin % 60)}',
                  _pickEnd,
                ),
              ],
            ),
            if (_badEnd) ...[
              const SizedBox(height: 8),
              Text(
                '끝나는 시각은 시작보다 뒤여야 해요',
                style: ts(context, 13, color: p.red, height: 17 / 13),
              ),
            ],
            const SizedBox(height: 18),
            Text('빠른 길이', style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _durs)
                  Tap(
                    onTap: () => setState(() => _minutes = m),
                    child: Pill(
                      height: 36,
                      ring: _minutes != m,
                      color: _minutes == m ? p.ink : p.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        durText(Duration(minutes: m)),
                        style: ts(
                          context,
                          14,
                          weight: FontWeight.w600,
                          color: _minutes == m ? p.bg : p.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
