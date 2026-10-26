import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import '../l10n.dart';

/// 화면 아래에 떠 있는 "한 줄 입력" 막대.
/// 모양·위치를 바꾸고 싶으면 이 파일만 고치면 돼요.
class QuickBar extends StatelessWidget {
  const QuickBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      label: tl('일정 추가'),
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(left: 20, right: 6),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.line),
          boxShadow: [
            BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            const SparkleIcon(size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tl('한 줄로 추가 · 예) 내일 3시 치과'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(context, 15, weight: FontWeight.w400, color: p.muted),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
              child: Icon(Icons.add_rounded, size: 24, color: p.bg),
            ),
          ],
        ),
      ),
    );
  }
}
