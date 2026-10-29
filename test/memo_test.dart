import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/demo_repo.dart';
import 'package:yeobaek/memos.dart';
import 'package:yeobaek/store.dart';

void main() {
  final now = DateTime(2026, 10, 29, 9);
  final today = DateTime(2026, 10, 29);

  CalendarStore make([MemoBook? book]) => CalendarStore(DemoRepo(clock: () => now), clock: () => now, memos: book);

  test('적은 글을 줄마다 나누고 빈 줄과 앞의 점은 버려요', () {
    expect(splitMemoLines('  세금계산서 보내기\n\n· 선물 고르기\r\n- 자료 확인  '), ['세금계산서 보내기', '선물 고르기', '자료 확인']);
    expect(splitMemoLines('   \n  '), isEmpty);
  });

  test('메모를 적으면 그 날에만 보이고, 누르면 줄이 그어져요', () async {
    final s = make();
    expect(await s.addMemos(today, '하나\n둘'), 2);
    expect(s.memosOn(today).map((m) => m.text), ['하나', '둘']);
    expect(s.memosOn(DateTime(2026, 10, 30)), isEmpty);
    expect(s.hasMemo(today), true);

    await s.toggleMemo(s.memosOn(today).first.id);
    expect(s.memosOn(today).first.done, true);
    expect(s.memosOn(today).last.done, false);
    await s.toggleMemo(s.memosOn(today).first.id);
    expect(s.memosOn(today).first.done, false);
  });

  test('고치면 날짜를 옮길 수 있고, 줄이 늘면 새 메모가 돼요', () async {
    final s = make();
    await s.addMemos(today, '처음 글');
    final m = s.memosOn(today).single;
    await s.editMemo(m, text: '바꾼 글\n덧붙인 글', day: DateTime(2026, 10, 31, 15));
    final moved = s.memosOn(DateTime(2026, 10, 31));
    expect(moved.map((x) => x.text), ['바꾼 글', '덧붙인 글']);
    expect(s.memosOn(today), isEmpty);
    // 빈 글로는 고쳐지지 않아요
    await s.editMemo(moved.first, text: '  ', day: today);
    expect(s.memosOn(DateTime(2026, 10, 31)).length, 2);
  });

  test('지우기, 그리고 모아보기는 최근 날짜가 먼저예요', () async {
    final s = make();
    await s.addMemos(DateTime(2026, 10, 20), '옛날');
    await s.addMemos(today, 'a\nb');
    await s.addMemos(DateTime(2026, 10, 27), '중간');
    expect(s.allMemos.map((m) => m.text), ['a', 'b', '중간', '옛날']);
    await s.removeMemo(s.allMemos.first.id);
    expect(s.allMemos.map((m) => m.text), ['b', '중간', '옛날']);
  });

  test('저장했다가 다시 읽어도 같고, 이상한 값은 건너뛰어요', () async {
    final book = MemoryMemoBook();
    final s = make(book);
    await s.addMemos(today, '남길 글');
    await s.toggleMemo(s.memosOn(today).single.id);
    final again = make(book);
    final m = again.memosOn(today).single;
    expect(m.text, '남길 글');
    expect(m.done, true);

    final j = m.toJson();
    expect(Memo.fromJson(j)!.day, today);
    expect(Memo.fromJson({'i': 'x', 'd': '2026-13-99-', 't': 'a'}), isNull);
    expect(Memo.fromJson({'i': 'x', 'd': '2026-10-29', 't': '  '}), isNull);
    expect(Memo.fromJson('이상한 값'), isNull);
  });
}
