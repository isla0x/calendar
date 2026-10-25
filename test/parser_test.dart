import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/parser.dart';

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
}
