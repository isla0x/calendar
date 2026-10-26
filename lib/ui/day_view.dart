import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../todos.dart';
import '../travel.dart';
import 'common.dart';
import 'nav.dart';
import 'pager.dart';
import '../l10n.dart';

/// 일간(오늘) 화면: 주 띠 + 남은 여유 카드 + 시간표
class DayView extends StatelessWidget {
  const DayView({super.key});

  static final DateTime _epoch = DateTime(2000, 1, 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _WeekStrip(),
        Expanded(
          child: SwipePager(
            index: (s) => daysBetween(_epoch, s.selected),
            onShift: (s, d) => s.shiftDay(d),
            builder: (context, i) => _DayPage(day: addDays(_epoch, i)),
          ),
        ),
      ],
    );
  }
}

/// 하루치 내용 (남은 여유 카드 + 시간표). 옆으로 밀면 이 쪽이 넘어가요.
class _DayPage extends StatelessWidget {
  const _DayPage({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isToday = sameDay(day, store.today);
    final now = store.now;

    final all = store.listedOn(day);
    final timed = all.where((e) => !e.allDay).toList();
    final allDay = all.where((e) => e.allDay).toList();
    final pastCount = isToday ? timed.where((e) => !e.end.isAfter(now)).length : 0;

    return Column(
      children: [
        _FlowCard(day: day),
        if (pastCount > 0) _PastChip(count: pastCount) else const SizedBox(height: 8),
        if (allDay.isNotEmpty) _AllDayRow(events: allDay),
        Expanded(child: _Timeline(day: day)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 주 띠

class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final start = weekStartSunday(store.selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: _StripCell(day: addDays(start, i))),
          ],
        ],
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final isSel = sameDay(day, store.selected);
    final isToday = sameDay(day, store.today);
    final col = day.weekday % 7;
    final hol = store.holidayOn(day) != null;
    final evs = store.shownOn(day);
    final dots = math.min(3, evs.length);

    Color letter = p.muted;
    Color numColor = p.ink;
    if (col == 0) {
      letter = p.red;
      numColor = p.red;
    } else if (col == 6) {
      letter = p.blue;
      numColor = p.blue;
    }
    if (hol) numColor = p.red;
    if (isSel) numColor = p.bg;

    return Tap(
      onTap: () => store.select(day),
      child: SizedBox(
        height: 56,
        child: Column(
          children: [
            Text(wd(day), style: ts(context, 11, weight: FontWeight.w600, color: letter, height: 14 / 11)),
            const SizedBox(height: 2),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? p.ink : Colors.transparent,
                shape: BoxShape.circle,
                border: (!isSel && isToday) ? Border.all(color: p.ink, width: 1.5) : null,
              ),
              child: Text('${day.day}', style: ts(context, 15, weight: FontWeight.w600, color: numColor)),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < dots; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Dot(evs[i].color, size: 5),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 남은 여유 카드

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.day});

  final DateTime day;

  static const int _rs = 7 * 60;
  static const int _re = 23 * 60;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final today = store.today;
    final isToday = sameDay(day, today);
    final isPast = day.isBefore(today);
    final now = store.now;
    final evs = store.listedOn(day);
    final timed = store.eventsOn(day).where((e) => !e.allDay).toList();

    String label;
    String value;
    String? right;
    if (isPast) {
      label = tl('지난 날');
      value = evs.isEmpty ? tl('일정 없음') : tl('일정 {0}개', [evs.length]);
    } else if (isToday) {
      label = tl('오늘 남은 여유');
      value = freeText(store.freeMinutes(day, from: now));
      right = tl('22시까지');
    } else {
      label = tl('이 날의 여유');
      value = freeText(store.freeMinutes(day));
      right = tl('9시~22시');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ts(context, 12, color: p.muted, height: 15 / 12)),
                    Text(
                      value,
                      style: ts(context, 24, weight: FontWeight.w700, height: 30 / 24, letterSpacing: -0.48),
                    ),
                  ],
                ),
              ),
              if (right != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(right, style: ts(context, 12, color: p.muted, height: 15 / 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              double fx(int min) {
                final v = math.max(_rs, math.min(_re, min));
                return (v - _rs) / (_re - _rs) * w;
              }

              final blocks = <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.soft,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ];
              for (final e in timed) {
                final s = minOfDay(e.start, day);
                final t = minOfDay(e.end, day);
                final l = fx(s);
                final r = fx(t);
                if (r - l < 2) continue;
                final ended = isPast || (isToday && !e.end.isAfter(now));
                blocks.add(Positioned(
                  left: l,
                  top: 0,
                  width: r - l,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ended ? e.color.withAlpha(102) : e.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ));
              }
              final nowMin = now.hour * 60 + now.minute;
              if (isToday && nowMin >= _rs && nowMin <= _re) {
                blocks.add(Positioned(
                  left: fx(nowMin) - 1,
                  top: -4,
                  width: 2,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.now,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ));
              }
              return SizedBox(
                height: 14,
                child: Stack(clipBehavior: Clip.none, children: blocks),
              );
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final st = ts(context, 11, color: p.muted, height: 14 / 11);
              Widget at(double f, String t) => Positioned(
                    left: w * f,
                    top: 0,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, 0),
                      child: Text(t, style: st),
                    ),
                  );
              return SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: 0, top: 0, child: Text(tl('7시'), style: st)),
                    at(5 / 16, tl('12시')),
                    at(11 / 16, tl('18시')),
                    Positioned(right: 0, top: 0, child: Text(tl('23시'), style: st)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 지난 일정 접기 / 종일 일정

class _PastChip extends StatelessWidget {
  const _PastChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final open = store.pastOpen;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Tap(
            onTap: store.togglePast,
            child: Pill(
              height: 32,
              color: p.soft,
              padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: p.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    open ? tl('지난 일정 접기') : tl('지난 일정 {0}개', [count]),
                    style: ts(context, 12, weight: FontWeight.w600, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.events});

  final List<Ev> events;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in events)
              Opacity(
                opacity: StoreScope.of(context).tagMatch(e) ? 1 : 0.28,
                child: Tap(
                onTap: () => openDetail(context, e),
                child: Container(
                  height: 28,
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: evColors(e.color, p).tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          tl('종일 · {0}', [e.title]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, 12, weight: FontWeight.w600, color: evColors(e.color, p).text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 시간표

class _Placed {
  _Placed(this.e, this.s, this.t);

  final Ev e;
  final int s;
  final int t;
  int col = 0;
  int cols = 1;
}

/// 겹치는 일정끼리 묶어서 가로로 나란히 놓을 칸 번호를 정해요.
void _assignColumns(List<_Placed> items) {
  var i = 0;
  while (i < items.length) {
    var clusterEnd = items[i].t;
    var j = i + 1;
    while (j < items.length && items[j].s < clusterEnd) {
      clusterEnd = math.max(clusterEnd, items[j].t);
      j++;
    }
    final colEnds = <int>[];
    for (var k = i; k < j; k++) {
      final it = items[k];
      var col = -1;
      for (var c = 0; c < colEnds.length; c++) {
        if (colEnds[c] <= it.s) {
          col = c;
          break;
        }
      }
      if (col < 0) {
        colEnds.add(it.t);
        col = colEnds.length - 1;
      } else {
        colEnds[col] = it.t;
      }
      it.col = col;
    }
    for (var k = i; k < j; k++) {
      items[k].cols = colEnds.length;
    }
    i = j;
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.day});

  final DateTime day;

  static const double hourH = 46;
  static const double labelW = 48;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final today = store.today;
    final isToday = sameDay(day, today);
    final isPast = day.isBefore(today);
    final now = store.now;

    final timed = store.listedOn(day).where((e) => !e.allDay).toList();
    final folded = isToday && !store.pastOpen;
    final shown = folded ? timed.where((e) => e.end.isAfter(now)).toList() : timed;
    final foldedCount = timed.length - shown.length;

    if (isPast && timed.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(tl('이 날은 일정이 없었어요'), style: ts(context, 14, color: p.muted)),
        ),
      );
    }

    final placed = <_Placed>[];
    for (final e in shown) {
      final s = minOfDay(e.start, day);
      var t = minOfDay(e.end, day);
      if (t <= s) t = math.min(1440, s + 30);
      placed.add(_Placed(e, s, t));
    }
    placed.sort((a, b) {
      final c = a.s.compareTo(b.s);
      return c != 0 ? c : b.t.compareTo(a.t);
    });
    _assignColumns(placed);

    // 보여줄 시간 범위(시)
    var sh = 9;
    var eh = 22;
    for (final x in placed) {
      final tr = store.travelOf(x.e);
      sh = math.min(sh, math.max(0, x.s - tr.before) ~/ 60);
      eh = math.max(eh, (math.min(1440, x.t + tr.after) + 59) ~/ 60);
    }
    final cands = store.candidates.where((c) => sameDay(c.start, day)).toList();
    for (final c in cands) {
      sh = math.min(sh, minOfDay(c.start, day) ~/ 60);
      eh = math.max(eh, (minOfDay(c.end, day) + 59) ~/ 60);
    }
    if (isToday) {
      if (folded && foldedCount > 0) {
        var c = now.hour;
        for (final x in placed) {
          c = math.min(c, x.s ~/ 60);
        }
        sh = c;
      } else {
        sh = math.min(sh, now.hour);
      }
      eh = math.max(eh, math.min(24, now.hour + 1));
    }
    sh = math.max(0, math.min(23, sh));
    eh = math.max(sh + 1, math.min(24, eh));

    final gaps = isPast ? const <Span>[] : store.gaps(day, from: isToday ? ceilTo(now, 5) : null);

    // 강조할 일정: 진행 중이거나 다음 일정
    String? hiId;
    var badge = '';
    if (isToday) {
      for (final x in placed) {
        if (!x.e.start.isAfter(now) && x.e.end.isAfter(now)) {
          hiId = x.e.instanceId;
          badge = tl('진행 중');
          break;
        }
      }
      if (hiId == null) {
        for (final x in placed) {
          if (x.e.start.isAfter(now)) {
            hiId = x.e.instanceId;
            badge = tl('{0} 후', [leftText(math.max(1, x.e.start.difference(now).inMinutes))]);
            break;
          }
        }
      }
    }
    final highlightId = hiId;
    final highlightBadge = badge;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth - 32;
        final bodyW = w - labelW;
        final totalH = (eh - sh) * hourH + 16.0;
        double yOf(int min) => 8 + (min - sh * 60) / 60 * hourH;

        final nowMin = now.hour * 60 + now.minute;
        final nowY = yOf(nowMin);
        final showNow = isToday && nowMin >= sh * 60 && nowMin <= eh * 60;

        final children = <Widget>[];

        // 시각 줄과 글자
        for (var h = sh; h <= eh; h++) {
          final y = yOf(h * 60);
          children.add(Positioned(
            left: labelW,
            right: 0,
            top: y,
            height: 1,
            child: ColoredBox(color: p.line),
          ));
          final hide = showNow && (y - nowY).abs() < 11;
          if (!hide) {
            children.add(Positioned(
              left: 0,
              top: y - 7,
              child: Text(
                '${two(h % 24)}:00',
                style: ts(context, 11, color: p.muted, height: 14 / 11),
              ),
            ));
          }
        }

        // 비는 시간
        for (final g in gaps) {
          final gs = g.a.hour * 60 + g.a.minute;
          final ge = g.b.hour * 60 + g.b.minute;
          if (gs < sh * 60 || ge > eh * 60) continue;
          final full = (ge - gs) / 60 * hourH - 2;
          final hh = math.min(full, 112.0);
          if (hh < 20) continue;
          final from = ceilTo(g.a, 15);
          children.add(Positioned(
            left: labelW,
            right: 0,
            top: yOf(gs) + 1,
            height: hh,
            child: Tap(
              onTap: () => openQuickAdd(
                context,
                initialText: '${mdText(from)} ${timeWords(from.hour, from.minute)} ',
              ),
              child: DashedBox(
                radius: 12,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: p.muted),
                      const SizedBox(width: 6),
                      Text(
                        tl('비는 시간 {0}', [durText(g.length)]),
                        style: ts(context, 12, weight: FontWeight.w600, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ));
        }

        // 이동시간 (일정 앞뒤로 줄무늬 띠)
        for (final x in placed) {
          final tr = store.travelOf(x.e);
          if (tr.isNone) continue;
          final colW = bodyW / x.cols;
          final left = labelW + x.col * colW;
          final width = colW - (x.cols > 1 ? 2 : 0);
          if (tr.before > 0) {
            final b = math.max(0, x.s - tr.before);
            children.add(Positioned(
              left: left,
              top: yOf(b) + 1,
              width: width,
              height: math.max(10.0, (x.s - b) / 60 * hourH - 2),
              child: _TravelBand(event: x.e, text: tl('이동 {0}', [Travel.minText(tr.before)])),
            ));
          }
          if (tr.after > 0) {
            final a = math.min(1440, x.t + tr.after);
            children.add(Positioned(
              left: left,
              top: yOf(x.t) + 1,
              width: width,
              height: math.max(10.0, (a - x.t) / 60 * hourH - 2),
              child: _TravelBand(event: x.e, text: tl('이동 {0}', [Travel.minText(tr.after)])),
            ));
          }
        }

        // 일정 블록
        for (final x in placed) {
          final colW = bodyW / x.cols;
          final height = math.max(22.0, (x.t - x.s) / 60 * hourH - 2);
          children.add(Positioned(
            left: labelW + x.col * colW,
            top: yOf(x.s) + 1,
            width: colW - (x.cols > 1 ? 2 : 0),
            height: height,
            child: _Block(
              event: x.e,
              height: height,
              badge: (highlightId != null && highlightId == x.e.instanceId) ? highlightBadge : null,
            ),
          ));
        }

        // 후보 (아직 캘린더에 없는 점선 칸)
        for (final c in cands) {
          final cs = minOfDay(c.start, day);
          final ce = math.max(cs + 15, minOfDay(c.end, day));
          final h = math.max(26.0, (ce - cs) / 60 * hourH - 2);
          children.add(Positioned(
            left: labelW,
            right: 0,
            top: yOf(cs) + 1,
            height: h,
            child: _CandidateBlock(proposal: c, height: h),
          ));
        }

        // 지금 선
        if (showNow) {
          children.add(Positioned(
            left: labelW - 4,
            right: 0,
            top: nowY - 1,
            height: 2,
            child: ColoredBox(color: p.now),
          ));
          children.add(Positioned(
            left: labelW - 7,
            top: nowY - 4,
            child: Dot(p.now, size: 8),
          ));
          children.add(Positioned(
            left: 0,
            top: nowY - 9,
            child: Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: p.now,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hm(now),
                    style: ts(context, 11, weight: FontWeight.w600, color: p.nowFg),
                  ),
                ],
              ),
            ),
          ));
        }

        return SingleChildScrollView(
          key: ValueKey('${dayKey(day)}-${store.pastOpen}'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          child: SizedBox(
            height: totalH,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        );
      },
    );
  }
}

/// 후보: 초록 점선 칸. 누르면 후보에서 빠져요.
class _CandidateBlock extends StatelessWidget {
  const _CandidateBlock({required this.proposal, required this.height});

  final Proposal proposal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final p = Pal.of(context);
    final t = proposal.count > 1
        ? '${proposal.todo.title} ${proposal.index}/${proposal.count}'
        : proposal.todo.title;
    final tall = height >= 44;
    return Tap(
      onTap: () => store.removeCandidate(proposal),
      label: tl('후보 빼기'),
      child: Container(
        decoration: BoxDecoration(
          color: p.good.withAlpha(p.dark ? 40 : 28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          painter: _GoodDash(p.good),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: tall
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(context, 14, weight: FontWeight.w600, color: p.good, height: 18 / 14),
                            ),
                            Text(
                              tl('{0}–{1} · 눌러서 빼기', [hm(proposal.start), hm(proposal.end)]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(context, 12, color: p.good, height: 15 / 12),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 13, weight: FontWeight.w600, color: p.good, height: 16 / 13),
                          ),
                        ),
                ),
                Container(
                  height: 22,
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.good.withAlpha(40),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(tl('후보'), style: ts(context, 11, weight: FontWeight.w700, color: p.good)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoodDash extends CustomPainter {
  _GoodDash(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)).deflate(0.75);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_GoodDash old) => old.color != color;
}

/// 이동시간 띠: 일정 색의 연한 줄무늬
class _TravelBand extends StatelessWidget {
  const _TravelBand({required this.event, required this.text});

  final Ev event;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = evColors(event.color, p);
    return LayoutBuilder(
      builder: (context, box) {
        final show = box.maxHeight >= 20 && box.maxWidth >= 70;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: c.tint.withAlpha(p.dark ? 90 : 120),
            border: Border.all(color: c.tint),
          ),
          child: show
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car_outlined, size: 12, color: c.text),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 11, weight: FontWeight.w600, color: c.text, height: 14 / 11),
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.event, required this.height, this.badge});

  final Ev event;
  final double height;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = evColors(event.color, p);
    final hi = badge != null;
    final bg = hi ? c.solid : c.tint;
    final fg = hi ? c.onSolid : c.text;
    final tall = height >= 44;
    final store = StoreScope.of(context);
    final link = store.todoForEvent(event);
    final isDone = link?.slot.done ?? false;

    final loc = event.location;
    final sub = (loc != null && loc.trim().isNotEmpty)
        ? '${hm(event.start)}–${hm(event.end)} · ${loc.trim()}'
        : '${hm(event.start)}–${hm(event.end)}';

    final lineThrough = isDone ? TextDecoration.lineThrough : null;
    final Widget text = tall
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(context, 14, weight: FontWeight.w600, color: fg, height: 18 / 14)
                    .copyWith(decoration: lineThrough),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(context, 12, weight: FontWeight.w400, color: fg, height: 15 / 12),
              ),
            ],
          )
        : Text(
            event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(context, 13, weight: FontWeight.w600, color: fg, height: 16 / 13)
                .copyWith(decoration: lineThrough),
          );

    final match = store.tagMatch(event);
    return Opacity(
      opacity: match ? (isDone ? 0.55 : 1) : 0.28,
      child: Tap(
      onTap: () => openDetail(context, event),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            if (link != null)
              Tap(
                onTap: () => store.toggleSlotDone(event),
                label: isDone ? tl('끝냄 취소') : tl('끝냈어요'),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: fg,
                  ),
                ),
              ),
            Expanded(child: text),
            if (badge != null)
              Container(
                height: 22,
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: c.onSolid.withAlpha(p.dark ? 40 : 56),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badge!,
                      style: ts(context, 11, weight: FontWeight.w600, color: fg),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
