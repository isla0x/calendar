import 'package:flutter/material.dart';

import '../models.dart';
import '../projects.dart';
import 'detail_page.dart';
import 'project_pages.dart';
import 'quick_add_page.dart';
import 'search_page.dart';
import 'todo_pages.dart';

/// 화면 이동 모음
Future<void> openDetail(BuildContext context, Ev e) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => EventDetailPage(event: e)),
  );
}

/// [initialText] 를 넣으면 한 줄 입력 칸에 미리 적어둬요 (예: 비는 시간을 눌렀을 때)
/// [project] 를 넣으면 그 프로젝트 안에 일정을 추가해요.
Future<void> openQuickAdd(BuildContext context, {String initialText = '', Project? project}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => QuickAddPage(initialText: initialText, project: project),
    ),
  );
}

Future<void> openSearch(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const SearchPage()),
  );
}

Future<void> openProjects(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const ProjectListPage()),
  );
}

Future<void> openProject(BuildContext context, String id) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => ProjectDetailPage(projectId: id)),
  );
}

Future<void> openTodos(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const TodoListPage()),
  );
}
