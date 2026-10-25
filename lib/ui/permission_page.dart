import 'package:flutter/material.dart';

import '../app_info.dart';
import '../repo.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// 캘린더 접근 권한을 받기 전에 보이는 안내 화면
class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  String _message(PermState s) {
    switch (s) {
      case PermState.denied:
        return '캘린더 접근이 꺼져 있어요.\n설정에서 캘린더를 켜 주세요.';
      case PermState.writeOnly:
        return '일정을 읽으려면 "모든 일정" 접근이 필요해요.\n설정에서 바꿔 주세요.';
      case PermState.restricted:
        return '이 기기에서는 캘린더 접근이 제한되어 있어요.';
      default:
        return '기기 캘린더의 일정을 그대로 불러와요.\n일정은 이 기기 안에서만 다뤄요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final needSettings = store.perm == PermState.denied ||
        store.perm == PermState.writeOnly ||
        store.perm == PermState.restricted;

    return Padding(
      padding: EdgeInsets.fromLTRB(28, top + 80, 28, bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.calendar_today_rounded, color: p.bg, size: 26),
          ),
          const SizedBox(height: 28),
          Text(
            kAppName,
            style: ts(context, 34, weight: FontWeight.w700, height: 40 / 34),
          ),
          const SizedBox(height: 10),
          Text(
            '비는 시간까지 한눈에 보여주는 캘린더',
            style: ts(context, 16, color: p.muted, height: 22 / 16),
          ),
          const SizedBox(height: 32),
          Text(
            _message(store.perm),
            style: ts(context, 15, height: 24 / 15),
          ),
          const Spacer(),
          if (needSettings && store.perm != PermState.restricted)
            _BigButton(label: '설정 열기', filled: true, onTap: store.openSettings)
          else if (!needSettings)
            _BigButton(label: '캘린더 접근 허용하기', filled: true, onTap: store.requestPermission),
          const SizedBox(height: 10),
          _BigButton(label: '샘플로 먼저 둘러보기', filled: false, onTap: store.useDemo),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? p.ink : p.surface,
          borderRadius: BorderRadius.circular(28),
          border: filled ? null : Border.all(color: p.line),
        ),
        child: Text(
          label,
          style: ts(context, 16, weight: FontWeight.w600, color: filled ? p.bg : p.ink),
        ),
      ),
    );
  }
}
