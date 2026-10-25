import 'package:flutter/material.dart';

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
