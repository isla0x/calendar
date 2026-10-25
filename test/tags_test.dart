import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/tags.dart';

void main() {
  test('splitTags: 제목 끝의 #태그를 떼어내요', () {
    final p = splitTags('치과 #건강 #병원');
    expect(p.title, '치과');
    expect(p.tags, ['건강', '병원']);
  });

  test('splitTags: 태그가 없거나 태그만 있으면 그대로', () {
    expect(splitTags('치과').title, '치과');
    expect(splitTags('치과').tags, isEmpty);
    final only = splitTags('#회의');
    expect(only.title, '#회의');
    expect(only.tags, isEmpty);
  });

  test('splitTags: 글자 뒤의 #는 태그가 아니에요', () {
    final p = splitTags('C# 공부');
    expect(p.title, 'C# 공부');
    expect(p.tags, isEmpty);
  });

  test('joinTags 와 splitTags 는 서로 되돌려져요', () {
    final raw = joinTags('주간 회의', ['업무', '정기']);
    expect(raw, '주간 회의 #업무 #정기');
    final p = splitTags(raw);
    expect(p.title, '주간 회의');
    expect(p.tags, ['업무', '정기']);
    expect(joinTags('치과', const []), '치과');
  });

  test('tagsFromText: 띄어쓰기·쉼표·# 모두 받아요', () {
    expect(tagsFromText('#회의, 건강 회의  #운동'), ['회의', '건강', '운동']);
    expect(tagsFromText('  '), isEmpty);
    expect(tagsFromText('a-b'), ['ab']);
  });

  test('tagColor: 같은 태그는 항상 같은 색', () {
    expect(tagColor('건강', dark: false), tagColor('건강', dark: false));
    expect(tagColor('건강', dark: false) == tagColor('건강', dark: true), false);
  });
}
