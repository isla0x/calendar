import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'event_tile.dart';
import 'nav.dart';

/// 일정 검색: 앞뒤 1년 안에서 제목·장소로 찾아요.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctl = TextEditingController();
  List<Ev> _all = const <Ev>[];
  bool _loading = true;
  bool _failed = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = StoreScope.read(context);
    final t = store.today;
    try {
      final list = await store.eventsBetween(
        DateTime(t.year - 1, t.month, t.day),
        DateTime(t.year + 1, t.month, t.day),
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  List<Ev> get _results {
    final k = _q.trim().toLowerCase();
    if (k.isEmpty) return const <Ev>[];
    final out = _all.where((e) {
      if (e.title.toLowerCase().contains(k)) return true;
      final loc = e.location;
      return loc != null && loc.toLowerCase().contains(k);
    }).toList();
    return out.length > 200 ? out.sublist(0, 200) : out;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final results = _results;

    Widget body;
    if (_loading) {
      body = Center(child: Text('불러오는 중…', style: ts(context, 14, color: p.muted)));
    } else if (_failed) {
      body = Center(child: Text('일정을 불러오지 못했어요', style: ts(context, 14, color: p.muted)));
    } else if (_q.trim().isEmpty) {
      body = Center(
        child: Text(
          '제목이나 장소로 찾아요\n(앞뒤 1년 안의 일정)',
          textAlign: TextAlign.center,
          style: ts(context, 14, color: p.muted, height: 1.6),
        ),
      );
    } else if (results.isEmpty) {
      body = Center(child: Text('찾는 일정이 없어요', style: ts(context, 14, color: p.muted)));
    } else {
      body = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
        children: [
          for (final e in results)
            EventTile(
              event: e,
              showDate: true,
              onTap: () {
                StoreScope.of(context).select(e.start);
                openDetail(context, e);
              },
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 4, 16, 8),
            child: Row(
              children: [
                Tap(
                  onTap: () => Navigator.of(context).pop(),
                  label: '뒤로',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.chevron_left_rounded, size: 30, color: p.ink),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.soft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _ctl,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            cursorColor: p.ink,
                            onChanged: (v) => setState(() => _q = v),
                            style: ts(context, 16, weight: FontWeight.w500),
                            decoration: InputDecoration.collapsed(
                              hintText: '일정 검색',
                              hintStyle: ts(context, 16, weight: FontWeight.w500, color: p.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
