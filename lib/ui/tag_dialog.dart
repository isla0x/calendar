import 'package:flutter/material.dart';

import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';

/// 태그를 쓰거나 고르는 작은 창. 취소하면 null, 확인하면 태그 목록(비어 있을 수 있어요).
Future<List<String>?> showTagDialog(
  BuildContext context, {
  List<String> initial = const [],
  List<String> known = const [],
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _TagDialog(initial: initial, known: known),
  );
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.initial, required this.known});

  final List<String> initial;
  final List<String> known;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial.isEmpty ? '' : '${widget.initial.map((t) => '#$t').join(' ')} ',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle(String t) {
    final cur = tagsFromText(_c.text);
    if (!cur.remove(t)) cur.add(t);
    final text = cur.isEmpty ? '' : '${cur.map((x) => '#$x').join(' ')} ';
    _c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cur = tagsFromText(_c.text);
    return AlertDialog(
      title: Text('태그', style: ts(context, 17, weight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => Navigator.of(context).pop(tagsFromText(v)),
              decoration: const InputDecoration(hintText: '예) 회의 건강 (띄어쓰기로 구분)'),
            ),
            if (widget.known.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '자주 쓴 태그',
                style: ts(context, 13, weight: FontWeight.w600, color: p.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in widget.known)
                    Tap(
                      onTap: () => _toggle(t),
                      child: Pill(
                        height: 32,
                        ring: !cur.contains(t),
                        color: cur.contains(t)
                            ? Color.alphaBlend(
                                tagColor(t, dark: p.dark).withAlpha(40),
                                p.surface,
                              )
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(tagsFromText(_c.text)),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

/// 위쪽 "# 태그" 버튼: 어떤 태그 일정만 볼지 고르는 창
Future<void> showTagFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
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
    final bottom = MediaQuery.of(context).padding.bottom;

    void pick(String? t) {
      store.setTagFilter(t);
      Navigator.of(context).pop();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('태그로 보기', style: ts(context, 18, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '고른 태그가 붙은 일정만 또렷하게 보여요',
            style: ts(context, 13, color: p.muted),
          ),
          const SizedBox(height: 16),
          if (tags.isEmpty)
            Text(
              '아직 태그가 없어요.\n일정에 #태그를 붙이면 여기에 나타나요.',
              style: ts(context, 14, color: p.muted, height: 1.6),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tap(
                  onTap: () => pick(null),
                  child: Pill(
                    height: 36,
                    ring: cur != null,
                    color: cur == null ? p.ink : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '전체',
                      style: ts(
                        context,
                        14,
                        weight: FontWeight.w600,
                        color: cur == null ? p.bg : p.ink,
                      ),
                    ),
                  ),
                ),
                for (final t in tags)
                  Tap(
                    onTap: () => pick(t),
                    child: Pill(
                      height: 36,
                      ring: cur != t,
                      color: cur == t
                          ? Color.alphaBlend(tagColor(t, dark: p.dark).withAlpha(44), p.surface)
                          : null,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
              ],
            ),
        ],
      ),
    );
  }
}
