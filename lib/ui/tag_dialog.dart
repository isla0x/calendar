import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'sheets.dart';

/// 태그를 쓰거나 고르는 창. 취소하면 null, 완료하면 태그 목록(비어 있을 수 있어요).
Future<List<String>?> showTagDialog(
  BuildContext context, {
  List<String> initial = const [],
  List<String> known = const [],
}) {
  return showTagSheet(context, initial: initial, known: known);
}

/// 위쪽 "#" 버튼: 어떤 태그 일정만 볼지 고르는 창
Future<void> showTagFilterSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const _TagFilterSheet(),
  );
}

class _TagFilterSheet extends StatelessWidget {
  const _TagFilterSheet();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Pal.of(context);
    final tags = store.knownTags();
    final cur = store.tagFilter;

    void pick(String? t) {
      store.setTagFilter(t);
      Navigator.of(context).pop();
    }

    return SheetFrame(
      title: '태그로 보기',
      subtitle: '고른 태그가 붙은 일정만 또렷하게 보여요',
      footer: cur == null
          ? null
          : BigButton(label: '전체 보기', quiet: true, onTap: () => pick(null)),
      child: tags.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '아직 태그가 없어요.\n일정에 #태그를 붙이면 여기에 나타나요.',
                style: ts(context, 14, color: p.muted, height: 1.6),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  TagPill(tag: t, on: cur == t, height: 38, onTap: () => pick(t)),
              ],
            ),
    );
  }
}
