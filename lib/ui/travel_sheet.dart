import 'package:flutter/material.dart';

import '../theme.dart';
import '../travel.dart';
import 'common.dart';
import 'sheets.dart';

/// 이동시간 고르는 창. 저장하면 [Travel], 닫으면 null.
Future<Travel?> showTravelSheet(BuildContext context, {Travel initial = Travel.none}) {
  return showAppSheet<Travel>(
    context: context,
    builder: (_) => _TravelSheet(initial: initial),
  );
}

class _TravelSheet extends StatefulWidget {
  const _TravelSheet({required this.initial});

  final Travel initial;

  @override
  State<_TravelSheet> createState() => _TravelSheetState();
}

class _TravelSheetState extends State<_TravelSheet> {
  late int _before = widget.initial.before;
  late int _after = widget.initial.after;

  /// 올 때도 같은 시간으로 (처음엔 둘이 같거나 비어 있을 때 켜 둬요)
  late bool _same = widget.initial.before == widget.initial.after;

  Widget _chips(String key, int value, ValueChanged<int> onPick) {
    final p = Pal.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in Travel.choices)
          Tap(
            onTap: () => onPick(m),
            label: m == 0 ? '$key 없음' : '$key ${Travel.minText(m)}',
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value == m ? p.ink : p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: value == m ? p.ink : p.line),
              ),
              child: Text(
                m == 0 ? '없음' : Travel.minText(m),
                style: ts(context, 14, weight: FontWeight.w600, color: value == m ? p.bg : p.ink),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = Travel(before: _before, after: _same ? _before : _after);
    return SheetFrame(
      title: '이동시간',
      subtitle: '정해 두면 비는 시간과 할 일 자리 찾기에서 이 시간을 빼고 계산해요.',
      footer: Row(
        children: [
          Expanded(
            child: BigButton(label: '이동시간 없음', quiet: true, onTap: () => Navigator.of(context).pop(Travel.none)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BigButton(label: '저장', onTap: () => Navigator.of(context).pop(t)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('가는 데', style: ts(context, 14, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          _chips('가는 데', _before, (m) => setState(() => _before = m)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('올 때도 같게', style: ts(context, 14, weight: FontWeight.w700))),
              AppSwitch(value: _same, onChanged: (v) => setState(() => _same = v), label: '올 때도 같게'),
            ],
          ),
          if (!_same) ...[
            const SizedBox(height: 14),
            Text('돌아오는 데', style: ts(context, 14, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            _chips('오는 데', _after, (m) => setState(() => _after = m)),
          ],
          const SizedBox(height: 14),
          Text(
            t.isNone ? '이동시간 없음' : t.label,
            style: ts(context, 13, color: p.muted),
          ),
        ],
      ),
    );
  }
}
