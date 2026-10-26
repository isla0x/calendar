import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_info.dart';
import 'color_book.dart';
import 'device_repo.dart';
import 'projects.dart';
import 'skins.dart';
import 'store.dart';
import 'todos.dart';
import 'travel.dart';
import 'theme.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final colors = await PrefsColorBook.open();
  final projects = await PrefsProjectBook.open();
  final todos = await PrefsTodoBook.open();
  final travel = await PrefsTravelBook.open();
  runApp(YeobaekApp(colors: colors, projects: projects, todos: todos, travel: travel));
}

/// 앱 뿌리. [store] 를 넣으면 그걸 쓰고(테스트용), 아니면 기기 캘린더에 연결해요.
class YeobaekApp extends StatefulWidget {
  const YeobaekApp({super.key, this.store, this.ticking = true, this.colors, this.projects, this.todos, this.travel});

  /// 일정별 색을 기억해 두는 곳 (없으면 앱을 끄면 잊어요)
  final ColorBook? colors;

  /// 프로젝트를 기억해 두는 곳
  final ProjectBook? projects;

  /// 할 일을 기억해 두는 곳
  final TodoBook? todos;

  /// 이동시간을 기억해 두는 곳
  final TravelBook? travel;

  final CalendarStore? store;

  /// false 면 "지금" 시각을 주기적으로 갱신하지 않아요(테스트용).
  final bool ticking;

  @override
  State<YeobaekApp> createState() => _YeobaekAppState();
}

class _YeobaekAppState extends State<YeobaekApp> with WidgetsBindingObserver {
  late final CalendarStore _store;
  late final bool _owned;

  @override
  void initState() {
    super.initState();
    _owned = widget.store == null;
    _store = widget.store ?? CalendarStore(DeviceRepo(), colors: widget.colors, projects: widget.projects, todos: widget.todos, travel: widget.travel);
    WidgetsBinding.instance.addObserver(this);
    _store.init();
    if (widget.ticking) _store.startClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
