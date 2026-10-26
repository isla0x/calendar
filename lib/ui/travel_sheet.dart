import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../travel.dart';
import 'common.dart';
import 'sheets.dart';
import '../l10n.dart';

/// 이동시간 고르는 창. 저장하면 [Travel], 닫으면 null.
/// [place] 를 넣으면 "앞으로도 이 시간으로" 스위치가 나오고, 켜 두면 그 장소의 이동시간을 기억해요.
Future<Travel?> showTravelSheet(
  BuildContext context, {
  Travel initial = Travel.none,
  String place = '',
}) {
  return showAppSheet<Travel>(
    context: context,
    builder: (_) => _TravelSheet(initial: initial, place: place.trim()),
  );
}

class _TravelSheet extends StatefulWidget {
  const _TravelSheet({required this.initial, required this.place});

  final Travel initial;
  final String place;

  @override
  State<_TravelSheet> createState() => _TravelSheetState();
}

class _TravelSheetState extends State<_TravelSheet> {
  late int _before = widget.initial.before;
  late int _after = widget.initial.after;

  /// 올 때도 같은 시간으로 (처음엔 둘이 같거나 비어 있을 때 켜 둬요)
  late bool _same = widget.initial.before == widget.initial.after;

  /// 이 장소는 앞으로도 이 시간으로
  bool _remember = true;

  void _finish(Travel t) {
    if (widget.place.isNotEmpty && _remember) {
      // 비동기지만 기다리지 않아도 돼요 (저장은 기기에 바로 쓰여요)
      StoreScope.read(context).rememberPlace(widget.place, t.isNone ? null : t);
    }
    Navigator.of(context).pop(t);
  }

  void _usePlace(Travel t) {
    setState(() {
      _before = t.before;
      _after = t.after;
      _same = t.before == t.after;
    });
  }

  Widget _chips(String key, int value, ValueChanged<int> onPick) {
    final p = Pal.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in Travel.choices)
          Tap(
            onTap: () => onPick(m),
            label: m == 0 ? tl('{0} 없음', [key]) : '$key ${Travel.minText(m)}',
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
                m == 0 ? tl('없음') : Travel.minText(m),
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
    final places = StoreScope.of(context).knownPlaces;
    return SheetFrame(
      title: tl('이동시간'),
      subtitle: tl('정해 두면 비는 시간과 할 일 자리 찾기에서 이 시간을 빼고 계산해요.'),
      footer: Row(
        children: [
          Expanded(
            child: BigButton(label: tl('이동시간 없음'), quiet: true, onTap: () => _finish(Travel.none)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BigButton(label: tl('저장'), onTap: () => _finish(t)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (places.isNotEmpty) ...[
            Text(tl('자주 가는 곳'), style: ts(context, 14, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in places.take(6))
                  Tap(
                    onTap: () => _usePlace(e.$2),
                    label: '${e.$1} ${e.$2.shortLabel}',
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.soft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.$1} · ${e.$2.shortLabel}',
                        style: ts(context, 14, weight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Text(tl('가는 데'), style: ts(context, 14, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          _chips(tl('가는 데'), _before, (m) => setState(() => _before = m)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text(tl('올 때도 같게'), style: ts(context, 14, weight: FontWeight.w700))),
              AppSwitch(value: _same, onChanged: (v) => setState(() => _same = v), label: tl('올 때도 같게')),
            ],
          ),
          if (!_same) ...[
            const SizedBox(height: 14),
            Text(tl('돌아오는 데'), style: ts(context, 14, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            _chips(tl('오는 데'), _after, (m) => setState(() => _after = m)),
          ],
          const SizedBox(height: 14),
          Text(
            t.isNone ? tl('이동시간 없음') : t.label,
            style: ts(context, 13, color: p.muted),
          ),
          if (widget.place.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tl('"{0}"은(는) 앞으로도 이 시간으로', [widget.place]),
                    style: ts(context, 14, weight: FontWeight.w700, height: 20 / 14),
                  ),
                ),
                const SizedBox(width: 10),
                AppSwitch(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v),
                  label: tl('앞으로도 이 시간으로'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
