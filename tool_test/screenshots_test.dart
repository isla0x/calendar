// 앱스토어용 스크린샷을 실제 앱 화면으로 만들어요. (샘플 일정 사용)
//
// 실행:  flutter test tool_test/screenshots_test.dart
// 결과:  build/screenshots/*.png  (1320 × 2868, iPhone 6.9인치)
//
// 일반 `flutter test`에는 포함되지 않아요(test/ 폴더만 실행하므로).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/main.dart';
import 'package:yeobaek/store.dart';
import 'package:yeobaek/theme.dart';

void main() {
  // 2026-10-26 월요일 14:10
  final now = DateTime(2026, 10, 26, 14, 10);
  final key = GlobalKey();

  Future<void> loadFont() async {
    final loader = FontLoader('IBMPlexSansKR');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/IBMPlexSansKR-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();

    // 아이콘 글꼴(Material Icons)은 테스트에서 자동으로 안 불러와서 Flutter SDK에서 찾아 직접 불러와요.
    final found = Process.runSync('bash', [
      '-c',
      'find "\${FLUTTER_ROOT:-/nonexistent}" /opt /usr/local /home /root -name MaterialIcons-Regular.otf -print -quit 2>/dev/null',
    ]).stdout.toString().trim();
    File('build/screenshots/debug.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('icons: "$found"\nFLUTTER_ROOT: ${Platform.environment['FLUTTER_ROOT']}\n');
    if (found.isNotEmpty) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(Future.value(ByteData.view(File(found).readAsBytesSync().buffer)));
      await icons.load();
    }
  }

  Future<CalendarStore> open(WidgetTester tester) async {
    useWebFont = true;
    // iPhone 6.9인치: 1320 × 2868 (논리 440 × 956, 배율 3)
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    // 상태 표시줄(위 59)과 홈 인디케이터(아래 34) 자리
    const pad = FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.padding = pad;
    tester.view.viewPadding = pad;
    addTearDown(tester.view.reset);
    final store = CalendarStore(DemoRepo(clock: () => now), clock: () => now);
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: YeobaekApp(store: store, ticking: false)),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> save(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/screenshots/$name.png')..createSync(recursive: true);
      file.writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  setUpAll(loadFont);

  testWidgets('1 월간', (tester) async {
    await open(tester);
    await save(tester, '1-month');
  });

  testWidgets('2 오늘', (tester) async {
    final store = await open(tester);
    store.setView(ViewMode.day);
    await save(tester, '2-today');
  });

  testWidgets('3 주간', (tester) async {
    final store = await open(tester);
    store.setView(ViewMode.week);
    await save(tester, '3-week');
  });

  testWidgets('4 한 줄 입력', (tester) async {
    await open(tester);
    await tester.tap(find.text('한 줄로 추가 · 예) 내일 3시 치과'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '내일 오후 3시 치과 30분');
    await save(tester, '4-quick-add');
  });

  testWidgets('5 일정 상세', (tester) async {
    await open(tester);
    await tester.tap(find.text('스프린트 플래닝'));
    await save(tester, '5-detail');
  });

  testWidgets('6 다크 모드', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = await open(tester);
    store.setView(ViewMode.day);
    await save(tester, '6-dark');
  });
}
