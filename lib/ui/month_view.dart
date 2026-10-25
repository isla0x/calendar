import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'event_tile.dart';
import 'nav.dart';

/// 월간 화면: 달력 + 고른 날의 일정 목록
class MonthView extends StatelessWidget {
  const MonthView({super.key});

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
        // 요일 줄(30) 을 빼고, 아래 목록에 최소 200 을 남긴 만큼만 달력 칸을 키워요.
        // 칸이 클수록 일정 글자가 더 많이 보여요.
        final raw = (c.maxHeight - 30 - 200 - gap * (rows - 1)) / rows;
        final cellH = math.max(50.0, math.min(104.0, raw));

        return Column(
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
                            kWeekdayKo[(i + 6) % 7],
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
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++) ...[
                    if (r > 0) const SizedBox(height: gap),
                    _WeekRow(
                      start: addDays(gridStart, r * 7),
                      month: store.month.month,
                      height: cellH,
                      gap: gap,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(child: _DaySheet()),
          ],
        );
      },
    );
  }
}

/// 달력 양옆 여백 (글자가 더 보이도록 좁게)
const double _kSide = 10;

/// 날짜 숫자 아래에서 일정 글자가 시작하는 높이, 글자 줄 하나의 높이
const double _kChipTop = 31;
const double _kLane = 16;
const double _kChip = 15;

int _lanesFor(double cellHeight) => math.max(1, ((cellHeight - _kChipTop - 2) / _kLane).floor());

/// 한 주에 그려지는 일정 띠 하나. 며칠에 걸친 일정은 c0..c1 칸을 이어서 차지해요.
class _Bar {
  _Bar(this.ev, this.c0, this.c1, this.contL, this.contR);

  final Ev ev;
  final int c0;
  final int c1;

  /// 앞 주에서 이어지는지, 다음 주로 이어지는지
  final bool contL;
  final bool contR;
  int lane = 0;

  bool get span => ev.lastDay.isAfter(ev.firstDay);
}

/// 한 주(일~토)의 일정들을 줄(lane)에 배치해요. 여러 날짜 일정이 먼저 위쪽 줄을 차지해요.
List<_Bar> _layoutWeek(CalendarStore store, List<DateTime> days) {
  final byKey = <String, _Bar>{};
  final cols = <String, List<int>>{};
  final evs = <String, Ev>{};
  for (var i = 0; i < 7; i++) {
    for (final e in store.eventsOn(days[i])) {
      final k = '${e.id}|${e.start.millisecondsSinceEpoch}|${e.end.millisecondsSinceEpoch}';
      (cols[k] ??= <int>[]).add(i);
      evs[k] = e;
    }
  }
  for (final k in cols.keys) {
    final e = evs[k]!;
    final cs = cols[k]!;
    final c0 = cs.reduce(math.min);
    final c1 = cs.reduce(math.max);
    byKey[k] = _Bar(
      e,
      c0,
      c1,
      c0 == 0 && e.firstDay.isBefore(days[0]),
      c1 == 6 && e.lastDay.isAfter(days[6]),
    );
  }
  final bars = byKey.values.toList()
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
                        softWrap: false,
                        overflow: TextOverflow.clip,
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

    final lv = inMonth ? store.loadLevel(day) : 0;
    final tint = lv == 0
        ? Colors.transparent
        : (lv == 1 ? p.busy1 : (lv == 2 ? p.busy2 : p.busy3));

    return Tap(
      onTap: () => store.select(day),
      child: Container(
        height: height,
        padding: const EdgeInsets.only(top: 4),
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
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

/// 고른 날의 일정 목록 (아래에서 올라온 듯한 시트)
class _DaySheet extends StatelessWidget {
  const _DaySheet();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final day = store.selected;
    final evs = store.eventsOn(day);
    final isPast = day.isBefore(store.today);
    final isToday = sameDay(day, store.today);
    final holiday = store.holidayOn(day);

    final parts = <String>[];
    if (holiday != null) parts.add(holiday);
    parts.add(evs.isEmpty ? '일정 없음' : '일정 ${evs.length}개');
    if (!isPast) {
      final free = store.freeMinutes(day, from: isToday ? store.now : null);
      parts.add(free <= 0 ? '여유 없음' : '여유 ${durText(Duration(minutes: free))}');
    }

    return Container(
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: p.line, offset: const Offset(0, -1))],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: p.dark ? p.dash : Color.alphaBlend(p.dash.withAlpha(140), p.surface),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${day.month}월 ${day.day}일 ${wdFull(day)}',
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
          Expanded(
            child: evs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        isPast ? '이 날은 일정이 없었어요' : '비어 있는 날이에요',
                        style: ts(context, 14, color: p.muted),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 130),
                    children: [
                      for (final e in evs)
                        EventTile(event: e, onTap: () => openDetail(context, e)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
