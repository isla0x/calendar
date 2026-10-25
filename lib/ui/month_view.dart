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
        // 요일 줄(30) 을 빼고, 아래 목록에 최소 230 을 남긴 만큼만 달력 칸을 키워요.
        final raw = (c.maxHeight - 30 - 230 - gap * (rows - 1)) / rows;
        final cellH = math.max(44.0, math.min(58.0, raw));

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) {
              store.shiftMonth(1);
            } else if (v > 200) {
              store.shiftMonth(-1);
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var r = 0; r < rows; r++) ...[
                      if (r > 0) const SizedBox(height: gap),
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            Expanded(
                              child: _DayCell(
                                day: addDays(gridStart, r * 7 + i),
                                inMonth: addDays(gridStart, r * 7 + i).month == store.month.month,
                                height: cellH,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(child: _DaySheet()),
            ],
          ),
        );
      },
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
    final evs = inMonth ? store.eventsOn(day) : const <Ev>[];
    final maxBars = math.max(0, math.min(4, ((height - 30) / 7).floor()));
    final bars = math.min(evs.length, maxBars);

    return Tap(
      onTap: () => store.select(day),
      child: Container(
        height: height,
        padding: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
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
            const SizedBox(height: 3),
            for (var i = 0; i < bars; i++) ...[
              if (i > 0) const SizedBox(height: 3),
              Container(
                width: 30,
                height: 4,
                decoration: BoxDecoration(
                  color: evs[i].color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
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
