import 'package:flutter_test/flutter_test.dart';
import 'package:yeobaek/projects.dart';

void main() {
  final p = Project(
    id: 'p1',
    name: '교보증권 프로젝트',
    start: DateTime(2026, 10, 26),
    end: DateTime(2026, 11, 13),
    colorValue: 0xFF909FEA,
    checkpoints: [
      Checkpoint(id: 'a', title: '착수', date: DateTime(2026, 10, 26), done: true),
      Checkpoint(id: 'b', title: '중간 보고', date: DateTime(2026, 11, 6)),
      Checkpoint(id: 'c', title: '최종 보고', date: DateTime(2026, 11, 13)),
    ],
  );

  test('쉬는 요일(토·일)을 뺀 근무일을 세요', () {
    expect(p.totalDays, 15);
    expect(p.workDays.first, DateTime(2026, 10, 26));
    expect(p.workDays.any((d) => d.weekday >= 6), false);
  });

  test('오늘이 며칠째인지, 남은 날, D-day', () {
    final t = DateTime(2026, 10, 26);
    expect(p.statusOn(t), ProjectStatus.active);
    expect(p.dayNumber(t), 1);
    expect(p.remainingDays(t), 14);
    expect(p.dDay(t), 18);
    expect(p.dDayLabel(t), 'D-18');
    // 토요일에는 금요일까지 센 값 그대로예요.
    expect(p.dayNumber(DateTime(2026, 10, 31)), 5);
    expect(p.statusOn(DateTime(2026, 10, 25)), ProjectStatus.upcoming);
    expect(p.statusOn(DateTime(2026, 11, 14)), ProjectStatus.done);
    expect(p.progress(DateTime(2026, 11, 13)), 1.0);
  });

  test('다음 체크포인트는 끝나지 않은 가장 가까운 날이에요', () {
    expect(p.nextCheckpoint(DateTime(2026, 10, 26))?.title, '중간 보고');
    expect(p.nextCheckpoint(DateTime(2026, 11, 7))?.title, '최종 보고');
    expect(p.nextCheckpoint(DateTime(2026, 11, 14)), isNull);
  });

  test('저장했다가 다시 읽어도 같아요', () {
    final q = Project.fromJson(p.toJson())!;
    expect(q.name, p.name);
    expect(q.start, p.start);
    expect(q.end, p.end);
    expect(q.rest, {6, 7});
    expect(q.checkpoints.length, 3);
    expect(q.checkpoints.first.done, true);
    expect(Project.fromJson('이상한 값'), isNull);
  });
}
