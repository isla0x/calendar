import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../models.dart';
import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';
import 'tag_dialog.dart';

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
        return '${relDay(e.start, today)} · ${wdFull(e.start)} · 종일';
      }
      return '${e.start.month}월 ${e.start.day}일 – ${last.month}월 ${last.day}일 · 종일';
    }
    final head = '${relDay(e.start, today)} · ${wdFull(e.start)}';
    final endsSameDay = sameDay(e.start, e.end) ||
        (e.end.hour == 0 && e.end.minute == 0 && daysBetween(e.start, e.end) == 1);
    if (endsSameDay) return '$head ${hm(e.start)} – ${hm(e.end)}';
    return '$head ${hm(e.start)} – ${e.end.month}월 ${e.end.day}일 ${hm(e.end)}';
  }

  String? _status(Ev e, DateTime now) {
    if (e.allDay) {
      final n = daysBetween(e.start, e.end);
      return n > 1 ? '$n일 동안' : null;
    }
    final dur = durText(e.duration);
    if (!e.end.isAfter(now)) return '종료됨 · $dur';
    if (!e.start.isAfter(now)) return '진행 중 · $dur';
    final m = e.start.difference(now).inMinutes;
    if (m < 24 * 60) return '${leftText(math.max(1, m))} 후 시작 · $dur';
    return dur;
  }

  String _reminderText(Duration d) {
    final m = d.inMinutes.abs();
    if (m == 0) return '시작할 때 알림';
    if (m < 60) return '$m분 전 알림';
    if (m < 24 * 60) {
      final h = m ~/ 60;
      final r = m % 60;
      return r == 0 ? '$h시간 전 알림' : '$h시간 $r분 전 알림';
    }
    return '${m ~/ (24 * 60)}일 전 알림';
  }

  // ---------------------------------------------------------------- 동작

  void _snack(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: ts(ctx, 17, weight: FontWeight.w700)),
        content: Text(body, style: ts(ctx, 14, weight: FontWeight.w400, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _openEditor() async {
    final store = StoreScope.of(context);
    if (store.isDemo) {
      _snack('샘플 모드에서는 편집할 수 없어요');
      return;
    }
    try {
      await store.repo.openEditor(_ev);
    } catch (_) {
      if (mounted) _snack('편집 화면을 열지 못했어요');
      return;
    }
    await store.reload();
    if (!mounted) return;
    final fresh = store.findEvent(_ev.id, start: _ev.start);
    if (fresh == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _ev = fresh);
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
        content: Text('${hm(s.start)}–${hm(s.end)} 로 옮겼어요'),
        action: SnackBarAction(label: '되돌리기', onPressed: () => _undoMove(old)),
      ));
    } else {
      _snack(store.error ?? '일정을 옮기지 못했어요');
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
      final go = await _confirm(
        '반복 일정이에요',
        '이 일정만 지울지, 앞으로의 일정을 모두 지울지는\n기본 편집 화면에서 고를 수 있어요.',
        '편집 화면 열기',
      );
      if (go && mounted) await _openEditor();
      return;
    }
    final yes = await _confirm('이 일정을 지울까요?', e.title, '지우기');
    if (!yes || !mounted) return;
    final done = await store.deleteEvent(e);
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      _snack(store.error ?? '일정을 지우지 못했어요');
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
    if (!ok) _snack(store.error ?? '태그를 바꾸지 못했어요');
  }

  Future<void> _share() async {
    final e = _ev;
    final lines = <String>[e.title, e.whenText()];
    final loc = e.location;
    if (loc != null && loc.trim().isNotEmpty) lines.add(loc.trim());
    if (e.tags.isNotEmpty) lines.add(e.tags.map((t) => '#$t').join(' '));
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) _snack('일정 정보를 복사했어요');
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
    if (e.attendees > 0) addRow(Icons.people_outline_rounded, '참석 ${e.attendees}명');
    for (final r in e.reminders.take(3)) {
      addRow(Icons.notifications_none_rounded, _reminderText(r));
    }
    if (e.recurring) addRow(Icons.repeat_rounded, '반복 일정');
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
                    label: '뒤로',
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
                        child: Text('편집', style: ts(context, 16, weight: FontWeight.w600)),
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
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: p.dark
                                          ? const Color(0x24FFFFFF)
                                          : const Color(0xB3FFFFFF),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      '#$t',
                                      style: ts(
                                        context,
                                        14,
                                        weight: FontWeight.w600,
                                        color: tagColor(t, dark: p.dark),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!e.readOnly)
                                Tap(
                                  onTap: _editTags,
                                  label: '태그 바꾸기',
                                  child: Container(
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: c.text.withAlpha(90)),
                                    ),
                                    child: Text(
                                      e.tags.isEmpty ? '+ 태그' : '편집',
                                      style: ts(
                                        context,
                                        14,
                                        weight: FontWeight.w600,
                                        color: c.text,
                                      ),
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
                            '겹치지 않는 시간으로 옮기기',
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
                          '삭제',
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
                        '공유하기',
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
