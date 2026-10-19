import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/subject.dart';
import '../../../utils/result.dart';
import '../../services/database_service.dart';
import '../../services/file_storage_service.dart';
import '../lecture/lecture_repository.dart';

// المواد وشباترها في SQLite. يستمع للمكتبة: حذف ملف يحذف شابتره.
class SubjectRepository extends ChangeNotifier {
  SubjectRepository({
    required DatabaseService database,
    required LectureRepository lectures,
    required FileStorageService storage,
  })  : _database = database,
        _lectures = lectures,
        _storage = storage {
    _lectures.addListener(_onLecturesChanged);
  }

  final DatabaseService _database;
  final LectureRepository _lectures;
  final FileStorageService _storage;

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

  Chapter? chapter(int id) {
    for (final c in _chapters) {
      if (c.id == id) return c;
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

  Future<Result<int>> createSubject(SubjectDraft draft) => _run(() async {
        final cover = await _storeCover(draft.cover, previous: null);
        return _database.insertSubject(
          name: draft.name.trim(),
          icon: draft.icon,
          coverPath: cover,
        );
      });

  Future<Result<void>> updateSubject(int id, SubjectDraft draft) =>
      _run(() async {
        final cover = await _storeCover(
          draft.cover,
          previous: subject(id)?.coverPath,
        );
        await _database.updateSubject(
          id,
          name: draft.name.trim(),
          icon: draft.icon,
          coverPath: cover,
        );
      });

  // صورة جديدة تُنسخ لمجلد التطبيق، والقديمة تُحذف. نفس المسار = بلا تغيير.
  Future<String?> _storeCover(String? cover, {required String? previous}) async {
    if (cover == previous) return previous;
    final copied = cover == null
        ? null
        : await _storage.copyIntoApp(cover, 'cover_${p.basename(cover)}');
    if (previous != null) await _storage.deleteIfExists(previous);
    return copied;
  }

  // ملفات المذاكرة لا تعيش خارج موادها: حذف المادة يحذف ملفات شباترها وغلافها
  Future<Result<void>> deleteSubject(int id) async {
    final cover = subject(id)?.coverPath;
    final files = {for (final c in chaptersOf(id)) c.lectureId};
    for (final lecture in _lectures.lectures.toList()) {
      if (!files.contains(lecture.id)) continue;
      final deleted = await _lectures.delete(lecture);
      if (deleted is Err<void>) return deleted;
    }
    if (cover != null) await _storage.deleteIfExists(cover);
    return _run(() => _database.deleteSubject(id));
  }

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

  // إزالة الشابتر تحذف ملفه (وملاحظاته وتحديداته)، وقاعدة البيانات تحذف الشابتر معه
  Future<Result<void>> removeChapter(int id) async {
    final c = chapter(id);
    if (c == null) return const Result.ok(null);
    for (final lecture in _lectures.lectures) {
      if (lecture.id == c.lectureId) {
        final deleted = await _lectures.delete(lecture);
        if (deleted is Err<void>) return deleted;
        return load();
      }
    }
    return _run(() => _database.deleteChapter(id));
  }

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
