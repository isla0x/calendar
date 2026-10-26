import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backup.dart';
import '../color_book.dart';
import '../pro.dart';
import '../projects.dart';
import '../store.dart';
import '../theme.dart';
import '../todos.dart';
import '../travel.dart';
import 'common.dart';
import 'sheets.dart';

/// PRO 표시 (작은 검은 알약)
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(11)),
      child: Text(
        'PRO',
        style: ts(context, 11, weight: FontWeight.w800, color: p.bg, letterSpacing: 0.3),
      ),
    );
  }
}

// ------------------------------------------------------------------ ⋯ 메뉴

Future<void> showMoreMenu(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (ctx) {
      final p = Pal.of(ctx);
      Widget row(IconData icon, String text, VoidCallback onTap, {bool pro = false}) => Tap(
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Icon(icon, size: 22, color: p.ink),
                  const SizedBox(width: 14),
                  Text(text, style: ts(ctx, 16, weight: FontWeight.w600)),
                  if (pro) ...[const SizedBox(width: 8), const ProBadge()],
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
                ],
              ),
            ),
          );
      return SheetFrame(
        title: '더보기',
        child: Column(
          children: [
            row(Icons.cloud_outlined, '백업 · 복원', () {
              Navigator.of(ctx).pop();
              openBackup(context);
            }, pro: true),
            row(Icons.info_outline_rounded, '사용 방법', () {
              Navigator.of(ctx).pop();
              showWelcomeSheet(context, first: false);
            }),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ 처음 안내

Future<void> showWelcomeSheet(BuildContext context, {required bool first}) async {
  final store = StoreScope.read(context);
  await showAppSheet<void>(
    context: context,
    builder: (ctx) {
      final p = Pal.of(ctx);
      Widget item(IconData icon, String t, String s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: p.soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: p.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t, style: ts(ctx, 16, weight: FontWeight.w700, height: 22 / 16)),
                      Text(s, style: ts(ctx, 13, color: p.muted, height: 19 / 13)),
                    ],
                  ),
                ),
              ],
            ),
          );
      return SheetFrame(
        title: '여백은 이렇게 써요',
        subtitle: '네 가지만 알면 돼요.',
        footer: Column(
          children: [
            BigButton(label: first ? '시작하기' : '닫기', onTap: () => Navigator.of(ctx).pop()),
            if (first) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '나중에 ⋯ → 사용 방법에서 다시 볼 수 있어요',
                  style: ts(ctx, 13, color: p.muted),
                ),
              ),
            ],
          ],
        ),
        child: Column(
          children: [
            item(Icons.short_text_rounded, '한 줄로 일정 쓰기', '"내일 3시 치과 1시간"처럼 쓰면 날짜·시간·길이를 알아서 읽어요.'),
            item(Icons.crop_free_rounded, '비는 시간 보기', '약속 사이의 빈틈이 점선 상자로 보여요. 눌러서 바로 추가해요.'),
            item(Icons.checklist_rounded, '할 일은 길이와 마감만', '"운동 1시간 주 2번"이라고 쓰고 자리 찾기를 누르면 빈 시간에 넣어줘요.'),
            item(Icons.flag_outlined, '기간이 있는 일은 프로젝트', '일정에서 "프로젝트" 칩을 켜면 진행 바와 D-day로 보여요.'),
          ],
        ),
      );
    },
  );
  if (first) await store.flags.setWelcomeSeen(true);
}

// ------------------------------------------------------------------ Pro

/// Pro 안내 창. Pro 가 되면 저절로 닫히고 true 를 돌려줘요.
Future<bool> showProSheet(BuildContext context) async {
  final store = StoreScope.read(context);
  unawaited_(store.pro.loadPrice());
  final r = await showAppSheet<bool>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: store.pro,
      builder: (ctx, _) {
        final p = Pal.of(ctx);
        final pro = store.pro;
        if (pro.isPro) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          });
        }
        return SheetFrame(
          title: '여백 Pro',
          action: const ProBadge(),
          subtitle: '기록이 날아갈 걱정 없이 쓰고 싶은 분을 위한 기능이에요.',
          footer: Column(
            children: [
              BigButton(
                label: pro.busy ? '잠시만요…' : (pro.price == null ? 'Pro 열기' : 'Pro 열기 · ${pro.price}'),
                onTap: pro.busy ? null : pro.buy,
              ),
              const SizedBox(height: 6),
              Tap(
                onTap: pro.busy ? null : pro.restore,
                child: SizedBox(
                  height: 40,
                  child: Center(
                    child: Text('구매 복원', style: ts(ctx, 14, weight: FontWeight.w600, color: p.muted)),
                  ),
                ),
              ),
              if (pro.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(pro.message!, style: ts(ctx, 13, color: p.red)),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final perk in kProPerks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded, size: 22, color: p.good),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(perk.$1, style: ts(ctx, 15, weight: FontWeight.w700)),
                            Text(perk.$2, style: ts(ctx, 13, color: p.muted, height: 18 / 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: Text.rich(
                  TextSpan(
                    style: ts(ctx, 13, color: p.muted, height: 19 / 13),
                    children: [
                      const TextSpan(text: '일정 보기, 한 줄 입력, 비는 시간, 프로젝트, 할 일, 이동시간은 '),
                      TextSpan(text: '계속 무료', style: ts(ctx, 13, weight: FontWeight.w700, color: p.ink)),
                      const TextSpan(text: '예요. 한 번만 결제하면 평생 쓸 수 있어요.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  return r == true || store.pro.isPro;
}

void unawaited_(Future<void> f) {}

// ------------------------------------------------------------------ 백업 · 복원

/// 백업 화면을 열어요. Pro 가 아니면 Pro 안내 창이 먼저 떠요.
Future<void> openBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  if (!store.pro.isPro) {
    final ok = await showProSheet(context);
    if (!ok || !context.mounted) return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const BackupPage()),
  );
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  SharedPreferences? _prefs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefs = p);
    }).catchError((_) {});
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _export() async {
    final prefs = _prefs;
    if (prefs == null || _busy) return;
    setState(() => _busy = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final text = await Backup.export(prefs);
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(text)),
        mimeType: 'application/json',
        name: 'yeobaek-backup.json',
      );
      await Share.shareXFiles(
        [file],
        fileNameOverrides: const ['yeobaek-backup.json'],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) _snack('내보내지 못했어요');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() async {
    final prefs = _prefs;
    if (prefs == null || _busy) return;
    final store = StoreScope.read(context);
    setState(() => _busy = true);
    try {
      final r = await FilePicker.platform.pickFiles(withData: true);
      final bytes = r?.files.single.bytes;
      if (bytes == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      final yes = await showConfirmSheet(
        context,
        title: '이 백업으로 되돌릴까요?',
        body: '지금 여백에 있는 색 · 프로젝트 · 할 일 · 이동시간이 백업의 것으로 바뀌어요.',
        yes: '되돌리기',
        no: '취소',
        danger: true,
      );
      if (!yes || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final sum = await Backup.import(prefs, utf8.decode(bytes, allowMalformed: true));
      if (sum == null) {
        if (mounted) _snack('여백 백업 파일이 아니에요');
      } else {
        await store.replaceBooks(
          colors: await PrefsColorBook.open(),
          projects: await PrefsProjectBook.open(),
          todos: await PrefsTodoBook.open(),
          travel: await PrefsTravelBook.open(),
        );
        if (mounted) {
          _snack('되돌렸어요 · 프로젝트 ${sum.projects}개 · 할 일 ${sum.todos}개');
        }
      }
    } catch (_) {
      if (mounted) _snack('가져오지 못했어요');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final sum = _prefs == null ? const BackupSummary() : Backup.summarize(_prefs!);

    Widget line(String t, String v, {bool last = false}) => Container(
          height: 50,
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: p.line)),
          ),
          child: Row(
            children: [
              Expanded(child: Text(t, style: ts(context, 15))),
              Text(v, style: ts(context, 14, color: p.muted)),
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 18, color: p.good),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 4, 8, 0),
            child: Row(
              children: [
                Tap(
                  onTap: () => Navigator.of(context).maybePop(),
                  label: '뒤로',
                  child: SizedBox(
                    width: 52,
                    height: 44,
                    child: Icon(Icons.chevron_left_rounded, size: 30, color: p.ink),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text('백업 · 복원', style: ts(context, 30, weight: FontWeight.w700, letterSpacing: -0.9)),
                        const SizedBox(width: 10),
                        const ProBadge(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      '일정은 아이폰 캘린더에 있어서 그대로예요.\n여백에서 따로 정한 것들만 백업해요.',
                      style: ts(context, 13, color: p.muted, height: 19 / 13),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: p.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('백업에 들어 있는 것', style: ts(context, 15, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        line('일정 색', '${sum.colors}개'),
                        line('프로젝트', '${sum.projects}개'),
                        line('할 일', '${sum.todos}개'),
                        line('이동시간', '${sum.travel}곳', last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  BigButton(label: '파일로 내보내기', onTap: _prefs == null || _busy ? null : _export),
                  const SizedBox(height: 10),
                  BigButton(label: '파일에서 가져오기', quiet: true, onTap: _prefs == null || _busy ? null : _import),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      '폰을 바꾸거나 앱을 다시 깔았다면\n저장해 둔 파일을 "가져오기"로 불러오세요.',
                      textAlign: TextAlign.center,
                      style: ts(context, 13, color: p.muted, height: 19 / 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
