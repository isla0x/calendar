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
import 'month_view.dart';
import 'nav.dart';
import 'permission_page.dart';
import 'project_pages.dart';
import 'quick_bar.dart';
import 'tag_dialog.dart';
import 'week_view.dart';

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

class _Home extends StatelessWidget {
  const _Home();

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

    return Stack(
      children: [
        Column(
          children: [
            const _Header(),
            const _Switcher(),
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
          child: QuickBar(onTap: () => openQuickAdd(context)),
        ),
      ],
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
      small = '${store.month.year}년';
      big = '${store.month.month}월';
    } else if (store.view == ViewMode.week) {
      final a = weekStartSunday(store.selected);
      final b = addDays(a, 6);
      small = a.month == b.month
          ? '${a.year}년 ${a.month}월'
          : '${a.year}년 ${a.month}월 – ${b.month}월';
      big = '${a.day}일 – ${b.day}일';
    } else {
      final d = store.selected;
      final h = store.holidayOn(d);
      small = h == null ? wdFull(d) : '${wdFull(d)} · $h';
      big = '${d.month}월 ${d.day}일';
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
            onTap: () => openTodos(context),
            label: '할 일',
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.checklist_rounded, size: 24, color: p.ink),
            ),
          ),
          Tap(
            onTap: () => openProjects(context),
            label: '프로젝트',
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.flag_outlined, size: 24, color: p.ink),
            ),
          ),
          Tap(
            onTap: () => showTagFilterSheet(context),
            label: '태그로 보기',
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(
                Icons.tag_rounded,
                size: 24,
                color: store.tagFilter != null ? tagColor(store.tagFilter!, dark: p.dark) : p.ink,
              ),
            ),
          ),
          Tap(
            onTap: () => openSearch(context),
            label: '검색',
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.search_rounded, size: 24, color: p.ink),
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
                  child: Text('오늘', style: ts(context, 14, weight: FontWeight.w600)),
                ),
              ),
            ),
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
            label: '태그 걸러보기 끄기',
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
              '이 태그의 일정만 보는 중',
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
          seg('월', ViewMode.month),
          const SizedBox(width: 2),
          seg('주', ViewMode.week),
          const SizedBox(width: 2),
          seg('일', ViewMode.day),
        ],
      ),
    );
  }
}
