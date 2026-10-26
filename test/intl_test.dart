import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/l10n.dart';
import 'package:yeobaek/l10n/en.dart';
import 'package:yeobaek/l10n/fr.dart';
import 'package:yeobaek/l10n/ja.dart';
import 'package:yeobaek/l10n/zh.dart';
import 'package:yeobaek/models.dart';
import 'package:yeobaek/parser.dart';
import 'package:yeobaek/todos.dart';

void main() {
  // 2026-10-26 월요일 14:10
  final now = DateTime(2026, 10, 26, 14, 10);
  final today = DateTime(2026, 10, 26);

  QuickParse parse(Lang lang, String s) {
    L10n.lang = lang;
    return parseQuick(s, now: now, defaultDay: today);
  }

  tearDown(() => L10n.lang = Lang.ko);

  group('번역표', () {
    test('네 언어의 키가 같아요', () {
      expect(kFr.keys.toSet(), kEn.keys.toSet());
      expect(kZh.keys.toSet(), kEn.keys.toSet());
      expect(kJa.keys.toSet(), kEn.keys.toSet());
    });

    test('자리표시자 {0} {1} 이 번역에도 그대로 있어요', () {
      final ph = RegExp(r'\{\d\}');
      for (final t in [kEn, kFr, kZh, kJa]) {
        t.forEach((ko, tr) {
          final a = ph.allMatches(ko).map((m) => m.group(0)).toSet();
          final b = ph.allMatches(tr).map((m) => m.group(0)).toSet();
          expect(b, a, reason: ko);
        });
      }
    });

    test('tl 은 없는 글이면 원문을 돌려줘요', () {
      L10n.lang = Lang.en;
      expect(tl('이건 번역표에 없는 글'), '이건 번역표에 없는 글');
      expect(tl('{0}분', [30]), '30 min');
    });

    test('폰 언어 고르기', () {
      expect(L10n.fromCode('fr'), Lang.fr);
      expect(L10n.fromCode('de'), Lang.en);
    });
  });

  group('영어', () {
    test('dentist tomorrow 3pm 30 min', () {
      final q = parse(Lang.en, 'dentist tomorrow 3pm 30 min');
      expect(q.title, 'dentist');
      expect(q.start, DateTime(2026, 10, 27, 15, 0));
      expect(q.end, DateTime(2026, 10, 27, 15, 30));
    });

    test('칩 색칠 자리가 원래 글을 가리켜요', () {
      const s = 'dentist tomorrow 3pm 30 min';
      final q = parse(Lang.en, s);
      final texts = {for (final h in q.hits) h.kind: s.substring(h.start, h.end).trim()};
      expect(texts[HitKind.date], 'tomorrow');
      expect(texts[HitKind.time], '3pm');
      expect(texts[HitKind.duration], '30 min');
    });

    test('Call mom on Oct 30 at 9:30 AM', () {
      final q = parse(Lang.en, 'Call mom on Oct 30 at 9:30 AM');
      expect(q.title, 'Call mom');
      expect(q.start, DateTime(2026, 10, 30, 9, 30));
    });

    test('Lunch Friday at noon for 1 hour', () {
      final q = parse(Lang.en, 'Lunch with Sam Friday at noon for 1 hour');
      expect(q.title, 'Lunch with Sam');
      expect(q.start, DateTime(2026, 10, 30, 12, 0));
      expect(q.end, DateTime(2026, 10, 30, 13, 0));
    });

    test('Standup every weekday 9am', () {
      final q = parse(Lang.en, 'Standup every weekday 9am');
      expect(q.title, 'Standup');
      expect(q.repeat, RepeatKind.weekdays);
      expect(q.start.hour, 9);
    });

    test('Submit report by Friday', () {
      final q = parse(Lang.en, 'Submit report by Friday');
      expect(q.title, 'Submit report');
      expect(q.start, DateTime(2026, 10, 30));
      expect(q.allDay, true);
    });

    test('앱이 넣어 주는 글을 다시 읽어도 같아요', () {
      final q = parse(Lang.en, 'Oct 27, 3 PM, 1 hr 30 min dentist');
      expect(q.start, DateTime(2026, 10, 27, 15, 0));
      expect(q.end, DateTime(2026, 10, 27, 16, 30));
      expect(q.title, 'dentist');
    });

    test('한국어로 써도 읽혀요', () {
      final q = parse(Lang.en, '내일 오후 3시 치과 30분');
      expect(q.title, '치과');
      expect(q.start, DateTime(2026, 10, 27, 15, 0));
    });
  });

  group('프랑스어', () {
    test('dentiste demain 15h30 30 min', () {
      final q = parse(Lang.fr, 'dentiste demain 15h30 30 min');
      expect(q.title, 'dentiste');
      expect(q.start, DateTime(2026, 10, 27, 15, 30));
      expect(q.end, DateTime(2026, 10, 27, 16, 0));
    });

    test('réunion vendredi 9h', () {
      final q = parse(Lang.fr, 'réunion vendredi 9h');
      expect(q.title, 'réunion');
      expect(q.start, DateTime(2026, 10, 30, 9, 0));
    });

    test('날짜는 일·월 순서: 5 nov 18h', () {
      final q = parse(Lang.fr, 'dîner 5 nov 18h');
      expect(q.start, DateTime(2026, 11, 5, 18, 0));
      expect(q.title, 'dîner');
    });

    test('앱이 넣어 주는 글을 다시 읽어도 같아요', () {
      final q = parse(Lang.fr, '27 oct., 15 h, 1 heure 30 min dentiste');
      expect(q.start, DateTime(2026, 10, 27, 15, 0));
      expect(q.end, DateTime(2026, 10, 27, 16, 30));
    });

    test('tous les jours', () {
      final q = parse(Lang.fr, 'sport tous les jours 7h');
      expect(q.repeat, RepeatKind.daily);
    });
  });

  group('중국어', () {
    test('明天下午3点开会1小时', () {
      final q = parse(Lang.zh, '明天下午3点开会1小时');
      expect(q.title, '开会');
      expect(q.start, DateTime(2026, 10, 27, 15, 0));
      expect(q.end, DateTime(2026, 10, 27, 16, 0));
    });

    test('周五晚上七点聚餐', () {
      final q = parse(Lang.zh, '周五晚上七点聚餐');
      expect(q.title, '聚餐');
      expect(q.start, DateTime(2026, 10, 30, 19, 0));
    });

    test('10月30日 9点半', () {
      final q = parse(Lang.zh, '10月30日 上午9点半 体检');
      expect(q.start, DateTime(2026, 10, 30, 9, 30));
      expect(q.title, '体检');
    });

    test('每天', () {
      final q = parse(Lang.zh, '每天早上7点跑步');
      expect(q.repeat, RepeatKind.daily);
      expect(q.start.hour, 7);
    });
  });

  group('일본어', () {
    test('来週の金曜日 午後3時 会議 1時間', () {
      final q = parse(Lang.ja, '来週の金曜日 午後3時 会議 1時間');
      expect(q.title, '会議');
      expect(q.start, DateTime(2026, 11, 6, 15, 0));
      expect(q.end, DateTime(2026, 11, 6, 16, 0));
    });

    test('明日 9:30 ミーティング', () {
      final q = parse(Lang.ja, '明日 09:30 ミーティング');
      expect(q.title, 'ミーティング');
      expect(q.start, DateTime(2026, 10, 27, 9, 30));
    });

    test('앱이 넣어 주는 글을 다시 읽어도 같아요', () {
      final q = parse(Lang.ja, '10月27日 午後3時30分 1時間30分 歯医者');
      expect(q.start, DateTime(2026, 10, 27, 15, 30));
      expect(q.end, DateTime(2026, 10, 27, 17, 0));
      expect(q.title, '歯医者');
    });

    test('毎日', () {
      final q = parse(Lang.ja, '毎日 朝7時 ランニング');
      expect(q.repeat, RepeatKind.daily);
      expect(q.start.hour, 7);
    });
  });

  group('할 일', () {
    TodoParse todo(Lang lang, String s) {
      L10n.lang = lang;
      return parseTodo(s, now: now);
    }

    test('영어: buy milk by Friday', () {
      final t = todo(Lang.en, 'buy milk by Friday');
      expect(t.title, 'buy milk');
      expect(t.due, DateTime(2026, 10, 30));
    });

    test('영어: gym 3 times a week', () {
      final t = todo(Lang.en, 'gym 3 times a week');
      expect(t.title, 'gym');
      expect(t.perWeek, 3);
    });

    test('일본어: いつか 本を読む', () {
      final t = todo(Lang.ja, 'いつか 本を読む');
      expect(t.someday, true);
    });

    test('중국어: 本周内 交报告', () {
      final t = todo(Lang.zh, '本周内 交报告');
      expect(t.due, isNotNull);
    });
  });
}
