import 'package:flutter/material.dart';

import '../dates.dart';
import '../models.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';

/// 일정 한 줄 (월간 화면 아래 목록, 검색 결과)
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.onTap,
    this.showDate = false,
  });

  final Ev event;
  final VoidCallback onTap;

  /// true 면 왼쪽에 시각 대신 날짜(10/28)를 보여줘요.
  final bool showDate;

  String get _top {
    if (showDate) return '${event.start.month}/${event.start.day}';
    return event.allDay ? '종일' : hm(event.start);
  }

  String get _bottom {
    if (showDate) {
      return event.allDay ? '${wd(event.start)} · 종일' : '${wd(event.start)} · ${hm(event.start)}';
    }
    if (event.allDay) {
      final n = daysBetween(event.start, event.end);
      return n > 1 ? '$n일' : '';
    }
    return durText(event.duration);
  }

  String get _sub {
    final parts = <String>[];
    final loc = event.location;
    if (loc != null && loc.trim().isNotEmpty) parts.add(loc.trim());
    if (event.attendees > 0) parts.add('${event.attendees}명');
    if (event.calendarName.isNotEmpty) parts.add(event.calendarName);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sub = _sub;
    final subStyle = ts(context, 13, weight: FontWeight.w400, color: p.muted, height: 17 / 13);
    return Tap(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_top, style: ts(context, 15, weight: FontWeight.w600, height: 19 / 15)),
                    if (_bottom.isNotEmpty)
                      Text(
                        _bottom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 11, color: p.muted, height: 14 / 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Dot(event.color, size: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(context, 16, weight: FontWeight.w600, height: 20 / 16),
                    ),
                    if (sub.isNotEmpty || event.tags.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          style: subStyle,
                          children: [
                            for (final t in event.tags)
                              TextSpan(
                                text: '#$t ',
                                style: TextStyle(
                                  color: tagColor(t, dark: p.dark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            TextSpan(text: sub),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
