import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'event_tile.dart';
import 'nav.dart';
import '../l10n.dart';

/// 월간 화면: 달력 + 고른 날의 일정 목록 (목록은 위로 끌어올리면 화면 가득 펼쳐져요)
class MonthView extends StatefulWidget {
  const MonthView({super.key});

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  DraggableScrollableController _sheet = DraggableScrollableController();
  String _sheetKey = '';

  // 달을 옆으로 넘기는 페이지. 처음 열린 달을 5000쪽으로 놓고 달마다 한 쪽씩이에요.
  static const int _basePage = 5000;
  late final DateTime _baseMonth;
  late final PageController _pages;
  bool _dragging = false;
  int? _animTo;

  @override
  void initState() {
    super.initState();
    final m = StoreScope.read(context).month;
    _baseMonth = DateTime(m.year, m.month);
    _pages = PageController(initialPage: _basePage);
  }

  @override
  void dispose() {
    _pages.dispose();
    _sheet.dispose();
    super.dispose();
  }

  int _pageOf(DateTime m) =>
      _basePage + (m.year - _baseMonth.year) * 12 + (m.month - _baseMonth.month);

  DateTime _monthOf(int page) =>
      DateTime(_baseMonth.year, _baseMonth.month + (page - _basePage));

  /// 버튼이나 날짜 선택으로 달이 바뀌면 페이지도 부드럽게 따라가요. (손으로 끄는 중에는 건드리지 않아요)
  void _syncPage(int target) {
    if (!_pages.hasClients || _dragging || _animTo == target) return;
    final cur = _pages.page;
    if (cur == null || (cur - target).abs() < 0.001) return;
    _animTo = target;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_pages.hasClients) {
        _animTo = null;
        return;
      }
      final from = _pages.page ?? target.toDouble();
      if ((target - from).abs() > 1.5) {
        _pages.jumpToPage(target);
      } else {
        await _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      _animTo = null;
    });
  }

  /// 손을 떼서 페이지가 자리 잡으면 그 달로 정해요.
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
    if (n is ScrollEndNotification) {
      _dragging = false;
      final store = StoreScope.read(context);
      final page = _pages.page;
      if (page != null) {
        final delta = page.round() - _pageOf(store.month);
        if (delta != 0) store.shiftMonth(delta);
      }
    }
    return false;
  }

  /// 달력 크기가 바뀌면(달이 바뀌어 줄 수가 달라질 때 등) 목록 시트를 새 컨트롤러로 다시 만들어요.
  /// (같은 컨트롤러를 두 시트에 동시에 붙일 수 없어서, 옛 것은 한 프레임 뒤에 정리해요.)
  void _syncSheet(String key) {
    if (key == _sheetKey) return;
    if (_sheetKey.isNotEmpty) {
      final old = _sheet;
      _sheet = DraggableScrollableController();
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _sheetKey = key;
  }

  void _toggle(double minSize, double maxSize) {
    if (!_sheet.isAttached) return;
    final open = _sheet.size > (minSize + maxSize) / 2;
    _sheet.animateTo(
      open ? minSize : maxSize,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);

    final first = DateTime(store.month.year, store.month.month, 1);
    final last = DateTime(store.month.year, store.month.month + 1, 0);
    final gridStart = weekStartSunday(first);
    final rows = daysBetween(gridStart, last) ~/ 7 + 1;

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 2.0;
        // 요일 줄(30) 을 빼고, 아래 목록에 최소 260 을 남긴 만큼만 달력 칸을 키워요.
        // 칸이 클수록 일정 글자가 더 많이 보여요.
        final raw = (c.maxHeight - 30 - 260 - gap * (rows - 1)) / rows;
        final cellH = math.max(50.0, math.min(104.0, raw));
        final gridBottom = 30 + rows * cellH + gap * (rows - 1) + 8;
        final minSize = (1 - gridBottom / c.maxHeight).clamp(0.2, 0.9).toDouble();
        // 펼쳐도 위쪽 "월/주/일" 줄이 가려지지 않게 살짝 남겨요.
        final maxSize = 1 - 6 / c.maxHeight;
        final sheetKey = 'daysheet-$rows-${gridBottom.round()}';
        _syncSheet(sheetKey);
        _syncPage(_pageOf(store.month));
        final gridH = rows * cellH + gap * (rows - 1);

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_kSide, 8, _kSide, 0),
                    child: SizedBox(
                      height: 22,
                      child: Row(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            Expanded(
                              child: Center(
                                child: Text(
                                  wdHead((i + 6) % 7 + 1),
                                  style: ts(
                                    context,
                                    12,
                                    weight: FontWeight.w600,
                                    color: i == 0 ? p.red : (i == 6 ? p.blue : p.muted),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _kSide),
                    child: SizedBox(
                      height: gridH,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: PageView.builder(
                          controller: _pages,
                          itemBuilder: (context, i) {
                            final m = _monthOf(i);
                            final g0 = weekStartSunday(DateTime(m.year, m.month, 1));
                            final end = DateTime(m.year, m.month + 1, 0);
                            final n = daysBetween(g0, end) ~/ 7 + 1;
                            // 줄 수가 다른 달은 위쪽을 맞춰요 (넘어가는 동안 모자라는 쪽은 잘려 보여요)
                            return OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: 0,
                              maxHeight: double.infinity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var r = 0; r < n; r++) ...[
                                    if (r > 0) const SizedBox(height: gap),
                                    _WeekRow(
                                      start: addDays(g0, r * 7),
                                      month: m.month,
                                      height: cellH,
                                      gap: gap,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: DraggableScrollableSheet(
                key: ValueKey(sheetKey),
                controller: _sheet,
                initialChildSize: minSize,
                minChildSize: minSize,
                maxChildSize: maxSize,
                snap: true,
                builder: (context, scroll) =>
                    _DaySheet(scroll: scroll, onToggle: () => _toggle(minSize, maxSize)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 달력 양옆 여백 (글자가 더 보이도록 좁게)
const double _kSide = 10;

/// 날짜 숫자 아래에서 일정 글자가 시작하는 높이, 글자 줄 하나의 높이
const double _kChipTop = 30;
const double _kLane = 15;
const double _kChip = 14;

int _lanesFor(double cellHeight) => math.max(1, ((cellHeight - _kChipTop - 2) / _kLane).floor());

/// 한 주에 그려지는 일정 띠 하나. 며칠에 걸친 일정은 c0..c1 칸을 이어서 차지해요.
class _Bar {
  _Bar(this.ev, this.c0, this.c1, this.contL, this.contR, {this.run = false});

  final Ev ev;
  final int c0;
  final int c1;

  /// 앞 주에서 이어지는지, 다음 주로 이어지는지
  final bool contL;
  final bool contR;
  int lane = 0;

  /// 매일 반복처럼 날마다 따로 있지만 이어서 한 줄로 그리는 일정인지
  final bool run;

  bool get span => run || ev.lastDay.isAfter(ev.firstDay);
}

/// 한 주(일~토)의 일정들을 줄(lane)에 배치해요. 여러 날짜 일정이 먼저 위쪽 줄을 차지해요.
List<_Bar> _layoutWeek(CalendarStore store, List<DateTime> days) {
  final bars0 = <_Bar>[];
  final cols = <String, List<int>>{};
  final evs = <String, Ev>{};
  for (var i = 0; i < 7; i++) {
    for (final e in store.shownOn(days[i])) {
      // 반복 일정은 같은 시리즈끼리 한 묶음으로 모아서, 이어진 날들을 한 줄로 그려요.
      final k = e.recurring
          ? 'r|${e.id}'
          : '${e.id}|${e.start.millisecondsSinceEpoch}|${e.end.millisecondsSinceEpoch}';
      final l = cols[k] ??= <int>[];
      if (!l.contains(i)) l.add(i);
      evs[k] ??= e;
    }
  }
  bool occursOn(Ev e, DateTime d) => store.shownOn(d).any((x) => x.id == e.id);
  for (final k in cols.keys) {
    final e = evs[k]!;
    final cs = cols[k]!..sort();
    if (e.recurring) {
      var a = cs.first;
      var prev = a;
      void flush(int z) {
        final l = a == 0 && occursOn(e, addDays(days[0], -1));
        final r = z == 6 && occursOn(e, addDays(days[6], 1));
        bars0.add(_Bar(e, a, z, l, r, run: z > a || l || r));
      }

      for (final c in cs.skip(1)) {
        if (c == prev + 1) {
          prev = c;
          continue;
        }
        flush(prev);
        a = c;
        prev = c;
      }
      flush(prev);
      continue;
    }
    final c0 = cs.first;
    final c1 = cs.last;
    bars0.add(_Bar(
      e,
      c0,
      c1,
      c0 == 0 && e.firstDay.isBefore(days[0]),
      c1 == 6 && e.lastDay.isAfter(days[6]),
    ));
  }
  final bars = bars0
    ..sort((a, b) {
      if (a.span != b.span) return a.span ? -1 : 1;
      if (a.span) {
        final la = a.c1 - a.c0;
        final lb = b.c1 - b.c0;
        if (la != lb) return lb.compareTo(la);
      }
      if (a.c0 != b.c0) return a.c0.compareTo(b.c0);
      if (a.ev.allDay != b.ev.allDay) return a.ev.allDay ? -1 : 1;
      final t = a.ev.start.compareTo(b.ev.start);
      if (t != 0) return t;
      return a.ev.title.compareTo(b.ev.title);
    });
  final used = <List<bool>>[];
  for (final b in bars) {
    var lane = 0;
    while (true) {
      if (lane == used.length) used.add(List<bool>.filled(7, false));
      var free = true;
      for (var c = b.c0; c <= b.c1; c++) {
        if (used[lane][c]) {
          free = false;
          break;
        }
      }
      if (free) break;
      lane++;
    }
    for (var c = b.c0; c <= b.c1; c++) {
      used[lane][c] = true;
    }
    b.lane = lane;
  }
  return bars;
}

/// 달력 한 줄(한 주): 날짜 칸들 위에 일정 글자를 얹어요.
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.start,
    required this.month,
    required this.height,
    required this.gap,
  });

  final DateTime start;
  final int month;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final days = [for (var i = 0; i < 7; i++) addDays(start, i)];
    final bars = _layoutWeek(store, days);
    final n = _lanesFor(height);

    // 칸마다 안 보이는 일정이 있으면 마지막 줄을 "+N" 으로 바꿔요. (줄이 둘 이상일 때만)
    final more = List<int>.filled(7, 0);
    if (n >= 2) {
      final hidden = List<int>.filled(7, 0);
      final fromLast = List<int>.filled(7, 0);
      for (final b in bars) {
        for (var c = b.c0; c <= b.c1; c++) {
          if (b.lane >= n) hidden[c]++;
          if (b.lane >= n - 1) fromLast[c]++;
        }
      }
      for (var c = 0; c < 7; c++) {
        if (hidden[c] > 0) more[c] = fromLast[c];
      }
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final cellW = (box.maxWidth - gap * 6) / 7;
          double xOf(int col) => col * (cellW + gap);
          double wOf(int a, int b) => (b - a + 1) * cellW + (b - a) * gap;

          final chips = <Widget>[];

          void addChip(_Bar b, int a, int z, {required bool left, required bool right, bool label = true}) {
            final c = evColors(b.ev.color, p);
            final solid = !p.dark && (b.ev.allDay || b.span);
            final lx = left ? 0.0 : 1.0;
            final rx = right ? 0.0 : 1.0;
            chips.add(Positioned(
              left: xOf(a) + lx,
              width: wOf(a, z) - lx - rx,
              top: _kChipTop + b.lane * _kLane,
              height: _kChip,
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: solid ? c.solid : c.tint,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(left ? 0 : 4),
                    right: Radius.circular(right ? 0 : 4),
                  ),
                ),
                child: label
                    ? Text(
                        b.ev.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(
                          context,
                          10,
                          weight: FontWeight.w600,
                          color: solid ? c.onSolid : c.text,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      )
                    : null,
              ),
            ));
          }

          for (final b in bars) {
            if (b.lane >= n) continue;
            final lastLane = n >= 2 && b.lane == n - 1;
            if (!lastLane) {
              addChip(b, b.c0, b.c1, left: b.contL, right: b.contR);
              continue;
            }
            // 마지막 줄: "+N" 이 들어가는 칸은 비워 두고 나머지 칸에만 그려요.
            var c = b.c0;
            var first = true;
            while (c <= b.c1) {
              if (more[c] > 0) {
                c++;
                continue;
              }
              var z = c;
              while (z + 1 <= b.c1 && more[z + 1] == 0) {
                z++;
              }
              addChip(
                b,
                c,
                z,
                left: c == b.c0 ? b.contL : false,
                right: z == b.c1 ? b.contR : false,
                label: first,
              );
              first = false;
              c = z + 1;
            }
          }
          for (var c = 0; c < 7; c++) {
            if (more[c] == 0) continue;
            chips.add(Positioned(
              left: xOf(c),
              width: cellW,
              top: _kChipTop + (n - 1) * _kLane,
              height: _kChip,
              child: Center(
                child: Text(
                  '+${more[c]}',
                  style: ts(context, 10, weight: FontWeight.w700, color: p.muted, height: 1.2),
                ),
              ),
            ));
          }

          return Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: _DayCell(
                        day: days[i],
                        inMonth: days[i].month == month,
                        height: height,
                      ),
                    ),
                  ],
                ],
              ),
              Positioned.fill(child: IgnorePointer(child: Stack(children: chips))),
            ],
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.inMonth, required this.height});

  final DateTime day;
  final bool inMonth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);

    final isToday = sameDay(day, store.today);
    final isSel = sameDay(day, store.selected);
    final hol = store.holidayOn(day) != null;
    final col = day.weekday % 7; // 0 = 일요일

    Color fg = p.ink;
    if (!inMonth) {
      fg = p.muted;
    } else if (hol || col == 0) {
      fg = p.red;
    } else if (col == 6) {
      fg = p.blue;
    }
    var numBg = Colors.transparent;
    if (isToday) {
      numBg = p.ink;
      fg = p.bg;
    }

    return Tap(
      onTap: () => store.select(day),
      child: Container(
        height: height,
        padding: const EdgeInsets.only(top: 4),
        alignment: Alignment.topCenter,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: numBg,
            shape: BoxShape.circle,
            border: isSel ? Border.all(color: p.ink, width: 1.5) : null,
          ),
          child: Text(
            '${day.day}',
            style: ts(context, 15, weight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }
}

/// 고른 날의 일정 목록 (아래에서 올라온 듯한 시트). 위로 끌면 화면 가득 펼쳐져요.
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.scroll, required this.onToggle});

  final ScrollController scroll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final day = store.selected;
    final evs = store.shownOn(day);
    final filter = store.tagFilter;
    final isPast = day.isBefore(store.today);
    final isToday = sameDay(day, store.today);
    final holiday = store.holidayOn(day);

    final parts = <String>[];
    if (holiday != null) parts.add(holiday);
    parts.add(evs.isEmpty ? tl('일정 없음') : tl('일정 {0}개', [evs.length]));
    if (!isPast) {
      final free = store.freeMinutes(day, from: isToday ? store.now : null);
      parts.add(free <= 0 ? tl('여유 없음') : tl('여유 {0}', [durText(Duration(minutes: free))]));
    }

    return Container(
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: p.line, offset: const Offset(0, -1))],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        children: [
          Tap(
            onTap: onToggle,
            label: tl('목록 크게 보기'),
            child: SizedBox(
              height: 24,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.dark ? p.dash : Color.alphaBlend(p.dash.withAlpha(140), p.surface),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dateFull(day),
                  style: ts(context, 18, weight: FontWeight.w700, letterSpacing: -0.36),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parts.join(' · '),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(context, 13, color: p.muted),
                  ),
                ),
              ],
            ),
          ),
          if (evs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28, bottom: 200),
              child: Center(
                child: Text(
                  filter != null
                      ? tl('이 날은 #{0} 일정이 없어요', [filter])
                      : (isPast ? tl('이 날은 일정이 없었어요') : tl('비어 있는 날이에요')),
                  style: ts(context, 14, color: p.muted),
                ),
              ),
            )
          else ...[
            for (final e in evs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: EventTile(event: e, onTap: () => openEvent(context, e)),
              ),
            const SizedBox(height: 130),
          ],
        ],
      ),
    );
  }
}
