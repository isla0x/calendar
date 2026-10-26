import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../projects.dart';
import '../skins.dart';
import '../store.dart';
import '../theme.dart';
import '../travel.dart';
import 'common.dart';
import 'nav.dart';
import 'sheets.dart';
import 'travel_sheet.dart';
import '../l10n.dart';

// ---------------------------------------------------------------- 도우미

Color _tint(Color c, Pal p, [int alpha = 56]) => Color.alphaBlend(c.withAlpha(alpha), p.surface);

String _md(DateTime d) => '${d.month}/${d.day}';

DateTime _mondayOf(DateTime d) => addDays(dayOnly(d), -(d.weekday - 1));


/// 위쪽 줄: 뒤로 가기 + 오른쪽 위젯
class _TopBar extends StatelessWidget {
  const _TopBar({required this.back, this.trailing});

  final String back;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Tap(
              onTap: () => Navigator.of(context).pop(),
              label: tl('뒤로'),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_left_rounded, size: 26, color: p.ink),
                    const SizedBox(width: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        back,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: ts(context, 14, weight: FontWeight.w600, color: p.bg),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14)});

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

/// 진행 바: 근무일 칸 또는 이어진 막대
class ProjectBar extends StatelessWidget {
  const ProjectBar({super.key, required this.project, required this.today, this.height = 14});

  final Project project;
  final DateTime today;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final pr = project;
    final total = pr.totalDays;
    final done = pr.dayNumber(today);
    final col = pr.color;
    final track = _tint(col, p, 40);
    if (total > 0 && total <= 31) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: i < done ? col : track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height / 2)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pr.progress(today),
        child: Container(
          decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(height / 2)),
        ),
      ),
    );
  }
}

String _stateLine(Project pr, DateTime today) {
  switch (pr.statusOn(today)) {
    case ProjectStatus.upcoming:
      return tl('{0}일 뒤 시작 · 근무일 {1}일', [daysBetween(dayOnly(today), pr.start), pr.totalDays]);
    case ProjectStatus.done:
      return tl('끝났어요 · 근무일 {0}일', [pr.totalDays]);
    case ProjectStatus.active:
      return tl('근무일 {0}일 중 {1}일째', [pr.totalDays, pr.dayNumber(today)]);
  }
}

// ---------------------------------------------------------------- 목록

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  ProjectStatus _tab = ProjectStatus.active;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final today = store.today;
    final all = store.projects;
    int count(ProjectStatus s) => all.where((x) => x.statusOn(today) == s).length;
    final shown = all.where((x) => x.statusOn(today) == _tab).toList()
      ..sort((a, b) => a.end.compareTo(b.end));

    Widget tab(String t, ProjectStatus s) {
      final on = _tab == s;
      return Expanded(
        child: Tap(
          onTap: () => setState(() => _tab = s),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$t ${count(s)}',
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
          _TopBar(
            back: tl('달력'),
            trailing: _SmallBtn(text: tl('+ 새 프로젝트'), onTap: () => showProjectForm(context)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('프로젝트', style: ts(context, 30, weight: FontWeight.w700, height: 38 / 30)),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                tab(tl('진행 중'), ProjectStatus.active),
                tab(tl('예정'), ProjectStatus.upcoming),
                tab(tl('끝남'), ProjectStatus.done),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        all.isEmpty
                            ? tl('아직 프로젝트가 없어요.\n새 일정을 쓸 때 "프로젝트로 보기"를 켜거나,\n위의 "+ 새 프로젝트"를 눌러 보세요.')
                            : tl('이 칸에는 프로젝트가 없어요.'),
                        textAlign: TextAlign.center,
                        style: ts(context, 14, color: p.muted, height: 21 / 14),
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    children: [
                      for (final pr in shown) ...[
                        _ProjectCard(project: pr, today: today),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.today});

  final Project project;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final pr = project;
    final next = pr.nextCheckpoint(today);
    final active = pr.statusOn(today) == ProjectStatus.active;
    return Tap(
      onTap: () => openProject(context, pr.id),
      child: _Box(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Dot(pr.color, size: 10),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pr.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(context, 17, weight: FontWeight.w700),
                  ),
                ),
                Text(
                  pr.dDayLabel(today),
                  style: ts(context, 15, weight: FontWeight.w700, color: p.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${pr.rangeText} · ${pr.timeLabel}',
              style: ts(context, 13, color: p.muted, height: 18 / 13),
            ),
            const SizedBox(height: 12),
            ProjectBar(project: pr, today: today),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(_stateLine(pr, today), style: ts(context, 13, color: p.muted)),
                ),
                if (active)
                  Text(tl('남은 {0}일', [pr.remainingDays(today)]), style: ts(context, 13, weight: FontWeight.w700)),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _tint(pr.color, p, 40),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(tl('다음 체크포인트'), style: ts(context, 12, color: p.muted)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${next.title} · ${_md(next.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 13, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'D-${daysBetween(dayOnly(today), next.date)}',
                      style: ts(context, 13, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 상세

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  Future<List<Ev>>? _future;
  String _futureKey = '';

  Future<List<Ev>> _events(CalendarStore store, Project pr) {
    final key = '${pr.eventIds.length}|${dayKey(pr.start)}|${dayKey(pr.end)}';
    if (_future == null || key != _futureKey) {
      _futureKey = key;
      _future = store.projectEvents(pr);
    }
    return _future!;
  }

  void _reload() => setState(() {
        _future = null;
        _futureKey = '';
      });

  Future<void> _addEvent(Project pr) async {
    await openQuickAdd(context, project: pr);
    if (mounted) _reload();
  }

  Future<void> _addCheckpoint(Project pr) async {
    final title = await showTextSheet(
      context,
      title: tl('체크포인트 이름'),
      hint: tl('예) 중간 보고'),
      icon: Icons.flag_outlined,
    );
    if (title == null || title.isEmpty || !mounted) return;
    final store = StoreScope.read(context);
    final d = await showDateSheet(
      context,
      initial: store.today.isBefore(pr.start) ? pr.start : (store.today.isAfter(pr.end) ? pr.end : store.today),
      first: pr.start,
      last: pr.end,
      title: tl('체크포인트 날짜'),
    );
    if (d == null) return;
    final cps = [...pr.checkpoints, Checkpoint(id: 'c${DateTime.now().microsecondsSinceEpoch}', title: title, date: d)]
      ..sort((a, b) => a.date.compareTo(b.date));
    await store.saveProject(pr.copyWith(checkpoints: cps));
  }

  Future<void> _toggleCp(Project pr, Checkpoint c) async {
    final store = StoreScope.read(context);
    await store.saveProject(
      pr.copyWith(checkpoints: [for (final x in pr.checkpoints) x.id == c.id ? x.copyWith(done: !x.done) : x]),
    );
  }

  Future<void> _removeCp(Project pr, Checkpoint c) async {
    final yes = await showConfirmSheet(
      context,
      title: tl('체크포인트를 지울까요?'),
      body: c.title,
      yes: tl('지우기'),
      danger: true,
    );
    if (!yes || !mounted) return;
    final store = StoreScope.read(context);
    await store.saveProject(
      pr.copyWith(checkpoints: pr.checkpoints.where((x) => x.id != c.id).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final pr = store.projectById(widget.projectId);
    if (pr == null) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Column(
          children: [
            const _TopBar(back: '프로젝트'),
            Expanded(
              child: Center(child: Text(tl('지워진 프로젝트예요'), style: ts(context, 15, color: p.muted))),
            ),
          ],
        ),
      );
    }
    final today = store.today;
    final status = pr.statusOn(today);
    final avg = store.avgFreeMinutes(pr);
    final cps = [...pr.checkpoints]..sort((a, b) => a.date.compareTo(b.date));
    final focusDay = status == ProjectStatus.active ? today : pr.start;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          _TopBar(
            back: '프로젝트',
            trailing: Tap(
              onTap: () => showProjectForm(context, project: pr),
              child: SizedBox(
                height: 44,
                child: Center(child: Text(tl('수정'), style: ts(context, 16, weight: FontWeight.w600))),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.name,
                        style: ts(context, 26, weight: FontWeight.w700, height: 34 / 26),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mdText(pr.start)} – ${mdText(pr.end)} · ${pr.timeLabel}',
                        style: ts(context, 13, color: p.muted, height: 18 / 13),
                      ),
                    ],
                  ),
                ),
                _Box(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Row(
                    children: [
                      _Ring(project: pr, today: today),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            _Stat(tl('남은 근무일'), status == ProjectStatus.done ? tl('없음') : tl('{0}일', [pr.remainingDays(today)])),
                            const SizedBox(height: 10),
                            _Stat(tl('끝나는 날'), '${pr.end.month}/${pr.end.day} ${wd(pr.end)}'),
                            const SizedBox(height: 10),
                            _Stat(
                              tl('하루 여유'),
                              status == ProjectStatus.done ? '-' : tl('약 {0}시간', [(avg / 60).toStringAsFixed(avg % 60 == 0 ? 0 : 1)]),
                              color: p.good,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Box(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(tl('체크포인트'), style: ts(context, 15, weight: FontWeight.w700))),
                          Tap(
                            onTap: () => _addCheckpoint(pr),
                            child: Text(
                              tl('+ 추가'),
                              style: ts(context, 14, weight: FontWeight.w600, color: p.blue),
                            ),
                          ),
                        ],
                      ),
                      if (cps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            tl('중간 보고, 마감처럼 챙길 날을 적어 두세요.'),
                            style: ts(context, 13, color: p.muted),
                          ),
                        ),
                      for (final c in cps)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleCp(pr, c),
                          onLongPress: () => _removeCp(pr, c),
                          child: SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: c.done ? pr.color : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: c.done ? null : Border.all(color: pr.color, width: 2),
                                  ),
                                  child: c.done
                                      ? Icon(Icons.check_rounded, size: 14, color: p.bg)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ts(
                                      context,
                                      14,
                                      weight: c.done ? FontWeight.w500 : FontWeight.w600,
                                      color: c.done ? p.muted : p.ink,
                                    ).copyWith(
                                      decoration: c.done ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  c.done || c.date.isBefore(today)
                                      ? _md(c.date)
                                      : '${_md(c.date)} · D-${daysBetween(dayOnly(today), c.date)}',
                                  style: ts(
                                    context,
                                    13,
                                    weight: c.done ? FontWeight.w500 : FontWeight.w700,
                                    color: c.done ? p.muted : p.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (cps.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(tl('눌러서 완료 표시 · 길게 누르면 지워요'), style: ts(context, 12, color: p.muted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Ev>>(
                  future: _events(store, pr),
                  builder: (context, snap) {
                    final evs = snap.data ?? const <Ev>[];
                    return Column(
                      children: [
                        _WeekHours(project: pr, events: evs),
                        const SizedBox(height: 12),
                        _TodayBox(
                          project: pr,
                          events: evs,
                          day: focusDay,
                          label: status == ProjectStatus.active ? tl('이 프로젝트의 오늘 일정') : tl('이 프로젝트의 첫날 일정'),
                          onAdd: () => _addEvent(pr),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BigButton(
                        label: tl('날짜별로 보기'),
                        quiet: true,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => ProjectDaysPage(projectId: pr.id)),
                          );
                          if (mounted) _reload();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BigButton(
                        label: tl('있던 일정 넣기'),
                        quiet: true,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => ProjectLinkPage(projectId: pr.id)),
                          );
                          if (mounted) _reload();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: ts(context, 14, color: p.muted)),
        Text(value, style: ts(context, 14, weight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.project, required this.today});

  final Project project;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final st = project.statusOn(today);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: project.progress(today),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: _tint(project.color, p, 50),
              valueColor: AlwaysStoppedAnimation<Color>(project.color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                st == ProjectStatus.done ? tl('끝') : project.dDayLabel(today),
                style: ts(context, 24, weight: FontWeight.w700, height: 30 / 24),
              ),
              Text(
                st == ProjectStatus.active
                    ? tl('{0}일째', [project.dayNumber(today)])
                    : (st == ProjectStatus.upcoming ? tl('시작 전') : tl('마무리')),
                style: ts(context, 12, color: p.muted, height: 16 / 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekHours extends StatelessWidget {
  const _WeekHours({required this.project, required this.events});

  final Project project;
  final List<Ev> events;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final pr = project;
    final mins = <int, int>{};
    for (final e in events) {
      if (e.allDay) continue;
      final k = dayKey(_mondayOf(e.start));
      mins[k] = (mins[k] ?? 0) + e.duration.inMinutes;
    }
    final weeks = <DateTime>[];
    var w = _mondayOf(pr.start);
    while (!w.isAfter(pr.end) && weeks.length < 30) {
      weeks.add(w);
      w = addDays(w, 7);
    }
    var maxM = 1;
    for (final v in mins.values) {
      if (v > maxM) maxM = v;
    }
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tl('주별 일정 시간'), style: ts(context, 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (mins.isEmpty)
            Text(tl('일정을 넣으면 주마다 몇 시간인지 보여요.'), style: ts(context, 13, color: p.muted))
          else
            for (final wk in weeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(tl('{0} 주', [_md(wk)]), style: ts(context, 13, color: p.muted)),
                    ),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: p.soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ((mins[dayKey(wk)] ?? 0) / maxM).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: pr.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(
                        _hoursText(mins[dayKey(wk)] ?? 0),
                        textAlign: TextAlign.right,
                        style: ts(context, 13, weight: FontWeight.w700),
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

String _hoursText(int m) {
  if (m % 60 == 0) return '${m ~/ 60}h';
  return '${(m / 60).toStringAsFixed(1)}h';
}

bool _onDay(Ev e, DateTime d) => !d.isBefore(e.firstDay) && !d.isAfter(e.lastDay);

class _TodayBox extends StatelessWidget {
  const _TodayBox({
    required this.project,
    required this.events,
    required this.day,
    required this.label,
    required this.onAdd,
  });

  final Project project;
  final List<Ev> events;
  final DateTime day;
  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = events.where((e) => _onDay(e, day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: ts(context, 15, weight: FontWeight.w700))),
              _SmallBtn(text: tl('+ 일정 추가'), onTap: onAdd),
            ],
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tl('이 날은 아직 일정이 없어요.'), style: ts(context, 13, color: p.muted)),
            ),
          for (final e in list)
            Tap(
              onTap: () => openDetail(context, e),
              child: SizedBox(
                height: 38,
                child: Row(
                  children: [
                    Dot(e.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 14, weight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      e.allDay ? tl('종일') : '${hm(e.start)} – ${hm(e.end)}',
                      style: ts(context, 13, color: p.muted),
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

// ---------------------------------------------------------------- 날짜별 모아보기

class ProjectDaysPage extends StatefulWidget {
  const ProjectDaysPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDaysPage> createState() => _ProjectDaysPageState();
}

class _ProjectDaysPageState extends State<ProjectDaysPage> {
  bool _byDay = true;
  DateTime? _day;
  Future<List<Ev>>? _future;
  String _futureKey = '';

  Future<List<Ev>> _events(CalendarStore store, Project pr) {
    final key = '${pr.eventIds.length}|${dayKey(pr.start)}|${dayKey(pr.end)}';
    if (_future == null || key != _futureKey) {
      _futureKey = key;
      _future = store.projectEvents(pr);
    }
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final pr = store.projectById(widget.projectId);
    if (pr == null) {
      return Scaffold(backgroundColor: p.bg, body: const _TopBar(back: '프로젝트'));
    }
    final today = store.today;
    final days = <DateTime>[];
    var d = pr.start;
    while (!d.isAfter(pr.end) && days.length < 200) {
      days.add(d);
      d = addDays(d, 1);
    }
    final sel = _day ?? (pr.contains(today) ? dayOnly(today) : pr.start);
    final cpDays = {for (final c in pr.checkpoints) dayKey(c.date)};

    return Scaffold(
      backgroundColor: p.bg,
      body: FutureBuilder<List<Ev>>(
        future: _events(store, pr),
        builder: (context, snap) {
          final evs = snap.data ?? const <Ev>[];
          final dayEvs = evs.where((e) => _onDay(e, sel)).toList()
            ..sort((a, b) => a.start.compareTo(b.start));
          Widget seg(String t, bool on, VoidCallback f) => Expanded(
                child: Tap(
                  onTap: f,
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
          return Column(
            children: [
              _TopBar(
                back: pr.name,
                trailing: _SmallBtn(
                  text: tl('+ 일정 추가'),
                  onTap: () async {
                    await openQuickAdd(context, project: pr);
                    if (mounted) {
                      setState(() {
                        _future = null;
                        _futureKey = '';
                      });
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tl('프로젝트 일정'), style: ts(context, 26, weight: FontWeight.w700, height: 34 / 26)),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    seg(tl('날짜별'), _byDay, () => setState(() => _byDay = true)),
                    seg(tl('전체 목록 {0}', [evs.length]), !_byDay, () => setState(() => _byDay = false)),
                  ],
                ),
              ),
              if (_byDay) ...[
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    itemCount: days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final x = days[i];
                      final on = sameDay(x, sel);
                      final rest = pr.isRestDay(x);
                      final n = evs.where((e) => _onDay(e, x)).length;
                      final isCp = cpDays.contains(dayKey(x));
                      return Tap(
                        onTap: () => setState(() => _day = x),
                        child: Opacity(
                          opacity: rest && !on ? 0.65 : 1,
                          child: Container(
                            width: 46,
                            decoration: BoxDecoration(
                              color: on ? p.ink : (isCp ? _tint(pr.color, p, 70) : (rest ? p.soft : p.surface)),
                              borderRadius: BorderRadius.circular(16),
                              border: on || isCp || rest ? null : Border.all(color: p.line),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  wd(x),
                                  style: ts(context, 12, color: on ? p.bg : p.muted, height: 16 / 12),
                                ),
                                Text(
                                  '${x.day}',
                                  style: ts(
                                    context,
                                    17,
                                    weight: FontWeight.w700,
                                    color: on ? p.bg : p.ink,
                                    height: 22 / 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (rest)
                                  Text(tl('쉼'), style: ts(context, 10, color: on ? p.bg : p.muted, height: 12 / 10))
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var k = 0; k < (n > 3 ? 3 : n); k++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 1),
                                          child: Dot(on ? p.bg : pr.color, size: 5),
                                        ),
                                      if (n == 0) const SizedBox(height: 5),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '${dateFull(sel)}',
                          style: ts(context, 18, weight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        pr.isRestDay(sel) ? tl('쉬는 날') : tl('일정 {0}개', [dayEvs.length]),
                        style: ts(context, 13, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 24),
                    children: [
                      if (dayEvs.isNotEmpty)
                        _EventList(events: dayEvs, project: pr)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              tl('이 날은 프로젝트 일정이 없어요.'),
                              style: ts(context, 14, color: p.muted),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _FreeLine(day: sel),
                    ],
                  ),
                ),
              ] else
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 24),
                    children: [
                      if (evs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(tl('아직 넣은 일정이 없어요.'), style: ts(context, 14, color: p.muted)),
                          ),
                        )
                      else
                        _EventList(events: evs, project: pr, withDate: true),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.project, this.withDate = false});

  final List<Ev> events;
  final Project project;
  final bool withDate;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cpTitles = {for (final c in project.checkpoints) dayKey(c.date): c.title};
    return _Box(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            Tap(
              onTap: () => openDetail(context, events[i]),
              child: Container(
                constraints: const BoxConstraints(minHeight: 62),
                decoration: BoxDecoration(
                  border: i == events.length - 1 ? null : Border(bottom: BorderSide(color: p.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: events[i].color,
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
                            events[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 15, weight: FontWeight.w600, height: 20 / 15),
                          ),
                          Text(
                            '${withDate ? '${events[i].start.month}/${events[i].start.day} ${wd(events[i].start)} · ' : ''}'
                            '${events[i].allDay ? '종일' : '${hm(events[i].start)} – ${hm(events[i].end)} · ${durText(events[i].duration)}'}',
                            style: ts(context, 13, color: p.muted, height: 18 / 13),
                          ),
                        ],
                      ),
                    ),
                    if (cpTitles.containsKey(dayKey(events[i].firstDay)))
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tint(project.color, p, 70),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(tl('체크포인트'), style: ts(context, 12, weight: FontWeight.w700)),
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

class _FreeLine extends StatelessWidget {
  const _FreeLine({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final gaps = store.gaps(day, min: const Duration(minutes: 60));
    final free = store.freeMinutes(day);
    if (gaps.isEmpty || free < 60) return const SizedBox.shrink();
    final first = gaps.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.good.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.good.withAlpha(120)),
      ),
      child: Text(
        tl('이 날 비는 시간 {0} · {1} – {2}{3}', [durText(Duration(minutes: free)), hm(first.a), hm(first.b), gaps.length > 1 ? tl(' 외') : '']),
        style: ts(context, 14, weight: FontWeight.w700, color: p.good),
      ),
    );
  }
}

// ---------------------------------------------------------------- 있던 일정 넣기

class ProjectLinkPage extends StatefulWidget {
  const ProjectLinkPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectLinkPage> createState() => _ProjectLinkPageState();
}

class _ProjectLinkPageState extends State<ProjectLinkPage> {
  List<Ev>? _list;
  final Set<String> _picked = <String>{};
  bool _init = false;

  bool _looksProject(Project pr, Ev e) {
    final t = e.title;
    final n = pr.name.replaceAll(' ', '');
    return t.contains('프로젝트') ||
        t.contains('보고') ||
        (n.length >= 2 && t.replaceAll(' ', '').contains(n));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final store = StoreScope.read(context);
    final pr = store.projectById(widget.projectId);
    if (pr == null) return;
    store.unlinkedEventsIn(pr).then((v) {
      if (!mounted) return;
      setState(() {
        _list = v;
        for (final e in v) {
          if (_looksProject(pr, e)) _picked.add(e.id);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final pr = store.projectById(widget.projectId);
    final list = _list;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          _TopBar(back: tl('닫기')),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tl('이미 있는 일정도\n프로젝트에 넣을 수 있어요'),
                style: ts(context, 24, weight: FontWeight.w700, height: 32 / 24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                pr == null
                    ? ''
                    : tl('{0} 기간({1} – {2})에 있고, 어디에도 안 들어간 일정', [pr.name, _md(pr.start), _md(pr.end)]),
                style: ts(context, 13, weight: FontWeight.w600, color: p.muted, height: 18 / 13),
              ),
            ),
          ),
          Expanded(
            child: list == null
                ? const SizedBox.shrink()
                : (list.isEmpty
                    ? Center(
                        child: Text(tl('넣을 수 있는 일정이 없어요.'), style: ts(context, 14, color: p.muted)),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        children: [
                          _Box(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Column(
                              children: [
                                for (var i = 0; i < list.length; i++)
                                  Tap(
                                    onTap: () => setState(() {
                                      if (!_picked.add(list[i].id)) _picked.remove(list[i].id);
                                    }),
                                    child: Container(
                                      constraints: const BoxConstraints(minHeight: 62),
                                      decoration: BoxDecoration(
                                        border: i == list.length - 1
                                            ? null
                                            : Border(bottom: BorderSide(color: p.line)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: _picked.contains(list[i].id) ? p.ink : Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: _picked.contains(list[i].id)
                                                  ? null
                                                  : Border.all(color: p.dash, width: 2),
                                            ),
                                            child: _picked.contains(list[i].id)
                                                ? Icon(Icons.check_rounded, size: 15, color: p.bg)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  list[i].title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: ts(context, 15, weight: FontWeight.w600, height: 20 / 15),
                                                ),
                                                Text(
                                                  '${list[i].start.month}/${list[i].start.day} ${wd(list[i].start)} · '
                                                  '${list[i].allDay ? '종일' : '${hm(list[i].start)} – ${hm(list[i].end)}'}'
                                                  '${list[i].recurring ? ' · 반복' : ''}',
                                                  style: ts(context, 13, color: p.muted, height: 18 / 13),
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
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                            child: Text(
                              tl('제목에 "프로젝트", "보고" 같은 말이 있으면 미리 체크해 둬요.'),
                              style: ts(context, 13, color: p.muted, height: 19 / 13),
                            ),
                          ),
                        ],
                      )),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tl('태그와는 별개예요 · 태그를 지워도 프로젝트에는 남아요'),
                  style: ts(context, 13, color: p.muted),
                ),
                const SizedBox(height: 10),
                BigButton(
                  label: tl('{0}개 넣기', [_picked.length]),
                  onTap: _picked.isEmpty || pr == null
                      ? null
                      : () async {
                          await store.addEventIdsToProject(pr.id, _picked);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 새 프로젝트 · 수정

Future<void> showProjectForm(BuildContext context, {Project? project}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => _ProjectForm(project: project),
  );
}

class _ProjectForm extends StatefulWidget {
  const _ProjectForm({this.project});

  final Project? project;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final TextEditingController _name = TextEditingController(text: widget.project?.name ?? '');
  late DateTime _start;
  late DateTime _end;
  late Set<int> _rest;
  late Color _color;

  /// 달력에도 매일 일정을 만들지 (새 프로젝트일 때만) 와 그 시간
  bool _withEvents = false;
  int _fromMin = 9 * 60;
  int _toMin = 18 * 60;
  Travel _travel = Travel.none;

  @override
  void initState() {
    super.initState();
    final pr = widget.project;
    final t = dayOnly(DateTime.now());
    _start = pr?.start ?? t;
    _end = pr?.end ?? addDays(t, 13);
    _rest = Set<int>.of(pr?.rest ?? const <int>{6, 7});
    _color = pr?.color ?? Skin.palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDateSheet(context, initial: _start, title: tl('시작하는 날'));
    if (d == null) return;
    setState(() {
      _start = d;
      if (_end.isBefore(d)) _end = d;
    });
  }

  Future<void> _pickEnd() async {
    final d = await showDateSheet(context, initial: _end, first: _start, title: tl('끝나는 날'));
    if (d == null) return;
    setState(() => _end = d);
  }

  String _tm(int m) => '${two(m ~/ 60)}:${two(m % 60)}';

  Future<void> _pickTime(bool from) async {
    final base = DateTime(2000, 1, 1, (from ? _fromMin : _toMin) ~/ 60, (from ? _fromMin : _toMin) % 60);
    final r = await showTimeSheet(context, initial: base, title: from ? tl('시작 시각') : tl('끝나는 시각'));
    if (r == null) return;
    setState(() {
      final m = r.hour * 60 + r.minute;
      if (from) {
        _fromMin = m;
        if (_toMin <= m) _toMin = math.min(1439, m + 60);
      } else {
        _toMin = m > _fromMin ? m : math.min(1439, _fromMin + 30);
      }
    });
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final old = widget.project;
    final Project pr;
    if (old == null) {
      pr = Project(
        id: store.newProjectId(),
        name: name,
        start: _start,
        end: _end,
        colorValue: _color.toARGB32(),
        rest: _rest,
        cells: true,
      );
      if (_withEvents) {
        // 달력 입력으로 만든 프로젝트와 똑같이: 쉬는 요일을 뺀 매일 반복 일정을 만들어요.
        var first = _start;
        var guard = 0;
        while (_rest.contains(first.weekday) && guard < 7) {
          first = addDays(first, 1);
          guard++;
        }
        final Repeat repeat;
        if (_rest.isEmpty) {
          repeat = Repeat(RepeatKind.daily, until: _end);
        } else if (_rest.length == 2 && _rest.contains(6) && _rest.contains(7)) {
          repeat = Repeat(RepeatKind.weekdays, until: _end);
        } else {
          repeat = Repeat(
            RepeatKind.days,
            until: _end,
            days: {for (var i = 1; i <= 7; i++) if (!_rest.contains(i)) i},
          );
        }
        final s0 = DateTime(first.year, first.month, first.day, _fromMin ~/ 60, _fromMin % 60);
        final e0 = DateTime(first.year, first.month, first.day, _toMin ~/ 60, _toMin % 60);
        final ok = await store.addEvent(
          title: name,
          start: s0,
          end: e0,
          repeat: repeat,
          color: _color,
        );
        final id = store.lastCreatedId;
        if (ok && id != null) {
          if (!_travel.isNone) await store.setTravelById(id, _travel);
          final prefix = _rest.isEmpty
              ? '매일 '
              : (_rest.length == 2 && _rest.contains(6) && _rest.contains(7) ? '평일 ' : '');
          await store.saveProject(
            pr.copyWith(eventIds: {id}, timeText: '$prefix${_tm(_fromMin)} – ${_tm(_toMin)}'),
          );
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
    } else {
      pr = old.copyWith(
        name: name,
        start: _start,
        end: _end,
        colorValue: _color.toARGB32(),
        rest: _rest,
        cells: true,
      );
    }
    await store.saveProject(pr);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final old = widget.project;
    if (old == null) return;
    final yes = await showConfirmSheet(
      context,
      title: tl('프로젝트를 지울까요?'),
      body: tl('일정은 그대로 남고, 프로젝트 묶음만 없어져요.'),
      yes: tl('지우기'),
      danger: true,
    );
    if (!yes || !mounted) return;
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    await store.deleteProject(old.id);
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.project != null;
    final total = Project(
      id: 'x',
      name: 'x',
      start: _start,
      end: _end,
      colorValue: 0,
      rest: _rest,
    ).totalDays;
    return SheetFrame(
      title: editing ? tl('프로젝트 고치기') : tl('새 프로젝트'),
      subtitle: tl('기간을 정하면 진행 바와 D-day 를 보여줘요.'),
      footer: Row(
        children: [
          if (editing) ...[
            Expanded(
              flex: 2,
              child: BigButton(label: tl('지우기'), quiet: true, color: p.red, onTap: _delete),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 3,
            child: BigButton(label: tl('저장'), onTap: _name.text.trim().isEmpty ? null : _save),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(27)),
            child: TextField(
              controller: _name,
              autofocus: !editing,
              onChanged: (_) => setState(() {}),
              cursorColor: p.ink,
              style: ts(context, 16, weight: FontWeight.w600),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: tl('프로젝트 이름'),
                hintStyle: ts(context, 16, color: p.dash),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DatePill(label: tl('시작'), date: _start, onTap: _pickStart),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DatePill(label: tl('끝'), date: _end, onTap: _pickEnd),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tl('쉬는 요일'), style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
          const SizedBox(height: 8),
          RestDayChips(
            rest: _rest,
            onChanged: (v) => setState(() => _rest = v),
          ),
          const SizedBox(height: 6),
          Text(tl('근무일 {0}일', [total]), style: ts(context, 13, color: p.muted)),
          if (!editing) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(tl('달력에도 매일 일정 넣기'), style: ts(context, 14, weight: FontWeight.w700)),
                ),
                AppSwitch(
                  value: _withEvents,
                  onChanged: (v) => setState(() => _withEvents = v),
                  label: tl('달력에도 매일 일정 넣기'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _withEvents
                  ? tl('근무일마다 같은 시간에 일정이 하나씩 생겨요.')
                  : tl('끄면 진행 카드만 만들고, 일정은 나중에 직접 넣어요.'),
              style: ts(context, 13, color: p.muted),
            ),
            if (_withEvents) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Tap(
                      onTap: () => _pickTime(true),
                      label: tl('시작 시각'),
                      child: _TimePill(label: tl('시작'), text: _tm(_fromMin)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tap(
                      onTap: () => _pickTime(false),
                      label: tl('끝나는 시각'),
                      child: _TimePill(label: tl('끝'), text: _tm(_toMin)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Tap(
                onTap: () async {
                  final r = await showTravelSheet(context, initial: _travel);
                  if (r != null && mounted) setState(() => _travel = r);
                },
                label: tl('이동시간'),
                child: _TimePill(label: tl('이동'), text: _travel.isNone ? tl('없음') : _travel.shortLabel),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in Skin.palette)
                Tap(
                  onTap: () => setState(() => _color = c),
                  label: tl('프로젝트 색'),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.toARGB32() == _color.toARGB32() ? p.ink : p.line,
                        width: c.toARGB32() == _color.toARGB32() ? 2.5 : 1,
                      ),
                    ),
                    child: c.toARGB32() == _color.toARGB32()
                        ? Icon(Icons.check_rounded, size: 18, color: p.ink)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Text(label, style: ts(context, 13, color: p.muted)),
          const Spacer(),
          Text(text, style: ts(context, 15, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Text(label, style: ts(context, 13, color: p.muted)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${dateChip(date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(context, 15, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 쉬는 요일 고르기 (칠한 요일이 쉬는 날)
class RestDayChips extends StatelessWidget {
  const RestDayChips({super.key, required this.rest, required this.onChanged});

  final Set<int> rest;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        for (var i = 1; i <= 7; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: Tap(
              onTap: () {
                final next = Set<int>.of(rest);
                if (!next.add(i)) next.remove(i);
                // 일주일 전부 쉬면 일정이 하나도 안 생겨서, 하루는 남겨 둬요.
                if (next.length >= 7) return;
                onChanged(next);
              },
              label: tl('{0} {1}', [wdHeadFull(i), rest.contains(i) ? tl('쉼') : tl('근무')]),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rest.contains(i) ? p.soft : p.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  wdHead(i),
                  style: ts(
                    context,
                    14,
                    weight: FontWeight.w700,
                    color: rest.contains(i) ? p.muted : p.bg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 일정 쓸 때 "프로젝트로 보기"

/// 프로젝트로 보기를 켤 때 고르는 것들
class ProjectDraft {
  const ProjectDraft({required this.rest, required this.checkpoints});

  final Set<int> rest;

  /// 체크포인트 (이름 → 날짜)
  final List<Checkpoint> checkpoints;
}

Future<ProjectDraft?> showProjectOptionsSheet(
  BuildContext context, {
  required String name,
  required DateTime start,
  required DateTime end,
  ProjectDraft? initial,
}) {
  return showAppSheet<ProjectDraft>(
    context: context,
    builder: (_) => _OptionsSheet(name: name, start: start, end: end, initial: initial),
  );
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.name, required this.start, required this.end, this.initial});

  final String name;
  final DateTime start;
  final DateTime end;
  final ProjectDraft? initial;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late Set<int> _rest = Set<int>.of(widget.initial?.rest ?? const <int>{6, 7});
  late bool _kick = widget.initial?.checkpoints.any((c) => c.title == tl('착수')) ?? false;
  late bool _mid = widget.initial?.checkpoints.any((c) => c.title == tl('중간 보고')) ?? true;
  late bool _fin = widget.initial?.checkpoints.any((c) => c.title == tl('최종 보고')) ?? true;

  Project get _tmp => Project(
        id: 'x',
        name: widget.name,
        start: widget.start,
        end: widget.end,
        colorValue: 0,
        rest: _rest,
      );

  DateTime _midDay() {
    final days = _tmp.workDays;
    if (days.isEmpty) return widget.start;
    return days[days.length ~/ 2];
  }

  DateTime _lastWorkDay() {
    final days = _tmp.workDays;
    return days.isEmpty ? widget.end : days.last;
  }

  DateTime _firstWorkDay() {
    final days = _tmp.workDays;
    return days.isEmpty ? widget.start : days.first;
  }

  ProjectDraft _result() {
    final cps = <Checkpoint>[
      if (_kick) Checkpoint(id: 'k${widget.start.microsecondsSinceEpoch}', title: tl('착수'), date: _firstWorkDay()),
      if (_mid) Checkpoint(id: 'm${widget.start.microsecondsSinceEpoch}', title: tl('중간 보고'), date: _midDay()),
      if (_fin) Checkpoint(id: 'f${widget.start.microsecondsSinceEpoch}', title: tl('최종 보고'), date: _lastWorkDay()),
    ];
    return ProjectDraft(rest: _rest, checkpoints: cps);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget chip(String t, bool on, VoidCallback f) => Tap(
          onTap: f,
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
              t,
              style: ts(context, 14, weight: FontWeight.w600, color: on ? p.bg : p.ink),
            ),
          ),
        );
    return SheetFrame(
      title: tl('프로젝트로 보기'),
      subtitle: tl('진행 바 · D-day 를 보여줘요.'),
      footer: BigButton(label: tl('완료'), onTap: () => Navigator.of(context).pop(_result())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tl('쉬는 요일'), style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
          const SizedBox(height: 8),
          RestDayChips(rest: _rest, onChanged: (v) => setState(() => _rest = v)),
          const SizedBox(height: 6),
          Text(
            tl('검게 칠한 요일에만 일정이 생겨요 · 근무일 {0}일', [_tmp.totalDays]),
            style: ts(context, 13, color: p.muted),
          ),
          const SizedBox(height: 18),
          Text(tl('체크포인트'), style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(tl('착수 · {0}', [_md(_firstWorkDay())]), _kick, () => setState(() => _kick = !_kick)),
              chip(tl('중간 보고 · {0}', [_md(_midDay())]), _mid, () => setState(() => _mid = !_mid)),
              chip(tl('최종 보고 · {0}', [_md(_lastWorkDay())]), _fin, () => setState(() => _fin = !_fin)),
            ],
          ),
          const SizedBox(height: 4),
          Text(tl('날짜와 이름은 나중에 프로젝트 화면에서 고칠 수 있어요.'), style: ts(context, 12, color: p.muted)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 월 화면 위 한 줄 띠

class ProjectStrip extends StatelessWidget {
  const ProjectStrip({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final today = store.today;
    final pr = project;
    return Tap(
      onTap: () => openProject(context, pr.id),
      label: '${pr.name} ${pr.dDayLabel(today)}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _tint(pr.color, p, 44),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Dot(pr.color, size: 8),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                pr.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(context, 14, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 72, child: ProjectBar(project: pr, today: today, height: 8)),
            const Spacer(),
            Text(pr.dDayLabel(today), style: ts(context, 14, weight: FontWeight.w700)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
          ],
        ),
      ),
    );
  }
}
