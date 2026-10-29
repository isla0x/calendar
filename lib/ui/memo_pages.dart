import 'package:flutter/material.dart';

import '../dates.dart';
import '../memos.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'sheets.dart';
import '../l10n.dart';

/// 메모 색 (연한 노랑). 일정 색과 겹치지 않게 따로 둬요.
class _MemoColors {
  const _MemoColors(this.bg, this.line, this.accent);

  final Color bg;
  final Color line;
  final Color accent;

  static _MemoColors of(Pal p) => p.dark
      ? const _MemoColors(Color(0xFF2E2A1C), Color(0xFF4A4126), Color(0xFFD9BC6A))
      : const _MemoColors(Color(0xFFFFF7DC), Color(0xFFF1E0B8), Color(0xFF8A6C26));
}

// ---------------------------------------------------------------- 메모 한 줄

/// 점 + 글. 누르면 줄이 그어지고(끝냄), 길게 누르면 고쳐요.
class _MemoLine extends StatelessWidget {
  const _MemoLine({required this.memo, this.size = 15});

  final Memo memo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mc = _MemoColors.of(p);
    final store = StoreScope.read(context);
    final done = memo.done;
    return Semantics(
      button: true,
      label: done ? tl('완료 표시 지우기') : tl('완료로 표시'),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => store.toggleMemo(memo.id),
        onLongPress: () => showMemoSheet(context, day: memo.day, memo: memo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8),
                child: Text('·', style: ts(context, size, weight: FontWeight.w700, color: mc.accent, height: 22 / size)),
              ),
              Expanded(
                child: Text(
                  memo.text,
                  style: ts(
                    context,
                    size,
                    color: done ? p.muted : p.ink,
                    height: 22 / size,
                  ).copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationThickness: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 일간 화면 카드

/// 일간 화면 위쪽에 들어가는 그날 메모. 메모가 없으면 작은 "메모 쓰기" 알약만 보여요.
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.day});

  final DateTime day;

  static const int _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final mc = _MemoColors.of(p);
    final list = store.memosOn(day);

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Tap(
            onTap: () => showMemoSheet(context, day: day),
            label: tl('메모 쓰기'),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.soft,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 16, color: p.muted),
                  const SizedBox(width: 6),
                  Text(tl('메모 쓰기'), style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final shown = list.take(_maxLines).toList();
    final more = list.length - shown.length;
    final isToday = sameDay(day, store.today);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      decoration: BoxDecoration(
        color: mc.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, size: 17, color: mc.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isToday ? tl('오늘 메모') : tl('메모'),
                  style: ts(context, 14, weight: FontWeight.w700, color: mc.accent),
                ),
              ),
              Tap(
                onTap: () => showMemoSheet(context, day: day),
                label: tl('메모 쓰기'),
                child: SizedBox(
                  width: 36,
                  height: 32,
                  child: Icon(Icons.add_rounded, size: 22, color: mc.accent),
                ),
              ),
              Tap(
                onTap: () => openMemosFrom(context),
                child: SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(tl('모두 보기'), style: ts(context, 13, weight: FontWeight.w600, color: mc.accent)),
                  ),
                ),
              ),
            ],
          ),
          for (final m in shown) _MemoLine(memo: m),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(tl('외 {0}개', [more]), style: ts(context, 13, color: p.muted)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 쓰기·고치기 시트

/// 메모를 쓰거나(memo 없음) 고치는 창. 날짜는 바꿀 수 있어요.
Future<void> showMemoSheet(BuildContext context, {required DateTime day, Memo? memo}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => _MemoSheet(day: day, memo: memo),
  );
}

class _MemoSheet extends StatefulWidget {
  const _MemoSheet({required this.day, required this.memo});

  final DateTime day;
  final Memo? memo;

  @override
  State<_MemoSheet> createState() => _MemoSheetState();
}

class _MemoSheetState extends State<_MemoSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.memo?.text ?? '');
  late DateTime _day = dayOnly(widget.day);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final d = await showDateSheet(context, initial: _day, title: tl('메모 날짜'));
    if (d != null && mounted) setState(() => _day = d);
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final m = widget.memo;
    if (m == null) {
      await store.addMemos(_day, _c.text);
    } else {
      await store.editMemo(m, text: _c.text, day: _day);
    }
    if (nav.mounted) nav.pop();
  }

  Future<void> _delete() async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    await store.removeMemo(widget.memo!.id);
    if (nav.mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mc = _MemoColors.of(p);
    final editing = widget.memo != null;
    return SheetFrame(
      title: editing ? tl('메모 고치기') : tl('메모'),
      footer: Row(
        children: [
          Expanded(
            flex: 2,
            child: editing
                ? BigButton(label: tl('지우기'), quiet: true, color: p.red, onTap: _delete)
                : BigButton(label: tl('취소'), quiet: true, onTap: () => Navigator.of(context).pop()),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: BigButton(label: tl('저장'), onTap: _save)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tap(
            onTap: _pickDay,
            label: tl('메모 날짜'),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: p.ink),
                  const SizedBox(width: 8),
                  Text(dateChip(_day), style: ts(context, 14, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: mc.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: mc.line),
            ),
            child: TextField(
              controller: _c,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              cursorColor: p.ink,
              style: ts(context, 16, height: 24 / 16),
              decoration: InputDecoration.collapsed(
                hintText: tl('적어 두고 싶은 것 · 줄을 바꾸면 한 줄씩 따로 저장돼요'),
                hintStyle: ts(context, 16, color: p.dash, height: 24 / 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 모아보기

void openMemosFrom(BuildContext context) {
  Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const MemoListPage()));
}

class MemoListPage extends StatefulWidget {
  const MemoListPage({super.key});

  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final mc = _MemoColors.of(p);
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final q = _q.text.trim().toLowerCase();
    final all = store.allMemos;
    final list = q.isEmpty ? all : [for (final m in all) if (m.text.toLowerCase().contains(q)) m];

    // 날짜별로 묶기 (이미 최근 날짜 순)
    final groups = <DateTime, List<Memo>>{};
    for (final m in list) {
      groups.putIfAbsent(m.day, () => <Memo>[]).add(m);
    }
    final today = store.today;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8, top + 4, 20, 0),
                child: Row(
                  children: [
                    Tap(
                      onTap: () => Navigator.of(context).pop(),
                      label: tl('뒤로'),
                      child: SizedBox(
                        width: 44,
                        height: 56,
                        child: Icon(Icons.chevron_left_rounded, size: 28, color: p.ink),
                      ),
                    ),
                    Text(tl('메모'), style: ts(context, 30, weight: FontWeight.w700, height: 38 / 30)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _q,
                          onChanged: (_) => setState(() {}),
                          cursorColor: p.ink,
                          style: ts(context, 15),
                          decoration: InputDecoration.collapsed(
                            hintText: tl('메모 찾기'),
                            hintStyle: ts(context, 15, color: p.dash),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            q.isEmpty
                                ? tl('아직 메모가 없어요.\n하루에 한두 줄, 잊고 싶지 않은 걸 적어 두세요.')
                                : tl('찾는 메모가 없어요'),
                            textAlign: TextAlign.center,
                            style: ts(context, 14, color: p.muted, height: 1.6),
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(16, 6, 16, bottom + 100),
                        children: [
                          for (final e in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                              child: Text(
                                sameDay(e.key, today)
                                    ? '${tl('오늘')} · ${dateChip(e.key)}'
                                    : dateChip(e.key),
                                style: ts(
                                  context,
                                  13,
                                  weight: FontWeight.w700,
                                  color: sameDay(e.key, today) ? mc.accent : p.muted,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: sameDay(e.key, today) ? mc.bg : p.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sameDay(e.key, today) ? mc.line : p.line),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (final m in e.value)
                                    Dismissible(
                                      key: ValueKey(m.id),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (_) => store.removeMemo(m.id),
                                      background: Container(
                                        color: p.red,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        child: Text(tl('지우기'), style: ts(context, 14, weight: FontWeight.w700, color: Colors.white)),
                                      ),
                                      child: Container(
                                        color: sameDay(e.key, today) ? mc.bg : p.surface,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                        child: _MemoLine(memo: m),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                            child: Text(
                              tl('눌러서 완료 표시 · 길게 누르면 고치기 · 왼쪽으로 밀어서 지우기'),
                              style: ts(context, 12, color: p.muted, height: 17 / 12),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: bottom + 24,
            child: Tap(
              onTap: () => showMemoSheet(context, day: store.selected),
              label: tl('메모 쓰기'),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: p.ink,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [BoxShadow(color: p.shadow, blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 22, color: p.bg),
                    const SizedBox(width: 8),
                    Text(tl('메모 쓰기'), style: ts(context, 16, weight: FontWeight.w600, color: p.bg)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
