import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/parser.dart';
import 'package:yeobaek/models.dart';

void main() {
  // 2026-10-26 월요일 14:10
  final now = DateTime(2026, 10, 26, 14, 10);
  final today = DateTime(2026, 10, 26);

  QuickParse parse(String s, {DateTime? day}) =>
      parseQuick(s, now: now, defaultDay: day ?? today);

  test('내일 오후 3시 치과 30분', () {
    final q = parse('내일 오후 3시 치과 30분');
    expect(q.title, '치과');
    expect(q.start, DateTime(2026, 10, 27, 15, 0));
    expect(q.end, DateTime(2026, 10, 27, 15, 30));
    expect(q.allDay, false);
    expect(q.hasDate && q.hasTime && q.hasDuration, true);
    expect(q.hits.length, 3);
  });

  test('금요일 저녁 7시 회식 2시간', () {
    final q = parse('금요일 저녁 7시 회식 2시간');
    expect(q.title, '회식');
    expect(q.start, DateTime(2026, 10, 30, 19, 0));
    expect(q.end, DateTime(2026, 10, 30, 21, 0));
  });

  test('다음주 월요일 9:30 주간회의 (기본 1시간)', () {
    final q = parse('다음주 월요일 9:30 주간회의');
    expect(q.title, '주간회의');
    expect(q.start, DateTime(2026, 11, 2, 9, 30));
    expect(q.end, DateTime(2026, 11, 2, 10, 30));
    expect(q.hasDuration, false);
  });

  test('11월 3일 종일 휴가', () {
    final q = parse('11월 3일 종일 휴가');
    expect(q.title, '휴가');
    expect(q.allDay, true);
    expect(q.start, DateTime(2026, 11, 3));
    expect(q.end, DateTime(2026, 11, 4));
  });

  test('3시~5시 스터디 (보고 있는 날 기준)', () {
    final q = parse('3시~5시 스터디', day: DateTime(2026, 10, 29));
    expect(q.title, '스터디');
    expect(q.start, DateTime(2026, 10, 29, 15, 0));
    expect(q.end, DateTime(2026, 10, 29, 17, 0));
    expect(q.hasDate, false);
    expect(q.hasDuration, true);
  });

  test('시간·날짜 없이 제목만이면 종일', () {
    final q = parse('치과');
    expect(q.title, '치과');
    expect(q.allDay, true);
    expect(q.start, today);
    expect(q.hits, isEmpty);
  });

  test('모레 오전 9시 반 병원', () {
    final q = parse('모레 오전 9시 반 병원');
    expect(q.title, '병원');
    expect(q.start, DateTime(2026, 10, 28, 9, 30));
  });

  test('길이만 쓰면 오늘은 다음 15분부터', () {
    final q = parse('운동 1시간 30분');
    expect(q.title, '운동');
    expect(q.allDay, false);
    expect(q.start, DateTime(2026, 10, 26, 14, 15));
    expect(q.end, DateTime(2026, 10, 26, 15, 45));
  });

  test('시각 뒤의 분은 시각, 따로 쓴 분은 길이', () {
    final q = parse('내일 오후 2시 30분 면접 45분');
    expect(q.title, '면접');
    expect(q.start, DateTime(2026, 10, 27, 14, 30));
    expect(q.end, DateTime(2026, 10, 27, 15, 15));
  });

  test('오전/오후 없는 시각은 낮 시간으로', () {
    expect(parse('7시 저녁').start.hour, 19);
    expect(parse('10시 회의').start.hour, 10);
    expect(parse('12시 점심').start.hour, 12);
    expect(parse('15:20 미팅').start.hour, 15);
  });

  test('범위: 오후 3시~5시, 9시~6시, 10시~1시', () {
    var q = parse('오후 3시~5시 회의');
    expect(q.start.hour, 15);
    expect(q.end.hour, 17);
    q = parse('9시~6시 근무');
    expect(q.start.hour, 9);
    expect(q.end.hour, 18);
    q = parse('10시~1시 행사');
    expect(q.start.hour, 10);
    expect(q.end.hour, 13);
  });

  test('3일 후, 2주 뒤, 다다음주 수요일', () {
    expect(parse('3일 후 점검').start, DateTime(2026, 10, 29));
    expect(parse('2주 뒤 검진').start, DateTime(2026, 11, 9));
    expect(parse('다다음주 수요일 회의').start, DateTime(2026, 11, 11));
  });

  test('날짜가 지난 월/일은 내년으로', () {
    final q = parse('3월 5일 시험');
    expect(q.start, DateTime(2027, 3, 5));
  });

  test('연도를 쓰면 그대로', () {
    final q = parse('2026년 10월 3일 개천절');
    expect(q.start, DateTime(2026, 10, 3));
  });

  test('한글 숫자 시각 / 영어 am pm', () {
    expect(parse('세시 상담').start.hour, 15);
    expect(parse('내일 3pm 콜').start, DateTime(2026, 10, 27, 15, 0));
    expect(parse('내일 9:30am 콜').start, DateTime(2026, 10, 27, 9, 30));
  });

  test('"오늘의 할일" 처럼 날짜가 아닌 말은 제목으로 남아요', () {
    final q = parse('오늘의 할일');
    expect(q.title, '오늘의 할일');
    expect(q.hasDate, false);
  });

  test('rewriteHits: 날짜만 바꾸기 / 없으면 끝에 붙이기', () {
    final q = parse('치과 내일 3시');
    final t = rewriteHits('치과 내일 3시', q.hits, {HitKind.date}, '10월 28일');
    expect(t, '치과 10월 28일 3시');
    final u = rewriteHits('치과', parse('치과').hits, {HitKind.date}, '10월 28일');
    expect(u, '치과 10월 28일');
    final v = rewriteHits('', const <Hit>[], {HitKind.time}, '종일');
    expect(v, '종일');
  });

  test('칩으로 고친 글을 다시 읽어도 같은 값', () {
    final q = parse('치과 10월 28일 오후 4시 30분, 45분');
    expect(q.title, '치과');
    expect(q.start, DateTime(2026, 10, 28, 16, 30));
    expect(q.end, DateTime(2026, 10, 28, 17, 15));
  });

  group('기간', () {
    void expectRange(QuickParse q, DateTime a, DateTime b) {
      expect(q.isRange, true);
      expect(q.allDay, true);
      expect(q.start, a);
      expect(q.lastDay, b);
      expect(q.end, DateTime(b.year, b.month, b.day + 1));
      expect(q.hits.where((h) => h.kind == HitKind.date).length, 1);
    }

    test('9/18~10/28 프로젝트 (최근에 시작한 기간은 올해로)', () {
      final q = parse('9/18~10/28 프로젝트');
      expect(q.title, '프로젝트');
      expectRange(q, DateTime(2026, 9, 18), DateTime(2026, 10, 28));
    });

    test('26.09.18~26.10.28 프로젝트', () {
      final q = parse('26.09.18~26.10.28 프로젝트');
      expect(q.title, '프로젝트');
      expectRange(q, DateTime(2026, 9, 18), DateTime(2026, 10, 28));
    });

    test('2026.9.18~2026.10.28 프로젝트', () {
      final q = parse('프로젝트 2026.9.18~2026.10.28');
      expect(q.title, '프로젝트');
      expectRange(q, DateTime(2026, 9, 18), DateTime(2026, 10, 28));
    });

    test('9월 18일부터 10월 28일까지 프로젝트', () {
      final q = parse('9월 18일부터 10월 28일까지 프로젝트');
      expect(q.title, '프로젝트');
      expectRange(q, DateTime(2026, 9, 18), DateTime(2026, 10, 28));
    });

    test('내일~모레 출장', () {
      final q = parse('내일~모레 출장');
      expect(q.title, '출장');
      expectRange(q, DateTime(2026, 10, 27), DateTime(2026, 10, 28));
    });

    test('먼 과거 같은 날짜는 내년으로, 끝이 더 이르면 다음 해로', () {
      var q = parse('3월 5일~3월 7일 시험');
      expectRange(q, DateTime(2027, 3, 5), DateTime(2027, 3, 7));
      q = parse('12/30~1/2 연말');
      expectRange(q, DateTime(2026, 12, 30), DateTime(2027, 1, 2));
    });

    test('범위가 아닌 것: 날짜 하나, 시간 범위, 제목 속 하이픈', () {
      expect(parse('10월 28일 3시 회의').isRange, false);
      expect(parse('3시~5시 스터디').isRange, false);
      final q = parse('내일 - 회의');
      expect(q.isRange, false);
      expect(q.title, '회의');
    });

    test('칩으로 날짜를 바꿀 때 기간 전체가 한 번에 바뀌어요', () {
      final q = parse('프로젝트 9/18~10/28');
      final t = rewriteHits('프로젝트 9/18~10/28', q.hits, {HitKind.date}, '10월 1일');
      expect(t, '프로젝트 10월 1일');
    });
  });

  group('태그', () {
    test('#태그는 제목에서 빠지고 따로 읽혀요', () {
      final q = parse('치과 #건강 #병원 내일 3시');
      expect(q.title, '치과');
      expect(q.tags, ['건강', '병원']);
      expect(q.start, DateTime(2026, 10, 27, 15, 0));
      expect(q.hits.where((h) => h.kind == HitKind.tag).length, 2);
    });

    test('태그 속 숫자는 시간·날짜로 읽지 않아요', () {
      final q = parse('#2024목표 #3시 회의');
      expect(q.title, '회의');
      expect(q.tags, ['2024목표', '3시']);
      expect(q.hasTime, false);
      expect(q.hasDate, false);
    });

    test('같은 태그는 한 번만, 태그만 써도 돼요', () {
      expect(parse('회의 #일 #일').tags, ['일']);
      final q = parse('#회의');
      expect(q.title, '');
      expect(q.tags, ['회의']);
    });

    test('# 앞에 글자가 붙어 있으면 태그가 아니에요', () {
      final q = parse('C# 공부');
      expect(q.tags, isEmpty);
      expect(q.title, 'C# 공부');
    });
  });

  group('붙여 쓴 날짜', () {
    test('261030 20:00 → 2026-10-30 20:00', () {
      final q = parse('261030 20:00');
      expect(q.start, DateTime(2026, 10, 30, 20, 0));
      expect(q.title, '');
    });

    test('20261030 회의 / 261030~261105 출장', () {
      expect(parse('20261030 회의').start.day, 30);
      final q = parse('261030~261105 출장');
      expect(q.title, '출장');
      expect(q.start, DateTime(2026, 10, 30));
      expect(q.lastDay, DateTime(2026, 11, 5));
    });

    test('날짜가 될 수 없는 숫자는 그대로 둬요', () {
      expect(parse('주문 269999').hasDate, false);
    });
  });

  group('반복', () {
    test('10/26~11/13 09:00-18:00 프로젝트 → 매일 반복', () {
      final q = parse('10/26~11/13 09:00-18:00 교보증권 프로젝트');
      expect(q.title, '교보증권 프로젝트');
      expect(q.repeat, RepeatKind.daily);
      expect(q.isRange, false);
      expect(q.allDay, false);
      expect(q.start, DateTime(2026, 10, 26, 9, 0));
      expect(q.end, DateTime(2026, 10, 26, 18, 0));
      expect(q.lastDay, DateTime(2026, 11, 13));
      expect(q.repeatRule?.until, DateTime(2026, 11, 13));
    });

    test('24시간제 08:00-17:00 은 오전 8시~오후 5시', () {
      final q = parse('261030 08:00-17:00 교보증권');
      expect(q.title, '교보증권');
      expect(q.start, DateTime(2026, 10, 30, 8, 0));
      expect(q.end, DateTime(2026, 10, 30, 17, 0));
    });

    test('09:00-17:00, 8:00-17:00, 단독 08:00 도 24시간제', () {
      final a = parse('내일 09:00-17:00 근무');
      expect(a.start.hour, 9);
      expect(a.end.hour, 17);
      final b = parse('내일 8:00-17:00 근무');
      expect(b.start.hour, 8);
      expect(b.end.hour, 17);
      final c = parse('내일 08:00 회의');
      expect(c.start.hour, 8);
      expect(parse('내일 8:00 회의').start.hour, 20);
    });

    test('매일 9시~6시 운동', () {
      final q = parse('매일 오전 9시 운동');
      expect(q.title, '운동');
      expect(q.repeat, RepeatKind.daily);
      expect(q.start.hour, 9);
      expect(q.lastDay, isNull);
    });

    test('평일마다 / 매주', () {
      expect(parse('평일마다 7시 러닝').repeat, RepeatKind.weekdays);
      expect(parse('매주 월요일 10시 회의').repeat, RepeatKind.weekly);
    });

    test('시각 없는 기간은 반복이 아니라 종일 하루짜리', () {
      final q = parse('9/18~10/28 프로젝트');
      expect(q.repeat, isNull);
      expect(q.isRange, true);
    });

    test('반복 글을 지우면 다시 반복 없음', () {
      expect(parse('운동 3시').repeat, isNull);
    });
  });
}
