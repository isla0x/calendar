import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_info.dart';
import 'color_book.dart';
import 'dates.dart';
import 'device_repo.dart';
import 'flags.dart';
import 'pro.dart';
import 'projects.dart';
import 'skins.dart';
import 'store.dart';
import 'todos.dart';
import 'travel.dart';
import 'widget_sync.dart';
import 'package:home_widget/home_widget.dart';
import 'ui/nav.dart';
import 'theme.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final colors = await PrefsColorBook.open();
  final projects = await PrefsProjectBook.open();
  final todos = await PrefsTodoBook.open();
  final travel = await PrefsTravelBook.open();
  final flags = await PrefsFlags.open();
  final pro = ProState(await StoreProBackend.open());
  runApp(YeobaekApp(
    colors: colors,
    projects: projects,
    todos: todos,
    travel: travel,
    flags: flags,
    pro: pro,
  ));
}

/// 앱 뿌리. [store] 를 넣으면 그걸 쓰고(테스트용), 아니면 기기 캘린더에 연결해요.
class YeobaekApp extends StatefulWidget {
  const YeobaekApp({super.key, this.store, this.ticking = true, this.colors, this.projects, this.todos, this.travel, this.flags, this.pro});

  /// 일정별 색을 기억해 두는 곳 (없으면 앱을 끄면 잊어요)
  final ColorBook? colors;

  /// 프로젝트를 기억해 두는 곳
  final ProjectBook? projects;

  /// 할 일을 기억해 두는 곳
  final TodoBook? todos;

  /// 이동시간을 기억해 두는 곳
  final TravelBook? travel;

  /// 처음 안내를 봤는지 같은 작은 표시
  final AppFlags? flags;

  /// Pro 구매 상태
  final ProState? pro;

  final CalendarStore? store;

  /// false 면 "지금" 시각을 주기적으로 갱신하지 않아요(테스트용).
  final bool ticking;

  @override
  State<YeobaekApp> createState() => _YeobaekAppState();
}

class _YeobaekAppState extends State<YeobaekApp> with WidgetsBindingObserver {
  late final CalendarStore _store;
  late final bool _owned;
  final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();
  WidgetSync? _sync;
  StreamSubscription<Uri?>? _clicks;

  @override
  void initState() {
    super.initState();
    _owned = widget.store == null;
    _store = widget.store ?? CalendarStore(DeviceRepo(), colors: widget.colors, projects: widget.projects, todos: widget.todos, travel: widget.travel, flags: widget.flags, pro: widget.pro);
    WidgetsBinding.instance.addObserver(this);
    _store.init();
    if (widget.ticking) _store.startClock();
    // 실제 기기에서만: 위젯에 자료를 건네고, 위젯을 눌러 들어오면 해당 화면을 열어요.
    if (_owned && defaultTargetPlatform == TargetPlatform.iOS) {
      _sync = WidgetSync(_store, HomeWidgetSink());
      HomeWidget.setAppGroupId(kWidgetGroup);
      _clicks = HomeWidget.widgetClicked.listen(_openFromWidget);
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_openFromWidget);
    }
  }

  void _openFromWidget(Uri? uri) {
    if (uri == null) return;
    // 화면이 다 그려진 뒤에 열어요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _nav.currentContext;
      if (ctx == null || !ctx.mounted) return;
      switch (uri.host) {
        case 'add':
          // from=밀리초: 그 시각부터 쓰기 (비는 시간을 눌렀을 때)
          final ms = int.tryParse(uri.queryParameters['from'] ?? '');
          var text = '';
          if (ms != null) {
            final f = DateTime.fromMillisecondsSinceEpoch(ms);
            text = '${f.month}월 ${f.day}일 ${timeWords(f.hour, f.minute)} ';
          }
          openQuickAdd(ctx, initialText: text);
        case 'todos':
          openTodos(ctx);
        case 'projects':
          openProjects(ctx);
        case 'today':
          _store.goToday();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clicks?.cancel();
    _sync?.dispose();
    _store.stopClock();
    if (_owned) _store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정 앱에 다녀오거나 다른 앱에서 일정을 고친 뒤 돌아오면 다시 읽어요.
    if (state == AppLifecycleState.resumed) _store.reload();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: _store,
      child: MaterialApp(
        navigatorKey: _nav,
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Skin.current.light),
        darkTheme: buildTheme(Skin.current.dark),
        themeMode: ThemeMode.system,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    );
  }
}
