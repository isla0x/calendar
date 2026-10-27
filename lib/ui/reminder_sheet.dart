import 'package:flutter/material.dart';

import '../dates.dart';
import '../reminder.dart';
import '../theme.dart';
import 'common.dart';
import 'sheets.dart';
import '../l10n.dart';

/// 고른 알림 (null 이면 "알림 없음"). 창을 그냥 닫으면 [showReminderSheet] 가 null 을 돌려줘요.
class ReminderPick {
  const ReminderPick(this.reminder);
  final Reminder? reminder;
}

/// 알림 시점을 고르는 창. 일정 시작 [start] 를 기준으로 "언제 울리는지"를 같이 보여줘요.
/// 이미 지난 시각이거나 시작보다 늦게 울려야 하는 선택지는 흐리게 두고 고를 수 없어요.
/// [allowPast] 가 true 면 (반복 일정처럼 다음 번에 울릴 수 있을 때) 지난 시각도 고를 수 있어요.
Future<ReminderPick?> showReminderSheet(
  BuildContext context, {
  required DateTime start,
  required bool allDay,
  required Reminder? current,
  required DateTime now,
  String? title,
  bool allowPast = false,
}) {
  return showAppSheet<ReminderPick>(
    context: context,
    builder: (ctx) {
      final p = Pal.of(ctx);
      Widget row({
        required String label,
        required String? right,
        required bool on,
        required bool enabled,
        required VoidCallback onTap,
      }) {
        final fg = enabled ? p.ink : p.dash;
        return Tap(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: on ? Icon(Icons.check_rounded, size: 20, color: p.ink) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: ts(ctx, 17, weight: on ? FontWeight.w700 : FontWeight.w600, color: fg)),
                ),
                if (right != null)
                  Flexible(
                    child: Text(
                      right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(ctx, 14, color: enabled ? p.muted : p.dash),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      final sub = StringBuffer(allDay ? dateChip(dayOnly(start)) : '${dateChip(dayOnly(start))} · ${ampm(start)}');
      if (title != null && title.trim().isNotEmpty) sub.write(' · ${title.trim()}');
      return SheetFrame(
        title: tl('알림 시점'),
        subtitle: sub.toString(),
        child: Column(
          children: [
            row(
              label: tl('알림 없음'),
              right: null,
              on: current == null,
              enabled: true,
              onTap: () => Navigator.of(ctx).pop(const ReminderPick(null)),
            ),
            for (final r in ReminderX.options(allDay: allDay))
              () {
                final off = r.offset(start);
                final ok = off != null && (allowPast || r.fireAt(start).isAfter(now));
                return row(
                  label: r.label,
                  right: ok ? ReminderX.fireText(r, start) : tl('선택 불가'),
                  on: current == r,
                  enabled: ok,
                  onTap: () => Navigator.of(ctx).pop(ReminderPick(r)),
                );
              }(),
          ],
        ),
      );
    },
  );
}
