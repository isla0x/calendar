import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../repo.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'day_view.dart';
import 'month_view.dart';
import 'nav.dart';
import 'permission_page.dart';
import 'quick_bar.dart';
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
    String prevLabel;
    String nextLabel;
    void shift(int d) {
      if (store.view == ViewMode.month) {
        store.shiftMonth(d);
      } else if (store.view == ViewMode.week) {
        store.shiftWeek(d);
      } else {
        store.shiftDay(d);
      }
    }

    if (store.view == ViewMode.month) {
      prevLabel = '이전 달';
      nextLabel = '다음 달';
      small = '${store.month.year}년';
      big = '${store.month.month}월';
    } else if (store.view == ViewMode.week) {
      prevLabel = '이전 주';
      nextLabel = '다음 주';
      final a = weekStartSunday(store.selected);
      final b = addDays(a, 6);
      small = a.month == b.month
          ? '${a.year}년 ${a.month}월'
          : '${a.year}년 ${a.month}월 – ${b.month}월';
      big = '${a.day}일 – ${b.day}일';
    } else {
      prevLabel = '전날';
      nextLabel = '다음 날';
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
                    const SizedBox(width: 10),
                    _NavButton(
                      icon: Icons.chevron_left_rounded,
                      label: prevLabel,
                      onTap: () => shift(-1),
                    ),
                    const SizedBox(width: 6),
                    _NavButton(
                      icon: Icons.chevron_right_rounded,
                      label: nextLabel,
                      onTap: () => shift(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tap(
            onTap: () => openSearch(context),
            label: '검색',
            child: SizedBox(
              width: 44,
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

/// 옆으로 넘기는 버튼 (밀어서 넘기는 대신)
class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      label: label,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.soft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 24, color: p.ink),
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
