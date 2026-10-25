import 'package:flutter/material.dart';

import '../models.dart';
import 'detail_page.dart';
import 'quick_add_page.dart';
import 'search_page.dart';

/// 화면 이동 모음
Future<void> openDetail(BuildContext context, Ev e) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => EventDetailPage(event: e)),
  );
}

/// [initialText] 를 넣으면 한 줄 입력 칸에 미리 적어둬요 (예: 비는 시간을 눌렀을 때)
Future<void> openQuickAdd(BuildContext context, {String initialText = ''}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => QuickAddPage(initialText: initialText),
    ),
  );
}

Future<void> openSearch(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const SearchPage()),
  );
}
