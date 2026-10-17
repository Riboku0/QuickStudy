import 'package:flutter/foundation.dart';

import '../../../domain/models/subject.dart';
import '../../../utils/result.dart';
import '../../services/database_service.dart';
import '../lecture/lecture_repository.dart';

// المواد وشباترها في SQLite. يستمع للمكتبة: حذف ملف يحذف شابتره.
class SubjectRepository extends ChangeNotifier {
  SubjectRepository({
    required DatabaseService database,
    required LectureRepository lectures,
  })  : _database = database,
        _lectures = lectures {
    _lectures.addListener(_onLecturesChanged);
  }

  final DatabaseService _database;
  final LectureRepository _lectures;

  List<Subject> _subjects = const [];
  List<Chapter> _chapters = const [];
  bool _loaded = false;
  int _lectureCount = -1;

  List<Subject> get subjects => _subjects;
  bool get isLoaded => _loaded;

  Subject? subject(int id) {
    for (final s in _subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  // بالترتيب الذي اختاره المستخدم
  List<Chapter> chaptersOf(int subjectId) =>
      _chapters.where((c) => c.subjectId == subjectId).toList();

  int chapterCount(int subjectId) =>
      _chapters.where((c) => c.subjectId == subjectId).length;

  // الملفات الموجودة في مادة (لا تظهر عند الإضافة لمادة أخرى)
  Set<int> get assignedLectureIds => {for (final c in _chapters) c.lectureId};

  void _onLecturesChanged() {
    // الحذف من المكتبة يحذف الشابتر في قاعدة البيانات، فنعيد القراءة
    final count = _lectures.lectures.length;
    if (_loaded && count < _lectureCount) load();
    _lectureCount = count;
  }

  Future<Result<void>> load() async {
    try {
      final subjects = await _database.getSubjects();
      final chapters = await _database.getChapters();
      _subjects = List.unmodifiable(subjects.map(Subject.fromMap));
      _chapters = List.unmodifiable(chapters.map(Chapter.fromMap));
      _loaded = true;
      _lectureCount = _lectures.lectures.length;
      notifyListeners();
      return const Result.ok(null);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  Future<Result<int>> createSubject(String name, int color) =>
      _run(() => _database.insertSubject(name: name.trim(), color: color));

  Future<Result<void>> updateSubject(int id, String name, int color) =>
      _run(() => _database.updateSubject(id, name: name.trim(), color: color));

  Future<Result<void>> deleteSubject(int id) =>
      _run(() => _database.deleteSubject(id));

  Future<Result<void>> addChapters(int subjectId, List<int> lectureIds) {
    final taken = assignedLectureIds;
    final fresh = [
      for (final id in lectureIds)
        if (!taken.contains(id)) id,
    ];
    if (fresh.isEmpty) return Future.value(const Result.ok(null));

    final last = chaptersOf(subjectId);
    final firstOrder = last.isEmpty ? 0 : last.last.sortOrder + 1;
    return _run(() => _database.insertChapters(subjectId, fresh, firstOrder));
  }

  Future<Result<void>> renameChapter(int id, String title) {
    final clean = title.trim();
    return _run(() => _database.renameChapter(id, clean.isEmpty ? null : clean));
  }

  Future<Result<void>> removeChapter(int id) =>
      _run(() => _database.deleteChapter(id));

  // الترتيب يتغير فورًا في الواجهة ثم يُحفظ
  Future<Result<void>> reorder(int subjectId, List<int> orderedIds) {
    final others = _chapters.where((c) => c.subjectId != subjectId);
    final byId = {for (final c in chaptersOf(subjectId)) c.id: c};
    _chapters = List.unmodifiable([
      ...others,
      for (final (i, id) in orderedIds.indexed)
        if (byId[id] case final c?)
          Chapter(
            id: c.id,
            subjectId: c.subjectId,
            lectureId: c.lectureId,
            title: c.title,
            sortOrder: i,
          ),
    ]);
    notifyListeners();
    return _run(() => _database.reorderChapters(orderedIds));
  }

  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    try {
      final value = await action();
      final reload = await load();
      if (reload is Err<void>) return Result.error(reload.error);
      return Result.ok(value);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  @override
  void dispose() {
    _lectures.removeListener(_onLecturesChanged);
    super.dispose();
  }
}
