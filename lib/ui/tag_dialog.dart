import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'sheets.dart';
import '../l10n.dart';

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
    final cur = store.tagFilters;

    return SheetFrame(
      title: tl('태그로 보기'),
      subtitle: tl('여러 개를 골라 한꺼번에 볼 수 있어요'),
      footer: Row(
        children: [
          if (cur.isNotEmpty) ...[
            Expanded(
              flex: 2,
              child: BigButton(label: tl('전체 보기'), quiet: true, onTap: () {
                store.setTagFilters(const <String>[]);
                Navigator.of(context).pop();
              }),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 3,
            child: BigButton(label: tl('완료'), onTap: () => Navigator.of(context).pop()),
          ),
        ],
      ),
      child: tags.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                tl('아직 태그가 없어요.\n일정에 #태그를 붙이면 여기에 나타나요.'),
                style: ts(context, 14, color: p.muted, height: 1.6),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  TagPill(
                    tag: t,
                    on: cur.contains(t),
                    height: 38,
                    trailing: cur.contains(t) ? Icons.check_rounded : null,
                    onTap: () => store.toggleTagFilter(t),
                  ),
              ],
            ),
    );
  }
}
