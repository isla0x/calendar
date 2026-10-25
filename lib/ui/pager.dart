import 'package:flutter/material.dart';

import '../store.dart';

/// 옆으로 밀어서 이전/다음 쪽(주, 하루 등)으로 넘기는 틀.
/// 넘어가는 동안 앞뒤 쪽이 함께 보이고, 손을 떼서 자리 잡으면 [onShift] 로 알려줘요.
/// 버튼이나 다른 곳에서 날짜가 바뀌면 쪽도 부드럽게 따라가요.
class SwipePager extends StatefulWidget {
  const SwipePager({
    super.key,
    required this.index,
    required this.onShift,
    required this.builder,
  });

  /// 지금 화면이 가리키는 쪽 번호 (예: 2000년부터 센 주 번호)
  final int Function(CalendarStore store) index;

  /// 쪽이 [delta] 만큼 넘어갔을 때 (예: shiftWeek)
  final void Function(CalendarStore store, int delta) onShift;

  /// 쪽 번호로 그 쪽의 내용을 그려요
  final Widget Function(BuildContext context, int index) builder;

  @override
  State<SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<SwipePager> {
  static const int _basePage = 5000;
  late final int _base;
  late final PageController _pc;
  bool _dragging = false;
  int? _animTo;

  @override
  void initState() {
    super.initState();
    _base = widget.index(StoreScope.read(context));
    _pc = PageController(initialPage: _basePage);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  int _pageOf(int idx) => _basePage + (idx - _base);
  int _idxOf(int page) => _base + (page - _basePage);

  void _sync(int target) {
    if (!_pc.hasClients || _dragging || _animTo == target) return;
    final cur = _pc.page;
    if (cur == null || (cur - target).abs() < 0.001) return;
    _animTo = target;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_pc.hasClients) {
        _animTo = null;
        return;
      }
      final from = _pc.page ?? target.toDouble();
      if ((target - from).abs() > 1.5) {
        _pc.jumpToPage(target);
      } else {
        await _pc.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      _animTo = null;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
    if (n is ScrollEndNotification) {
      _dragging = false;
      final store = StoreScope.read(context);
      final page = _pc.page;
      if (page != null) {
        final delta = page.round() - _pageOf(widget.index(store));
        if (delta != 0) widget.onShift(store, delta);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    _sync(_pageOf(widget.index(store)));
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: PageView.builder(
        controller: _pc,
        itemBuilder: (context, i) => widget.builder(context, _idxOf(i)),
      ),
    );
  }
}
