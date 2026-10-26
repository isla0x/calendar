import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../tags.dart';
import '../theme.dart';
import 'common.dart';
import 'event_tile.dart';
import 'nav.dart';
import '../l10n.dart';

/// 일정 검색: 앞뒤 1년 안에서 제목·장소·태그로 찾아요.
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
  String? _tag;

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

  /// 찾은 일정들에 붙은 태그 (많이 쓴 순)
  List<String> get _tags {
    final count = <String, int>{};
    for (final e in _all) {
      for (final t in e.tags) {
        count[t] = (count[t] ?? 0) + 1;
      }
    }
    final keys = count.keys.toList()
      ..sort((a, b) {
        final c = (count[b] ?? 0).compareTo(count[a] ?? 0);
        return c != 0 ? c : a.compareTo(b);
      });
    return keys.take(16).toList();
  }

  List<Ev> get _results {
    final raw = _q.trim().toLowerCase();
    final k = raw.startsWith('#') ? raw.substring(1) : raw;
    final tag = _tag;
    if (k.isEmpty && tag == null) return const <Ev>[];
    final out = _all.where((e) {
      if (tag != null && !e.tags.contains(tag)) return false;
      if (k.isEmpty) return true;
      if (e.title.toLowerCase().contains(k)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(k))) return true;
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
      body = Center(child: Text(tl('불러오는 중…'), style: ts(context, 14, color: p.muted)));
    } else if (_failed) {
      body = Center(child: Text(tl('일정을 불러오지 못했어요'), style: ts(context, 14, color: p.muted)));
    } else if (_q.trim().isEmpty && _tag == null) {
      body = Center(
        child: Text(
          tl('제목·장소·태그로 찾아요\n(앞뒤 1년 안의 일정)'),
          textAlign: TextAlign.center,
          style: ts(context, 14, color: p.muted, height: 1.6),
        ),
      );
    } else if (results.isEmpty) {
      body = Center(child: Text(tl('찾는 일정이 없어요'), style: ts(context, 14, color: p.muted)));
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
                openEvent(context, e);
              },
            ),
        ],
      );
    }

    final tags = _loading ? const <String>[] : _tags;

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
                  label: tl('뒤로'),
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
                              hintText: tl('일정 검색'),
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
          if (tags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = tags[i];
                  final on = _tag == t;
                  final col = tagColor(t, dark: p.dark);
                  return Tap(
                    onTap: () => setState(() => _tag = on ? null : t),
                    child: Pill(
                      height: 32,
                      ring: !on,
                      color: on ? Color.alphaBlend(col.withAlpha(44), p.surface) : null,
                      child: Text(
                        '#$t',
                        style: ts(context, 14, weight: FontWeight.w600, color: col),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
