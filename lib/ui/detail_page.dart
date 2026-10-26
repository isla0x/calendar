import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';
import 'edit_page.dart';
import 'sheets.dart';
import 'tag_dialog.dart';
import '../l10n.dart';

/// 일정 상세: 한눈에 보기, 겹치지 않는 시간으로 옮기기, 편집·삭제·공유
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event});

  final Ev event;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Ev _ev = widget.event;
  bool _busy = false;

  // ---------------------------------------------------------------- 문구

  String _whenLine(Ev e, DateTime today) {
    if (e.allDay) {
      final last = addDays(e.end, -1);
      if (!last.isAfter(e.start)) {
        return tl('{0} · {1} · 종일', [relDay(e.start, today), wdFull(e.start)]);
      }
      return tl('{0} – {1} · 종일', [mdText(e.start), mdText(last)]);
    }
    final head = '${relDay(e.start, today)} · ${wdFull(e.start)}';
    final endsSameDay = sameDay(e.start, e.end) ||
        (e.end.hour == 0 && e.end.minute == 0 && daysBetween(e.start, e.end) == 1);
    if (endsSameDay) return '$head ${hm(e.start)} – ${hm(e.end)}';
    return '$head ${hm(e.start)} – ${mdText(e.end)} ${hm(e.end)}';
  }

  String? _status(Ev e, DateTime now) {
    if (e.allDay) {
      final n = daysBetween(e.start, e.end);
      return n > 1 ? tl('{0}일 동안', [n]) : null;
    }
    final dur = durText(e.duration);
    if (!e.end.isAfter(now)) return tl('종료됨 · {0}', [dur]);
    if (!e.start.isAfter(now)) return tl('진행 중 · {0}', [dur]);
    final m = e.start.difference(now).inMinutes;
    if (m < 24 * 60) return tl('{0} 후 시작 · {1}', [leftText(math.max(1, m)), dur]);
    return dur;
  }

  String _reminderText(Duration d) {
    final m = d.inMinutes.abs();
    if (m == 0) return tl('시작할 때 알림');
    if (m < 60) return tl('{0}분 전 알림', [m]);
    if (m < 24 * 60) {
      final h = m ~/ 60;
      final r = m % 60;
      return r == 0 ? tl('{0}시간 전 알림', [h]) : tl('{0}시간 {1}분 전 알림', [h, r]);
    }
    return tl('{0}일 전 알림', [m ~/ (24 * 60)]);
  }

  // ---------------------------------------------------------------- 동작

  void _snack(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 앱 안의 편집 화면
  Future<void> _openEditor() async {
    final r = await Navigator.of(context).push<Ev>(
      MaterialPageRoute<Ev>(
        fullscreenDialog: true,
        builder: (_) => EventEditPage(event: _ev),
      ),
    );
    if (r != null && mounted) {
      final store = StoreScope.of(context);
      setState(() => _ev = store.findEvent(r.id, start: r.start) ?? r);
    }
  }

  Future<void> _move(Slot s) async {
    if (_busy) return;
    final store = StoreScope.of(context);
    final old = _ev;
    setState(() => _busy = true);
    final ok = await store.moveEvent(old, s.start, s.end);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _ev = store.findEvent(old.id, start: s.start) ?? old.copyWith(start: s.start, end: s.end);
      }
    });
    if (ok) {
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        content: Text(tl('{0}–{1} 로 옮겼어요', [hm(s.start), hm(s.end)])),
        action: SnackBarAction(label: tl('되돌리기'), onPressed: () => _undoMove(old)),
      ));
    } else {
      _snack(store.error ?? tl('일정을 옮기지 못했어요'));
    }
  }

  Future<void> _undoMove(Ev old) async {
    if (!mounted) return;
    final store = StoreScope.of(context);
    final ok = await store.moveEvent(_ev, old.start, old.end);
    if (!mounted) return;
    if (ok) {
      setState(() => _ev = store.findEvent(old.id, start: old.start) ?? old);
    }
  }

  Future<void> _delete() async {
    final store = StoreScope.of(context);
    final e = _ev;
    if (e.recurring) {
      final scope = await showAppSheet<DeleteScope>(
        context: context,
        builder: (ctx) => SheetFrame(
          title: tl('반복 일정을 지울까요?'),
          subtitle: e.title,
          child: Column(
            children: [
              BigButton(
                label: tl('이 일정만'),
                quiet: true,
                onTap: () => Navigator.of(ctx).pop(DeleteScope.one),
              ),
              const SizedBox(height: 10),
              BigButton(
                label: tl('이후 모든 일정'),
                quiet: true,
                onTap: () => Navigator.of(ctx).pop(DeleteScope.following),
              ),
              const SizedBox(height: 10),
              BigButton(
                label: tl('반복 일정 전체'),
                color: Pal.of(ctx).red,
                onTap: () => Navigator.of(ctx).pop(DeleteScope.all),
              ),
            ],
          ),
        ),
      );
      if (scope == null || !mounted) return;
      final done = await store.deleteEvent(e, scope: scope);
      if (!mounted) return;
      if (done) {
        Navigator.of(context).pop();
      } else {
        _snack(store.error ?? tl('일정을 지우지 못했어요'));
      }
      return;
    }
    final yes = await showConfirmSheet(
      context,
      title: tl('이 일정을 지울까요?'),
      body: e.title,
      yes: tl('지우기'),
      danger: true,
    );
    if (!yes || !mounted) return;
    final done = await store.deleteEvent(e);
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      _snack(store.error ?? tl('일정을 지우지 못했어요'));
    }
  }

  Future<void> _editTags() async {
    if (_busy) return;
    final store = StoreScope.of(context);
    final old = _ev;
    final r = await showTagDialog(
      context,
      initial: old.tags,
      known: store.knownTags().take(12).toList(),
    );
    if (r == null || !mounted) return;
    if (r.length == old.tags.length && r.every(old.tags.contains)) return;
    setState(() => _busy = true);
    final ok = await store.setEventTags(old, r);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _ev = store.findEvent(old.id, start: old.start) ?? old.copyWith(tags: r);
      }
    });
    if (!ok) _snack(store.error ?? tl('태그를 바꾸지 못했어요'));
  }

  Future<void> _share() async {
    final e = _ev;
    final lines = <String>[e.title, e.whenText()];
    final loc = e.location;
    if (loc != null && loc.trim().isNotEmpty) lines.add(loc.trim());
    if (e.tags.isNotEmpty) lines.add(e.tags.map((t) => '#$t').join(' '));
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) _snack(tl('일정 정보를 복사했어요'));
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final e = _ev;
    final c = evColors(e.color, p);
    final now = store.now;
    final today = store.today;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    final status = _status(e, now);

    // 정보 줄
    final rows = <Widget>[];
    void addRow(IconData icon, String text) {
      if (rows.isNotEmpty) rows.add(_Divider(color: p.line));
      rows.add(_InfoRow(icon: icon, text: text));
    }

    final loc = e.location;
    if (loc != null && loc.trim().isNotEmpty) addRow(Icons.place_outlined, loc.trim());
    final travel = store.travelOf(e);
    if (!travel.isNone && !e.allDay) addRow(Icons.directions_car_outlined, tl('이동시간 {0}', [travel.label]));
    if (e.attendees > 0) addRow(Icons.people_outline_rounded, tl('참석 {0}명', [e.attendees]));
    for (final r in e.reminders.take(3)) {
      addRow(Icons.notifications_none_rounded, _reminderText(r));
    }
    if (e.recurring) addRow(Icons.repeat_rounded, tl('반복 일정'));
    final note = e.note;
    if (note != null && note.trim().isNotEmpty) addRow(Icons.notes_rounded, note.trim());

    // 옮길 수 있는 시간
    final canMove = !e.readOnly &&
        !e.recurring &&
        !e.allDay &&
        !e.holiday &&
        e.duration.inMinutes >= 5 &&
        !dayOnly(e.start).isBefore(today);
    final slots = canMove
        ? store.slotsOnDay(
            e.duration,
            dayOnly(e.start),
            skip: e,
            from: sameDay(e.start, today) ? now : null,
            travel: store.travelOf(e),
          )
        : const <Slot>[];

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 4, 8, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tap(
                    onTap: () => Navigator.of(context).pop(),
                    label: tl('뒤로'),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.chevron_left_rounded, size: 30, color: p.ink),
                    ),
                  ),
                  if (!e.readOnly)
                    Tap(
                      onTap: _openEditor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(tl('편집'), style: ts(context, 16, weight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.tint,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.calendarName.isNotEmpty)
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: p.dark ? const Color(0x24FFFFFF) : const Color(0xB3FFFFFF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Dot(e.color, size: 8),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    e.calendarName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ts(context, 13, weight: FontWeight.w600, color: c.text),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        Text(
                          e.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: ts(
                            context,
                            30,
                            weight: FontWeight.w700,
                            height: 36 / 30,
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _whenLine(e, today),
                          style: ts(context, 16, color: c.text, height: 20 / 16),
                        ),
                        if (e.tags.isNotEmpty || !e.readOnly) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in e.tags)
                                Tap(
                                  onTap: e.readOnly ? null : _editTags,
                                  child: Container(
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: p.dark
                                          ? const Color(0x24FFFFFF)
                                          : const Color(0xB3FFFFFF),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '#$t',
                                          style: ts(
                                            context,
                                            14,
                                            weight: FontWeight.w600,
                                            color: tagColor(t, dark: p.dark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (!e.readOnly)
                                Tap(
                                  onTap: _editTags,
                                  label: tl('태그 바꾸기'),
                                  child: Container(
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: c.text.withAlpha(90)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          e.tags.isEmpty ? tl('+ 태그') : tl('편집'),
                                          style: ts(
                                            context,
                                            14,
                                            weight: FontWeight.w600,
                                            color: c.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (status != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: p.ink,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: p.bg),
                                const SizedBox(width: 6),
                                Text(
                                  status,
                                  style: ts(context, 14, weight: FontWeight.w600, color: p.bg),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (rows.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: p.line),
                      ),
                      child: Column(children: rows),
                    ),
                  if (slots.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tl('겹치지 않는 시간으로 옮기기'),
                            style: ts(context, 13, weight: FontWeight.w600, color: p.muted, height: 17 / 13),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in slots)
                                Tap(
                                  onTap: _busy ? null : () => _move(s),
                                  child: Pill(
                                    height: 36,
                                    ring: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      '${hm(s.start)}–${hm(s.end)}',
                                      style: ts(context, 14, weight: FontWeight.w600),
                                    ),
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
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, math.max(bottom, 16.0)),
            child: Row(
              children: [
                if (!e.readOnly) ...[
                  Expanded(
                    flex: 1,
                    child: Tap(
                      onTap: _delete,
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: p.line),
                        ),
                        child: Text(
                          tl('삭제'),
                          style: ts(context, 16, weight: FontWeight.w600, color: p.red),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: Tap(
                    onTap: _share,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.ink,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Text(
                        tl('공유하기'),
                        style: ts(context, 16, weight: FontWeight.w600, color: p.bg),
                      ),
                    ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: ts(context, 15, height: 21 / 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 52),
      height: 1,
      color: color,
    );
  }
}
