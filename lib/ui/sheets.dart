import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme, CupertinoThemeData, CupertinoTextThemeData;
import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';

/// 앱 전체에서 같이 쓰는 "아래에서 올라오는 창" 모음.
/// 모양을 한 곳(SheetFrame)에서 정해서, 태그·장소·날짜·시간·확인 창이 모두 같은 느낌이에요.

Future<T?> showAppSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: builder,
  );
}

/// 창 틀: 손잡이 · 제목(+설명) · 오른쪽 버튼 · 내용 · 아래 버튼. 키보드가 올라오면 같이 올라와요.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.child,
    this.footer,
  });

  final String title;
  final String? subtitle;

  /// 제목 오른쪽 위젯 (예: "오늘" 버튼)
  final Widget? action;
  final Widget? child;

  /// 맨 아래 큰 버튼 줄
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final bottom = keyboard > 0 ? keyboard + 12 : math.max(mq.padding.bottom, 16.0);
    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(
                    color: p.dash.withAlpha(p.dark ? 255 : 150),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: ts(context, 21, weight: FontWeight.w700, letterSpacing: -0.5),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: ts(context, 13, color: p.muted, height: 18 / 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: 18),
                child!,
              ],
              if (footer != null) ...[
                const SizedBox(height: 22),
                footer!,
              ],
            ],
          ),
        ),
    );
  }
}

/// 크고 둥근 버튼 (아래 줄). [quiet] 면 테두리만 있는 버튼.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.quiet = false,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final bool quiet;

  /// 글자색 (조용한 버튼에서 빨강 등)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: quiet ? p.surface : p.ink,
            borderRadius: BorderRadius.circular(27),
            border: quiet ? Border.all(color: p.line) : null,
          ),
          child: Text(
            label,
            style: ts(
              context,
              16,
              weight: FontWeight.w600,
              color: color ?? (quiet ? p.ink : p.bg),
            ),
          ),
        ),
      ),
    );
  }
}

/// 태그 모양 알약. 고른 상태면 태그 색으로 물들어요.
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.tag,
    this.on = false,
    this.onTap,
    this.trailing,
    this.height = 36,
  });

  final String tag;
  final bool on;
  final VoidCallback? onTap;
  final IconData? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final col = tagColor(tag, dark: p.dark);
    return Tap(
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.only(left: 14, right: trailing == null ? 14 : 10),
        decoration: BoxDecoration(
          color: on ? Color.alphaBlend(col.withAlpha(p.dark ? 60 : 40), p.surface) : p.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: on ? col.withAlpha(120) : p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#$tag', style: ts(context, 14, weight: FontWeight.w600, color: col)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 16, color: col),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 태그 고르기

/// 태그를 쓰거나 고르는 창. 취소하면 null, "완료"를 누르면 태그 목록(비어 있을 수 있어요).
Future<List<String>?> showTagSheet(
  BuildContext context, {
  List<String> initial = const [],
  List<String> known = const [],
}) {
  return showAppSheet<List<String>>(
    context: context,
    builder: (_) => _TagSheet(initial: initial, known: known),
  );
}

class _TagSheet extends StatefulWidget {
  const _TagSheet({required this.initial, required this.known});

  final List<String> initial;
  final List<String> known;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  final TextEditingController _c = TextEditingController();
  late final List<String> _sel = [...widget.initial];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _addTyped() {
    final add = tagsFromText(_c.text);
    if (add.isEmpty) return;
    setState(() {
      for (final t in add) {
        if (!_sel.contains(t)) _sel.add(t);
      }
      _c.clear();
    });
  }

  void _toggle(String t) {
    setState(() {
      if (!_sel.remove(t)) _sel.add(t);
    });
  }

  void _done() {
    // 입력 칸에 쓰다 만 태그도 같이 담아요.
    final rest = tagsFromText(_c.text);
    final out = [..._sel];
    for (final t in rest) {
      if (!out.contains(t)) out.add(t);
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final typed = _c.text.trim().isNotEmpty;
    final others = [
      for (final t in widget.known)
        if (!_sel.contains(t)) t,
    ];
    return SheetFrame(
      title: '태그',
      subtitle: '일정을 묶어서 한눈에 볼 수 있어요',
      footer: Row(
        children: [
          Expanded(
            flex: 2,
            child: BigButton(
              label: '취소',
              quiet: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: BigButton(label: '완료', onTap: _done)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.only(left: 16, right: 7),
            decoration: BoxDecoration(
              color: p.soft,
              borderRadius: BorderRadius.circular(27),
            ),
            child: Row(
              children: [
                Icon(Icons.tag_rounded, size: 20, color: p.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _c,
                    textInputAction: TextInputAction.done,
                    cursorColor: p.ink,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _addTyped(),
                    style: ts(context, 16, weight: FontWeight.w600),
                    decoration: InputDecoration.collapsed(
                      hintText: '새 태그를 써서 추가해요',
                      hintStyle: ts(context, 16, weight: FontWeight.w500, color: p.dash),
                    ),
                  ),
                ),
                Tap(
                  onTap: typed ? _addTyped : null,
                  label: '태그 추가',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typed ? p.ink : p.line,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded, size: 22, color: typed ? p.bg : p.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('붙인 태그', style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
          const SizedBox(height: 10),
          if (_sel.isEmpty)
            Text('아직 없어요', style: ts(context, 14, color: p.dash))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _sel)
                  TagPill(tag: t, on: true, trailing: Icons.close_rounded, onTap: () => _toggle(t)),
              ],
            ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('자주 쓰는 태그', style: ts(context, 13, weight: FontWeight.w600, color: p.muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in others) TagPill(tag: t, onTap: () => _toggle(t)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 글 쓰기 (장소 등)

Future<String?> showTextSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required String hint,
  String initial = '',
  IconData icon = Icons.edit_outlined,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => _TextSheet(
      title: title,
      subtitle: subtitle,
      hint: hint,
      initial: initial,
      icon: icon,
    ),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.initial,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final String hint;
  final String initial;
  final IconData icon;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      footer: Row(
        children: [
          Expanded(
            flex: 2,
            child: BigButton(
              label: '취소',
              quiet: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: BigButton(
              label: '완료',
              onTap: () => Navigator.of(context).pop(_c.text.trim()),
            ),
          ),
        ],
      ),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: p.soft,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: p.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _c,
                autofocus: true,
                textInputAction: TextInputAction.done,
                cursorColor: p.ink,
                onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
                style: ts(context, 16, weight: FontWeight.w600),
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: ts(context, 16, weight: FontWeight.w500, color: p.dash),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 확인

/// "정말 지울까요?" 같은 확인 창. 누르면 true, 취소하면 false.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  required String yes,
  String no = '취소',
  bool danger = false,
}) async {
  final r = await showAppSheet<bool>(
    context: context,
    builder: (ctx) {
      final p = Pal.of(ctx);
      return SheetFrame(
        title: title,
        subtitle: body,
        footer: Row(
          children: [
            Expanded(
              flex: 2,
              child: BigButton(label: no, quiet: true, onTap: () => Navigator.of(ctx).pop(false)),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: danger
                  ? Tap(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.red,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Text(
                          yes,
                          style: ts(ctx, 16, weight: FontWeight.w600, color: p.dark ? p.bg : Colors.white),
                        ),
                      ),
                    )
                  : BigButton(label: yes, onTap: () => Navigator.of(ctx).pop(true)),
            ),
          ],
        ),
      );
    },
  );
  return r == true;
}

// ------------------------------------------------------------------ 캘린더 고르기

Future<String?> showCalendarSheet(
  BuildContext context, {
  required List<CalInfo> list,
  String? currentId,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (ctx) {
      final p = Pal.of(ctx);
      return SheetFrame(
        title: '캘린더',
        subtitle: '어느 캘린더에 담을까요?',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final c in list)
                Tap(
                  onTap: () => Navigator.of(ctx).pop(c.id),
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        Dot(c.color, size: 12),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(ctx, 16, weight: FontWeight.w600),
                          ),
                        ),
                        if (c.id == currentId) Icon(Icons.check_rounded, size: 22, color: p.ink),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ 날짜 고르기

/// 달력에서 날짜 하나를 고르는 창. 날짜를 누르면 바로 닫히고 그 날짜를 돌려줘요.
Future<DateTime?> showDateSheet(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
  DateTime? last,
  String title = '날짜',
}) {
  return showAppSheet<DateTime>(
    context: context,
    builder: (_) => _DateSheet(
      initial: dayOnly(initial),
      first: dayOnly(first ?? DateTime(2000)),
      last: dayOnly(last ?? DateTime(2100)),
      title: title,
    ),
  );
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({
    required this.initial,
    required this.first,
    required this.last,
    required this.title,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  bool get _canPrev => DateTime(_month.year, _month.month).isAfter(
        DateTime(widget.first.year, widget.first.month),
      );
  bool get _canNext => DateTime(_month.year, _month.month).isBefore(
        DateTime(widget.last.year, widget.last.month),
      );

  void _shift(int d) => setState(() => _month = DateTime(_month.year, _month.month + d));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final today = dayOnly(DateTime.now());
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final lastOfMonth = DateTime(_month.year, _month.month + 1, 0);
    final gridStart = weekStartSunday(firstOfMonth);
    final rows = daysBetween(gridStart, lastOfMonth) ~/ 7 + 1;

    Widget nav(IconData icon, String label, bool on, VoidCallback f) => Tap(
          onTap: on ? f : null,
          label: label,
          child: Opacity(
            opacity: on ? 1 : 0.3,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 24, color: p.ink),
            ),
          ),
        );

    final canToday = !today.isBefore(widget.first) && !today.isAfter(widget.last);

    return SheetFrame(
      title: widget.title,
      action: canToday
          ? Tap(
              onTap: () => Navigator.of(context).pop(today),
              child: Pill(
                height: 34,
                ring: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('오늘', style: ts(context, 14, weight: FontWeight.w600)),
              ),
            )
          : null,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_month.year}년 ${_month.month}월',
                  style: ts(context, 17, weight: FontWeight.w700),
                ),
              ),
              nav(Icons.chevron_left_rounded, '이전 달', _canPrev, () => _shift(-1)),
              const SizedBox(width: 8),
              nav(Icons.chevron_right_rounded, '다음 달', _canNext, () => _shift(1)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
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
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _dayCell(context, p, addDays(gridStart, r * 7 + c), today),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, Pal p, DateTime d, DateTime today) {
    if (d.month != _month.month) return const SizedBox(height: 46);
    final ok = !d.isBefore(widget.first) && !d.isAfter(widget.last);
    final sel = sameDay(d, widget.initial);
    final isToday = sameDay(d, today);
    final col = d.weekday % 7;
    Color fg = p.ink;
    if (col == 0) fg = p.red;
    if (col == 6) fg = p.blue;
    if (sel) fg = p.bg;
    return Tap(
      onTap: ok ? () => Navigator.of(context).pop(d) : null,
      child: SizedBox(
        height: 46,
        child: Center(
          child: Opacity(
            opacity: ok ? 1 : 0.3,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? p.ink : Colors.transparent,
                shape: BoxShape.circle,
                border: (!sel && isToday) ? Border.all(color: p.ink, width: 1.5) : null,
              ),
              child: Text(
                '${d.day}',
                style: ts(context, 16, weight: FontWeight.w600, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 시각 고르기

/// 돌려서 시각을 고르는 창. "완료"를 누르면 [initial] 의 날짜에 고른 시각을 얹어서 돌려줘요.
Future<DateTime?> showTimeSheet(
  BuildContext context, {
  required DateTime initial,
  String title = '시간',
}) {
  return showAppSheet<DateTime>(
    context: context,
    builder: (_) => _TimeWheelSheet(initial: initial, title: title),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initial, required this.title});

  final DateTime initial;
  final String title;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late DateTime _picked = widget.initial;
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final base = widget.initial;
    // 5분 단위 바퀴라서, 처음 시각은 5분 단위로 맞춰서 보여줘요. (안 건드리고 "완료"하면 원래 시각 그대로)
    final shown = DateTime(base.year, base.month, base.day, base.hour, base.minute - base.minute % 5);
    return SheetFrame(
      title: widget.title,
      footer: Row(
        children: [
          Expanded(
            flex: 2,
            child: BigButton(
              label: '취소',
              quiet: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: BigButton(
              label: '완료',
              onTap: () => Navigator.of(context).pop(_touched ? _picked : widget.initial),
            ),
          ),
        ],
      ),
      child: SizedBox(
        height: 200,
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: p.dark ? Brightness.dark : Brightness.light,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: ts(context, 21, weight: FontWeight.w600),
            ),
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: false,
            minuteInterval: 5,
            initialDateTime: shown,
            onDateTimeChanged: (d) {
              _touched = true;
              _picked = DateTime(base.year, base.month, base.day, d.hour, d.minute);
            },
          ),
        ),
      ),
    );
  }
}
