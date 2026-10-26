import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../repo.dart';
import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';
import 'day_view.dart';
import 'more_pages.dart';
import 'month_view.dart';
import 'nav.dart';
import 'permission_page.dart';
import 'project_pages.dart';
import 'quick_bar.dart';
import 'sheets.dart';
import 'tag_dialog.dart';
import 'week_view.dart';
import '../l10n.dart';

/// 앱의 첫 화면. 권한이 없으면 안내 화면, 있으면 월/주/일 화면.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    Widget body;
    if (!store.ready) {
      body = const SizedBox.shrink();
    } else if (store.perm != PermState.granted) {
      body = const PermissionPage();
    } else {
      body = const _Home();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(backgroundColor: p.bg, body: body),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void initState() {
    super.initState();
    // 처음 열었을 때 한 번만 사용 안내를 보여줘요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = StoreScope.read(context);
      if (!store.flags.welcomeSeen) showWelcomeSheet(context, first: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget content;
    if (store.view == ViewMode.month) {
      content = const MonthView();
    } else if (store.view == ViewMode.week) {
      content = const WeekView();
    } else {
      content = const DayView();
    }

    final undo = store.undo;
    final showUndo = undo != null && store.now.isBefore(undo.until);
    final hasCandidates = store.candidates.isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            const _Header(),
            const _Switcher(),
            const _PillRow(),
            if (store.view == ViewMode.month && store.currentProject != null)
              ProjectStrip(project: store.currentProject!),
            if (store.tagFilter != null) _TagFilterBar(tag: store.tagFilter!),
            Expanded(child: content),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: math.max(bottom, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showUndo && !hasCandidates) ...[
                _UndoBar(count: undo.eventIds.length),
                const SizedBox(height: 10),
              ],
              if (hasCandidates)
                const _CandidateCard()
              else
                QuickBar(onTap: () => openQuickAdd(context)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "일정 N개를 넣었어요 · 되돌리기"
class _UndoBar extends StatelessWidget {
  const _UndoBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final p = Pal.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 18, right: 6),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 20, color: p.bg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tl('일정 {0}개를 넣었어요', [count]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(context, 15, weight: FontWeight.w600, color: p.bg),
            ),
          ),
          Tap(
            onTap: store.undoLast,
            label: tl('되돌리기'),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(
                tl('되돌리기'),
                style: ts(context, 15, weight: FontWeight.w700, color: p.bg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 후보(점선)를 보고 있을 때 아래에 뜨는 카드
class _CandidateCard extends StatelessWidget {
  const _CandidateCard();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final n = store.candidates.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tl('이렇게 넣어볼까요?'), style: ts(context, 16, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            tl('점선 칸은 아직 캘린더에 없어요. 눌러서 빼도 돼요.'),
            style: ts(context, 13, color: p.muted, height: 18 / 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: BigButton(label: tl('후보 지우기'), quiet: true, onTap: store.clearCandidates),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: BigButton(label: tl('캘린더에 넣기 · {0}개', [n]), onTap: store.confirmCandidates),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;

    String small;
    String big;

    if (store.view == ViewMode.month) {
      small = '${yText(store.month.year)}';
      big = '${mText(store.month.month)}';
    } else if (store.view == ViewMode.week) {
      final a = weekStartSunday(store.selected);
      final b = addDays(a, 6);
      small = a.month == b.month
          ? '${ymText(a)}'
          : '${ymText(a)} – ${mText(b.month)}';
      big = '${dText(a.day)} – ${dText(b.day)}';
    } else {
      final d = store.selected;
      final h = store.holidayOn(d);
      small = h == null ? wdFull(d) : '${wdFull(d)} · $h';
      big = '${mdText(d)}';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, top + 4, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(context, 13, color: p.muted, height: 16 / 13),
                ),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          big,
                          maxLines: 1,
                          style: ts(context, 34, weight: FontWeight.w700, height: 40 / 34),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tap(
            onTap: () => openSearch(context),
            label: tl('검색'),
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.search_rounded, size: 24, color: p.ink),
            ),
          ),
          Tap(
            onTap: () => showMoreMenu(context),
            label: tl('더보기'),
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.more_horiz_rounded, size: 24, color: p.ink),
            ),
          ),
          Tap(
            onTap: store.goToday,
            child: SizedBox(
              height: 44,
              child: Center(
                child: Pill(
                  height: 34,
                  ring: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(tl('오늘'), style: ts(context, 14, weight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스위처 아래 "할 일 · 프로젝트 · 태그" 알약 줄
class _PillRow extends StatelessWidget {
  const _PillRow();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final todos = store.todos.where((t) => !t.done).length;
    final projects = store.projects.length;
    final tag = store.tagFilter;
    final tagCol = tag == null ? null : tagColor(tag, dark: p.dark);

    Widget pill(IconData icon, String text, VoidCallback onTap, String label, {Color? color}) {
      final c = color ?? p.ink;
      return Tap(
        onTap: onTap,
        label: label,
        child: Container(
          height: 34,
          padding: const EdgeInsets.only(left: 11, right: 13),
          decoration: BoxDecoration(
            color: color == null ? p.soft : Color.alphaBlend(color.withAlpha(44), p.surface),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c),
              const SizedBox(width: 6),
              Text(text, style: ts(context, 14, weight: FontWeight.w600, color: c)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          pill(
            Icons.checklist_rounded,
            todos > 0 ? tl('할 일 {0}', [todos]) : tl('할 일'),
            () => openTodos(context),
            tl('할 일'),
          ),
          const SizedBox(width: 8),
          pill(
            Icons.flag_outlined,
            projects > 0 ? tl('프로젝트 {0}', [projects]) : tl('프로젝트'),
            () => openProjects(context),
            tl('프로젝트'),
          ),
          const SizedBox(width: 8),
          pill(
            Icons.tag_rounded,
            tl('태그'),
            () => showTagFilterSheet(context),
            tl('태그로 보기'),
            color: tagCol,
          ),
        ],
      ),
    );
  }
}

/// 태그로 걸러보는 중일 때 나오는 줄 (누르면 전체 보기로 돌아가요)
class _TagFilterBar extends StatelessWidget {
  const _TagFilterBar({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final col = tagColor(tag, dark: p.dark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Tap(
            onTap: () => store.setTagFilter(null),
            label: tl('태그 걸러보기 끄기'),
            child: Container(
              height: 32,
              padding: const EdgeInsets.only(left: 12, right: 8),
              decoration: BoxDecoration(
                color: Color.alphaBlend(col.withAlpha(44), p.surface),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$tag',
                    style: ts(context, 14, weight: FontWeight.w600, color: col),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.close_rounded, size: 16, color: col),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tl('이 태그의 일정만 보는 중'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(context, 13, color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Switcher extends StatelessWidget {
  const _Switcher();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);

    Widget seg(String t, ViewMode m) {
      final on = store.view == m;
      return Expanded(
        child: Tap(
          onTap: () => store.setView(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: on
                  ? const [
                      BoxShadow(
                        color: Color(0x1A16161A),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              t,
              style: ts(context, 14, weight: FontWeight.w600, color: on ? p.ink : p.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          seg(tl('월'), ViewMode.month),
          const SizedBox(width: 2),
          seg(tl('주'), ViewMode.week),
          const SizedBox(width: 2),
          seg(tl('일'), ViewMode.day),
        ],
      ),
    );
  }
}
