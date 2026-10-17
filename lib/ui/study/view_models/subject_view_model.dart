import 'package:flutter/foundation.dart';

import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/repositories/subjects/subject_repository.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../domain/models/lecture.dart';
import '../../../domain/models/reading_progress.dart';
import '../../../domain/models/subject.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

// شابتر مع ملفه (للعرض)
typedef ChapterItem = ({Chapter chapter, Lecture lecture});

// منطق صفحة المادة: شباترها، وإضافتها من الملفات أو برفع جديد
class SubjectViewModel extends ChangeNotifier {
  SubjectViewModel({
    required this.subjectId,
    required SubjectRepository subjects,
    required LectureRepository lectures,
    required ReadingProgressRepository progress,
    required FilePickerService picker,
  })  : _subjects = subjects,
        _lectures = lectures,
        _progress = progress,
        _picker = picker {
    _subjects.addListener(notifyListeners);
    _lectures.addListener(notifyListeners);
    _progress.addListener(notifyListeners);
    addExisting = Command1<void, int>(_addExisting);
    uploadNew = Command0<ImportSummary>(_uploadNew);
    rename = Command1<void, (Chapter, String)>(_rename);
    remove = Command1<void, Chapter>(_remove);
    updateSubject = Command1<void, (String, int)>(_updateSubject);
    deleteSubject = Command0<void>(_deleteSubject);
  }

  final int subjectId;
  final SubjectRepository _subjects;
  final LectureRepository _lectures;
  final ReadingProgressRepository _progress;
  final FilePickerService _picker;

  late final Command1<void, int> addExisting;
  late final Command0<ImportSummary> uploadNew;
  late final Command1<void, (Chapter, String)> rename;
  late final Command1<void, Chapter> remove;
  late final Command1<void, (String, int)> updateSubject;
  late final Command0<void> deleteSubject;

  Subject? get subject => _subjects.subject(subjectId);

  ReadingProgress? progressFor(Lecture lecture) =>
      _progress.progressFor(lecture.id);

  List<ChapterItem> get chapters {
    final byId = {for (final l in _lectures.lectures) l.id: l};
    return [
      for (final c in _subjects.chaptersOf(subjectId))
        if (byId[c.lectureId] case final lecture?) (chapter: c, lecture: lecture),
    ];
  }

  // ملفات PDF التي ليست في أي مادة
  List<Lecture> get availablePdfs {
    final taken = _subjects.assignedLectureIds;
    return [
      for (final l in _lectures.lectures)
        if (l.isPdf && l.exists && !taken.contains(l.id)) l,
    ];
  }

  void reorder(int oldIndex, int newIndex) {
    final ids = [for (final item in chapters) item.chapter.id];
    if (newIndex > oldIndex) newIndex--;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _subjects.reorder(subjectId, ids);
  }

  Future<Result<void>> _addExisting(int lectureId) =>
      _subjects.addChapters(subjectId, [lectureId]);

  Future<Result<ImportSummary>> _uploadNew() async {
    try {
      final picked =
          await _picker.pickLectureFiles(extensions: FilePickerService.pdfOnly);
      if (picked.isEmpty) return const Result.ok(ImportSummary.none);

      final imported = await _lectures.importFiles(picked);
      if (imported is Err<ImportSummary>) return imported;

      // الجديدة والمكررة (موجودة في الملفات بنفس الاسم) تدخل المادة إن لم تكن في مادة
      final names = {for (final f in picked) f.name};
      final taken = _subjects.assignedLectureIds;
      final ids = [
        for (final l in _lectures.lectures.reversed)
          if (l.isPdf && names.contains(l.name) && !taken.contains(l.id)) l.id,
      ];
      final added = await _subjects.addChapters(subjectId, ids);
      if (added is Err<void>) return Result.error(added.error);

      return imported;
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  Future<Result<void>> _rename((Chapter, String) input) =>
      _subjects.renameChapter(input.$1.id, input.$2);

  Future<Result<void>> _remove(Chapter chapter) =>
      _subjects.removeChapter(chapter.id);

  Future<Result<void>> _updateSubject((String, int) input) =>
      _subjects.updateSubject(subjectId, input.$1, input.$2);

  Future<Result<void>> _deleteSubject() => _subjects.deleteSubject(subjectId);

  @override
  void dispose() {
    _subjects.removeListener(notifyListeners);
    _lectures.removeListener(notifyListeners);
    _progress.removeListener(notifyListeners);
    addExisting.dispose();
    uploadNew.dispose();
    rename.dispose();
    remove.dispose();
    updateSubject.dispose();
    deleteSubject.dispose();
    super.dispose();
  }
}
