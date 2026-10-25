import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'pager.dart';

/// 주간 화면: 7일을 가로 막대로 쌓아서 한눈에 비교
class WeekView extends StatelessWidget {
  const WeekView({super.key});

  // 2000-01-02 는 일요일이라, 여기서부터 센 주 번호로 쪽을 구분해요.
  static final DateTime _epoch = DateTime(2000, 1, 2);

  @override
  Widget build(BuildContext context) {
    return SwipePager(
      index: (s) => daysBetween(_epoch, weekStartSunday(s.selected)) ~/ 7,
      onShift: (s, d) => s.shiftWeek(d),
      builder: (context, i) => _WeekPage(start: addDays(_epoch, i * 7)),
    );
  }
}

class _WeekPage extends StatelessWidget {
  const _WeekPage({required this.start});

  final DateTime start;

  static const int _rs = 9 * 60;
  static const int _re = 22 * 60;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final days = [for (var i = 0; i < 7; i++) addDays(start, i)];
    final today = store.today;
    final now = store.now;

    // 가장 여유로운 날 / 가장 바쁜 날 (오늘부터 남은 날만 비교)
    final cands = <DateTime>[];
    final free = <int, int>{};
    for (final d in days) {
      if (d.isBefore(today)) continue;
      cands.add(d);
      free[dayKey(d)] = store.freeMinutes(d, from: sameDay(d, today) ? now : null);
    }
    DateTime? best;
    DateTime? busy;
    for (final d in cands) {
      final f = free[dayKey(d)] ?? 0;
      if (best == null || f > (free[dayKey(best)] ?? 0)) best = d;
      if (busy == null || f < (free[dayKey(busy)] ?? 0)) busy = d;
    }
    final showCards = best != null &&
        busy != null &&
        cands.length >= 2 &&
        (free[dayKey(best)] ?? 0) != (free[dayKey(busy)] ?? 0);

    return ListView(
      padding: const EdgeInsets.only(bottom: 130),
      children: [
        if (showCards)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _InsightCard(
                    label: '가장 여유로운 날',
                    value: '${wd(best)}요일 · ${freeText(free[dayKey(best)] ?? 0)}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InsightCard(
                    label: '가장 바쁜 날',
                    value: (free[dayKey(busy)] ?? 0) <= 0
                        ? '${wd(busy)}요일 · 여유 없음'
                        : '${wd(busy)}요일 · 여유 ${freeText(free[dayKey(busy)] ?? 0)}',
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(62, 10, 16, 0),
          child: LayoutBuilder(
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
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _WeekRow(day: days[i], column: i),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ts(context, 11, color: p.muted, height: 14 / 11)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(context, 13, weight: FontWeight.w700, height: 18 / 13),
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.day, required this.column});

  final DateTime day;
  final int column;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final today = store.today;
    final now = store.now;
    final isToday = sameDay(day, today);
    final isPast = day.isBefore(today);
    final hol = store.holidayOn(day);
    final evs = store.shownOn(day);
    // 시간 막대는 모든 일정을 그리되, 태그로 걸러보는 중이면 해당하지 않는 것은 흐리게 해요.
    final timed = store.eventsOn(day).where((e) => !e.allDay).toList();

    // 요일·날짜 글자 색
    Color letter = p.muted;
    Color numColor = p.ink;
    if (column == 0) {
      letter = p.red;
      numColor = p.red;
    } else if (column == 6) {
      letter = p.blue;
      numColor = p.blue;
    }
    if (hol != null) numColor = p.red;
    if (isToday) numColor = p.bg;

    // 아래 줄: 일정 이름 + 여유
    final names = <String>[];
    if (hol != null) names.add(hol);
    if (evs.isEmpty) {
      if (hol == null) names.add('일정 없음');
    } else {
      Ev? first;
      for (final e in evs) {
        if (isToday && !e.allDay && !e.end.isAfter(now)) continue;
        first = e;
        break;
      }
      first ??= evs.first;
      names.add(evs.length == 1 ? first.title : '${first.title} 외 ${evs.length - 1}개');
    }

    String freeLabel;
    if (isPast) {
      freeLabel = '지난 날';
    } else if (isToday) {
      freeLabel = '남은 여유 ${freeText(store.freeMinutes(day, from: now))}';
    } else {
      freeLabel = '여유 ${freeText(store.freeMinutes(day))}';
    }
    if (freeLabel.endsWith('여유 없음')) freeLabel = '여유 없음';

    const rs = _WeekPage._rs;
    const re = _WeekPage._re;
    final nowMin = now.hour * 60 + now.minute;

    return Tap(
      onTap: () {
        store.select(day);
        store.setView(ViewMode.day);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isToday ? p.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isToday ? Border.all(color: p.line) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(wd(day), style: ts(context, 11, weight: FontWeight.w600, color: letter, height: 14 / 11)),
                  const SizedBox(height: 2),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? p.ink : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${day.day}', style: ts(context, 15, weight: FontWeight.w600, color: numColor)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      double fx(int min) {
                        final v = math.max(rs, math.min(re, min));
                        return (v - rs) / (re - rs) * w;
                      }

                      final kids = <Widget>[];
                      for (final h in const [12, 15, 18, 21]) {
                        kids.add(Positioned(
                          left: fx(h * 60),
                          top: 0,
                          bottom: 0,
                          width: 1,
                          child: ColoredBox(color: p.line),
                        ));
                      }
                      for (final e in timed) {
                        final s = minOfDay(e.start, day);
                        final t = minOfDay(e.end, day);
                        final l = fx(s);
                        final r = fx(t);
                        if (r - l < 2) continue;
                        kids.add(Positioned(
                          left: l,
                          top: 3,
                          width: r - l,
                          height: 22,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: !store.tagMatch(e)
                                  ? e.color.withAlpha(48)
                                  : (isPast ? e.color.withAlpha(102) : e.color),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ));
                      }
                      if (isToday && nowMin >= rs && nowMin <= re) {
                        kids.add(Positioned(
                          left: fx(nowMin) - 1,
                          top: -3,
                          width: 2,
                          height: 34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.now,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ));
                      }
                      return Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: p.soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(clipBehavior: Clip.none, children: kids),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          names.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, 12, weight: FontWeight.w400, color: p.muted, height: 15 / 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        freeLabel,
                        maxLines: 1,
                        style: ts(
                          context,
                          12,
                          weight: FontWeight.w600,
                          color: isPast ? p.muted : p.ink,
                          height: 15 / 12,
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
    );
  }
}
