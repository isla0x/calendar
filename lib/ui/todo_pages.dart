import 'package:flutter/material.dart';

import '../dates.dart';
import '../store.dart';
import '../theme.dart';
import '../todos.dart';
import 'common.dart';
import 'sheets.dart';

// ---------------------------------------------------------------- 도우미

Color _tint(Color c, Pal p, [int alpha = 40]) => Color.alphaBlend(c.withAlpha(alpha), p.surface);

String _dueText(Todo t, DateTime today) {
  final d = t.due;
  if (d == null) return '언젠가';
  final n = daysBetween(today, d);
  if (n == 0) return '오늘까지';
  if (n == 1) return '내일까지';
  if (n < 0) return '${d.month}/${d.day} 마감 지남';
  if (n < 7) return '${wdFull(d)}까지';
  return '${d.month}월 ${d.day}일까지';
}

String _dayWord(DateTime d, DateTime today) {
  final n = daysBetween(today, d);
  if (n == 0) return '오늘';
  if (n == 1) return '내일';
  return wd(d);
}

String _repeatText(int perWeek) => perWeek >= 7 ? '매일' : '주 $perWeek번';

class _Header extends StatelessWidget {
  const _Header({required this.small, required this.big});

  final String small;
  final String big;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Tap(
            onTap: () => Navigator.of(context).pop(),
            label: '뒤로',
            child: SizedBox(
              width: 44,
              height: 56,
              child: Icon(Icons.chevron_left_rounded, size: 28, color: p.ink),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(small, style: ts(context, 13, color: p.muted, height: 16 / 13)),
                Text(big, style: ts(context, 30, weight: FontWeight.w700, height: 38 / 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}

class _OptChip extends StatelessWidget {
  const _OptChip(this.text, this.on, this.onTap);

  final String text;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? p.ink : p.surface,
          borderRadius: BorderRadius.circular(19),
          border: on ? null : Border.all(color: p.line),
        ),
        child: Text(
          text,
          style: ts(context, 14, weight: FontWeight.w600, color: on ? p.bg : p.ink),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 목록

enum _TodoTab { all, today, week, someday }

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  _TodoTab _tab = _TodoTab.all;

  bool _inTab(Todo t, DateTime today, DateTime now) {
    switch (_tab) {
      case _TodoTab.all:
        return true;
      case _TodoTab.today:
        if (t.due != null && !t.due!.isAfter(today)) return true;
        return t.slots.any((s) => sameDay(s.start, today));
      case _TodoTab.week:
        final end = weekDeadline(today);
        final sun = addDays(today, 7 - today.weekday);
        final lim = end.isAfter(sun) ? end : sun;
        return t.due != null && !t.due!.isAfter(lim);
      case _TodoTab.someday:
        return t.due == null;
    }
  }

  int _need(Todo t) {
    if (t.perWeek > 0) return t.minutes * (t.perWeek >= 7 ? 5 : t.perWeek);
    return t.need > 0 ? t.need : t.minutes;
  }

  String _slotLabel(Todo t, DateTime now, DateTime today) {
    if (t.done) return '끝냈어요';
    final f = t.futureSlots(now);
    if (f.isEmpty) return t.due == null ? '여유 날에' : '자리 찾기 전';
    final s = f.first.start;
    final txt = '${_dayWord(s, today)} ${hm(s)}';
    return f.length > 1 ? '$txt 외 ${f.length - 1}' : txt;
  }

  Future<void> _more(Todo t) async {
    final store = StoreScope.read(context);
    final r = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: t.title,
        subtitle: '캘린더에 이미 넣은 일정은 그대로 남아요.',
        child: Column(
          children: [
            BigButton(
              label: t.done ? '다시 할 일로' : '끝냈어요',
              quiet: true,
              onTap: () => Navigator.of(ctx).pop('done'),
            ),
            const SizedBox(height: 10),
            BigButton(
              label: '할 일 지우기',
              color: Pal.of(ctx).red,
              quiet: true,
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (r == 'done') await store.setTodoDone(t.id, !t.done);
    if (r == 'delete') await store.deleteTodo(t.id);
  }

  Future<void> _find() async {
    final store = StoreScope.read(context);
    final need = store.todos.where((t) => t.needsPlan(store.now)).length;
    if (need == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자리를 찾을 할 일이 없어요. 새 할 일을 추가해 보세요')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TodoPlanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final now = store.now;
    final today = store.today;
    final all = store.todos;
    final open = all.where((t) => !t.done).toList()
      ..sort((a, b) {
        final c = (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100));
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    final done = all.where((t) => t.done).toList()
      ..sort((a, b) => (b.doneAt ?? DateTime(2000)).compareTo(a.doneAt ?? DateTime(2000)));
    final shown = open.where((t) => _inTab(t, today, now)).toList();
    final doneToday = done.where((t) => t.doneAt != null && sameDay(t.doneAt!, today)).length;

    var totalMin = 0;
    var placed = 0;
    for (final t in open) {
      totalMin += _need(t);
      if (t.futureSlots(now).isNotEmpty) placed++;
    }
    var free = 0;
    for (var i = 0; i < 7; i++) {
      final d = addDays(today, i);
      free += store.freeMinutes(d, from: i == 0 ? now : null);
    }
    final ratio = free <= 0 ? 1.0 : (totalMin / free).clamp(0.0, 1.0);
    final over = totalMin > free;
    final q = store.todoQuestion;
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget tab(String t, _TodoTab v) {
      final on = _tab == v;
      return Expanded(
        child: Tap(
          onTap: () => setState(() => _tab = v),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              t,
              style: ts(context, 14, weight: FontWeight.w600, color: on ? p.ink : p.muted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          const _Header(small: '비는 시간에 맞춰서', big: '할 일'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (q != null) ...[
                  _QuestionCard(todo: q.todo, slot: q.slot),
                  const SizedBox(height: 12),
                ],
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              open.isEmpty
                                  ? '할 일이 없어요'
                                  : '할 일 ${open.length}개 · 모두 ${durText(Duration(minutes: totalMin))}',
                              style: ts(context, 15, weight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '이번 주 여유 ${durText(Duration(minutes: free < 0 ? 0 : free))}',
                            style: ts(context, 13, color: p.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.soft,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: open.isEmpty ? 0 : ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: over ? p.red : p.good,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        open.isEmpty
                            ? '아래에서 할 일을 추가하면 비는 시간에 자리를 찾아줘요.'
                            : (over
                                ? '이번 주 여유보다 많아요. 마감 없는 건 다음 주로 미뤄도 좋아요.'
                                : '전부 이번 주 여유 안에 들어가요. $placed개는 이미 자리를 찾았어요.'),
                        style: ts(context, 13, color: p.muted, height: 18 / 13),
                      ),
                      if (doneToday > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '오늘 $doneToday개 끝냈어요',
                          style: ts(context, 13, weight: FontWeight.w600, color: p.good),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      tab('전체', _TodoTab.all),
                      tab('오늘', _TodoTab.today),
                      tab('이번 주', _TodoTab.week),
                      tab('언젠가', _TodoTab.someday),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        open.isEmpty ? '아직 할 일이 없어요' : '이 칸에는 할 일이 없어요',
                        style: ts(context, 14, color: p.muted),
                      ),
                    ),
                  )
                else
                  _Card(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Column(
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          _TodoRow(
                            todo: shown[i],
                            last: i == shown.length - 1,
                            label: _slotLabel(shown[i], now, today),
                            due: _dueText(shown[i], today),
                            onMore: () => _more(shown[i]),
                          ),
                      ],
                    ),
                  ),
                if (_tab == _TodoTab.all && done.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text('끝낸 할 일', style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
                  ),
                  _Card(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Column(
                      children: [
                        for (var i = 0; i < done.length && i < 8; i++)
                          _TodoRow(
                            todo: done[i],
                            last: i == done.length - 1 || i == 7,
                            label: '끝냈어요',
                            due: _dueText(done[i], today),
                            onMore: () => _more(done[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 14),
            child: Row(
              children: [
                Expanded(
                  child: Tap(
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (_) => const TodoAddPage(),
                        ),
                      );
                    },
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: p.line),
                      ),
                      child: Text(
                        '+ 할 일 추가 · 예) 운동 1시간',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 15, color: p.muted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tap(
                  onTap: _find,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(26)),
                    child: Text(
                      '자리 찾기',
                      style: ts(context, 15, weight: FontWeight.w700, color: p.bg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.todo,
    required this.last,
    required this.label,
    required this.due,
    required this.onMore,
  });

  final Todo todo;
  final bool last;
  final String label;
  final String due;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = StoreScope.read(context);
    final t = todo;
    final parts = <String>[
      durText(Duration(minutes: t.minutes)),
      if (t.perWeek > 0) _repeatText(t.perWeek) else if (t.split && t.minutes > 60) '나눠도 돼요',
      due,
    ];
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Tap(
            onTap: () => store.setTodoDone(t.id, !t.done),
            label: t.done ? '다시 할 일로' : '끝냈어요',
            child: SizedBox(
              width: 40,
              height: 52,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: t.done ? p.ink : Colors.transparent,
                    shape: BoxShape.circle,
                    border: t.done ? null : Border.all(color: p.dash, width: 2),
                  ),
                  child: t.done ? Icon(Icons.check_rounded, size: 15, color: p.bg) : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: Tap(
              onTap: onMore,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(
                            context,
                            15,
                            weight: FontWeight.w600,
                            color: t.done ? p.muted : p.ink,
                            height: 20 / 15,
                          ).copyWith(decoration: t.done ? TextDecoration.lineThrough : null),
                        ),
                        Text(
                          '${parts.join(' · ')}${t.tags.isEmpty ? '' : ' · ${t.tags.map((x) => '#$x').join(' ')}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, 13, color: p.muted, height: 18 / 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: ts(
                      context,
                      13,
                      weight: FontWeight.w700,
                      color: t.done || label.contains('찾기 전') ? p.muted : p.ink,
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
}

/// "방금 끝난 시간" — 일정이 끝난 뒤 앱을 열 때만 물어봐요 (알림은 안 보내요)
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.todo, required this.slot});

  final Todo todo;
  final TodoSlot slot;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = StoreScope.read(context);
    Widget btn(String t, VoidCallback f, {bool dark = false}) => Expanded(
          child: Tap(
            onTap: f,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? p.ink : p.surface,
                borderRadius: BorderRadius.circular(22),
                border: dark ? null : Border.all(color: p.line),
              ),
              child: Text(
                t,
                style: ts(context, 14, weight: FontWeight.w700, color: dark ? p.bg : p.ink),
              ),
            ),
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: _tint(p.good, p, 30),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.good.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Dot(p.good),
              const SizedBox(width: 8),
              Text('방금 끝난 시간', style: ts(context, 13, weight: FontWeight.w700, color: p.good)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${todo.title} 다 했어요?', style: ts(context, 18, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${hm(slot.start)} – ${hm(slot.end)}${todo.tags.isEmpty ? '' : ' · ${todo.tags.map((x) => '#$x').join(' ')}'}',
            style: ts(context, 13, color: p.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              btn('다 했어요', () => store.answerTodo(todo.id, slot.eventId, done: true), dark: true),
              const SizedBox(width: 8),
              btn('30분 더', () => store.answerTodo(todo.id, slot.eventId, more: 30)),
              const SizedBox(width: 8),
              btn('내일로', () => store.answerTodo(todo.id, slot.eventId, postpone: true)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"30분 더"와 "내일로"는 자리 찾기를 누르면 새 자리를 찾아줘요.',
            style: ts(context, 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 추가

class TodoAddPage extends StatefulWidget {
  const TodoAddPage({super.key});

  @override
  State<TodoAddPage> createState() => _TodoAddPageState();
}

class _TodoAddPageState extends State<TodoAddPage> {
  final TextEditingController _ctl = TextEditingController();
  int? _minutes;
  DateTime? _due;
  bool _dueSet = false;
  bool _split = true;
  int _chunk = 30;
  DayPart _part = DayPart.any;
  int? _week;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Todo _draft(CalendarStore store, TodoParse r) {
    final week = _week ?? r.perWeek;
    return Todo(
      id: 'draft',
      title: r.title.isEmpty ? '새 할 일' : r.title,
      minutes: _minutes ?? r.minutes ?? 30,
      due: _dueSet ? _due : r.due,
      split: _split && _chunk > 0,
      minChunk: _split ? _chunk : 0,
      part: _part,
      perWeek: week,
      tags: r.tags,
    );
  }

  Future<void> _pickMinutes() async {
    const opts = [10, 20, 30, 45, 60, 90, 120, 180];
    final r = await showAppSheet<int>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: '걸리는 시간',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in opts)
              _OptChip(durText(Duration(minutes: m)), false, () => Navigator.of(ctx).pop(m)),
          ],
        ),
      ),
    );
    if (r != null) setState(() => _minutes = r);
  }

  Future<void> _pickDue(CalendarStore store) async {
    final r = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: '마감',
        child: Column(
          children: [
            BigButton(label: '날짜 고르기', quiet: true, onTap: () => Navigator.of(ctx).pop('pick')),
            const SizedBox(height: 10),
            BigButton(label: '이번 주 안에', quiet: true, onTap: () => Navigator.of(ctx).pop('week')),
            const SizedBox(height: 10),
            BigButton(label: '언젠가 (마감 없음)', quiet: true, onTap: () => Navigator.of(ctx).pop('none')),
          ],
        ),
      ),
    );
    if (r == null || !mounted) return;
    if (r == 'week') {
      setState(() {
        _due = weekDeadline(store.today);
        _dueSet = true;
      });
    } else if (r == 'none') {
      setState(() {
        _due = null;
        _dueSet = true;
      });
    } else {
      final d = await showDateSheet(context, initial: store.today, first: store.today, title: '마감');
      if (d == null || !mounted) return;
      setState(() {
        _due = d;
        _dueSet = true;
      });
    }
  }

  Future<void> _save(CalendarStore store, TodoParse r) async {
    if (_ctl.text.trim().isEmpty) return;
    final d = _draft(store, r);
    await store.saveTodo(
      Todo(
        id: store.newTodoId(),
        title: d.title,
        minutes: d.minutes,
        due: d.due,
        split: d.split,
        minChunk: d.minChunk,
        part: d.part,
        perWeek: d.perWeek,
        tags: d.tags,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final today = store.today;
    final text = _ctl.text;
    final r = parseTodo(text, now: store.now);
    final has = text.trim().isNotEmpty;
    final d = _draft(store, r);
    final preview = has ? store.planTodoSlots(only: [d]) : const PlanResult(<Proposal>[], <String, int>{});

    final read = <String>[
      if ((r.minutes != null) && _minutes == null) '길이',
      if (r.due != null && !_dueSet) '마감',
      if (r.perWeek > 0 && _week == null) '반복',
      if (r.tags.isNotEmpty) '태그',
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 4, 20, 0),
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tap(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('취소', style: ts(context, 16)),
                  ),
                  Text('새 할 일', style: ts(context, 16, weight: FontWeight.w600)),
                  Opacity(
                    opacity: has ? 1 : 0.35,
                    child: Tap(
                      onTap: has ? () => _save(store, r) : null,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.ink,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '추가',
                          style: ts(context, 15, weight: FontWeight.w600, color: p.bg),
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
              padding: EdgeInsets.fromLTRB(
                24,
                10,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ctl,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 3,
                    cursorColor: p.ink,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(store, r),
                    style: ts(context, 26, weight: FontWeight.w600, height: 36 / 26, letterSpacing: -0.78),
                    decoration: InputDecoration.collapsed(
                      hintText: '소설 쓰기 2시간 이번 주 안에',
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
                  const SizedBox(height: 6),
                  Text(
                    read.isEmpty ? '길이 · 마감 · 태그를 같이 쓰면 자동으로 읽어요' : '${read.join(' · ')} 자동으로 읽었어요',
                    style: ts(context, 13, color: p.muted, height: 17 / 13),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        text: durText(Duration(minutes: d.minutes)),
                        onTap: _pickMinutes,
                      ),
                      _InfoChip(
                        icon: Icons.flag_outlined,
                        text: d.due == null ? '언젠가' : '${d.due!.month}월 ${d.due!.day}일 ${wd(d.due!)}까지',
                        dashed: d.due == null,
                        onTap: () => _pickDue(store),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('나눠서 넣어도 돼요', style: ts(context, 15, weight: FontWeight.w700)),
                                  Text(
                                    '긴 할 일은 짧게 쪼개서 비는 틈에 넣어요',
                                    style: ts(context, 13, color: p.muted, height: 18 / 13),
                                  ),
                                ],
                              ),
                            ),
                            AppSwitch(
                              value: _split,
                              label: '나눠서 넣기',
                              onChanged: (v) => setState(() => _split = v),
                            ),
                          ],
                        ),
                        if (_split) ...[
                          const SizedBox(height: 12),
                          Text('한 번에 최소', style: ts(context, 13, color: p.muted)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _OptChip('30분', _chunk == 30, () => setState(() => _chunk = 30)),
                              _OptChip('1시간', _chunk == 60, () => setState(() => _chunk = 60)),
                              _OptChip('통째로', _chunk == 0, () => setState(() => _chunk = 0)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text('좋아하는 시간대', style: ts(context, 15, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in [DayPart.morning, DayPart.afternoon, DayPart.evening, DayPart.any])
                              _OptChip(v.label, _part == v, () => setState(() => _part = v)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('반복', style: ts(context, 15, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final w in const [0, 7, 2, 3])
                              _OptChip(
                                w == 0 ? '안 해요' : _repeatText(w),
                                d.perWeek == w,
                                () => setState(() => _week = w),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (has)
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이렇게 넣을 수 있어요', style: ts(context, 15, weight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (preview.items.isEmpty)
                            Text(
                              '마감 전에 비는 시간을 못 찾았어요. 마감을 늘리거나 시간을 줄여 보세요.',
                              style: ts(context, 13, color: p.red, height: 18 / 13),
                            ),
                          for (final it in preview.items.take(5))
                            SizedBox(
                              height: 34,
                              child: Row(
                                children: [
                                  Dot(p.good),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_dayWord(it.start, today)} ${it.start.month}/${it.start.day}',
                                      style: ts(context, 14, weight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    '${hm(it.start)} – ${hm(it.end)}',
                                    style: ts(context, 14, color: p.muted),
                                  ),
                                ],
                              ),
                            ),
                          if (preview.unplaced.isNotEmpty && preview.items.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${durText(Duration(minutes: preview.unplaced.values.first))}는 아직 자리가 없어요.',
                                style: ts(context, 13, color: p.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '추가한 뒤 "자리 찾기"를 누르면 캘린더에 일정으로 넣어요. 일정을 옮기면 자리를 다시 찾아요.',
                    style: ts(context, 13, color: p.muted, height: 19 / 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, required this.onTap, this.dashed = false});

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: dashed ? p.muted : p.ink),
            const SizedBox(width: 6),
            Text(
              text,
              style: ts(context, 14, weight: FontWeight.w600, color: dashed ? p.muted : p.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 이렇게 넣어봤어요

class TodoPlanPage extends StatefulWidget {
  const TodoPlanPage({super.key});

  @override
  State<TodoPlanPage> createState() => _TodoPlanPageState();
}

class _TodoPlanPageState extends State<TodoPlanPage> {
  DayPart? _basis;
  final Set<String> _removed = <String>{};
  bool _busy = false;

  String _key(Proposal x) => '${x.todo.id}|${x.start.millisecondsSinceEpoch}';

  Future<void> _apply(CalendarStore store, List<Proposal> items) async {
    if (_busy || items.isEmpty) return;
    setState(() => _busy = true);
    final n = await store.applyProposals(items);
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    m.showSnackBar(SnackBar(content: Text('일정 $n개를 캘린더에 넣었어요')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final today = store.today;
    final res = store.planTodoSlots(override: _basis);
    final items = res.items.where((x) => !_removed.contains(_key(x))).toList();
    final bottom = MediaQuery.of(context).padding.bottom;

    // 날짜별로 묶기
    final days = <int, List<Proposal>>{};
    for (final it in items) {
      days.putIfAbsent(dayKey(it.start), () => <Proposal>[]).add(it);
    }
    final keys = days.keys.toList()..sort();

    Widget basis(String t, DayPart? v) => _OptChip(t, _basis == v, () {
          setState(() {
            _basis = v;
            _removed.clear();
          });
        });

    final names = <String>[
      for (final id in res.unplaced.keys)
        if (store.todoById(id) != null) store.todoById(id)!.title,
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          const _Header(small: '마감이 급한 순서 → 짧은 순서로 맞췄어요', big: '이렇게 넣어봤어요'),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('시간대', style: ts(context, 13, color: p.muted)),
                  const SizedBox(width: 10),
                  basis('각자 정한 대로', null),
                  const SizedBox(width: 8),
                  basis('오전', DayPart.morning),
                  const SizedBox(width: 8),
                  basis('오후', DayPart.afternoon),
                  const SizedBox(width: 8),
                  basis('저녁', DayPart.evening),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '넣을 수 있는 자리를 못 찾았어요.',
                        style: ts(context, 14, color: p.muted),
                      ),
                    ),
                  ),
                for (final k in keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Text(
                      '${_dayWord(days[k]!.first.start, today)} · ${days[k]!.first.start.month}월 ${days[k]!.first.start.day}일 ${wdFull(days[k]!.first.start)}',
                      style: ts(context, 14, weight: FontWeight.w700, color: p.muted),
                    ),
                  ),
                  _Card(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Column(
                      children: [
                        for (var i = 0; i < days[k]!.length; i++)
                          Container(
                            constraints: const BoxConstraints(minHeight: 62),
                            decoration: BoxDecoration(
                              border: i == days[k]!.length - 1
                                  ? null
                                  : Border(bottom: BorderSide(color: p.line)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: p.good,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        days[k]![i].count > 1
                                            ? '${days[k]![i].todo.title} ${days[k]![i].index}/${days[k]![i].count}'
                                            : days[k]![i].todo.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ts(context, 15, weight: FontWeight.w600, height: 20 / 15),
                                      ),
                                      Text(
                                        '${hm(days[k]![i].start)} – ${hm(days[k]![i].end)} · ${_dueText(days[k]![i].todo, today)}',
                                        style: ts(context, 13, color: p.muted, height: 18 / 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Tap(
                                  onTap: () => setState(() => _removed.add(_key(days[k]![i]))),
                                  label: '이 자리 빼기',
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(Icons.close_rounded, size: 20, color: p.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (names.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Text(
                      '${names.join(', ')}은(는) 마감 전에 비는 시간이 없어서 못 넣었어요.',
                      style: ts(context, 13, color: p.red, height: 19 / 13),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isNotEmpty) ...[
                  BigButton(
                    label: '캘린더에서 보기',
                    quiet: true,
                    onTap: _busy
                        ? null
                        : () {
                            store.showCandidates(items);
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                  ),
                  const SizedBox(height: 8),
                ],
                BigButton(
                  label: items.isEmpty ? '넣을 자리가 없어요' : '모두 넣기 · 일정 ${items.length}개',
                  onTap: items.isEmpty || _busy ? null : () => _apply(store, items),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
