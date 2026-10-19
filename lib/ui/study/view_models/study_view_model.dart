import 'package:flutter/foundation.dart';

import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/repositories/settings/settings_repository.dart';
import '../../../data/repositories/subjects/subject_repository.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../domain/models/subject.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

// منطق صفحة Study: قائمة المواد وإنشاؤها وتعديلها وحذفها، وتقدم كل مادة
class StudyViewModel extends ChangeNotifier {
  StudyViewModel({
    required SubjectRepository subjects,
    required ReadingProgressRepository progress,
    required FilePickerService picker,
    required SettingsRepository settings,
  })  : _subjects = subjects,
        _progress = progress,
        _picker = picker,
        _settings = settings {
    _subjects.addListener(notifyListeners);
    _progress.addListener(notifyListeners);
    _settings.addListener(notifyListeners);
    create = Command1<int, SubjectDraft>(_create);
    update = Command1<void, (Subject, SubjectDraft)>(_update);
    delete = Command1<void, Subject>(_delete);
  }

  final SubjectRepository _subjects;
  final ReadingProgressRepository _progress;
  final FilePickerService _picker;
  final SettingsRepository _settings;

  late final Command1<int, SubjectDraft> create;
  late final Command1<void, (Subject, SubjectDraft)> update;
  late final Command1<void, Subject> delete;

  bool get isLoaded => _subjects.isLoaded;

  // اسم المستخدم للتحية (فارغ = "أهلًا" فقط)
  String get userName => _settings.userName;
  List<Subject> get subjects => _subjects.subjects;
  int chapterCount(Subject subject) => _subjects.chapterCount(subject.id);

  // متوسط تقدم القراءة في شباتر المادة (0..1). الشابتر غير المفتوح = 0
  double progressFor(Subject subject) {
    final chapters = _subjects.chaptersOf(subject.id);
    if (chapters.isEmpty) return 0;
    var sum = 0.0;
    for (final c in chapters) {
      final p = _progress.progressFor(c.lectureId);
      if (p == null || p.pageCount == 0) continue;
      sum += p.page >= p.pageCount ? 1 : p.fraction;
    }
    return sum / chapters.length;
  }

  // بطاقة الهدف: الشباتر المنتهية من كل المواد
  int get totalChapters =>
      subjects.fold(0, (sum, s) => sum + _subjects.chapterCount(s.id));

  int get finishedChapters {
    var n = 0;
    for (final subject in subjects) {
      for (final c in _subjects.chaptersOf(subject.id)) {
        final p = _progress.progressFor(c.lectureId);
        if (p != null && p.pageCount > 0 && p.page >= p.pageCount) n++;
      }
    }
    return n;
  }

  // صورة غلاف من الهاتف (للنافذة)
  Future<String?> pickCoverImage() => _picker.pickImage();

  Future<Result<int>> _create(SubjectDraft draft) =>
      _subjects.createSubject(draft);

  Future<Result<void>> _update((Subject, SubjectDraft) input) =>
      _subjects.updateSubject(input.$1.id, input.$2);

  Future<Result<void>> _delete(Subject subject) =>
      _subjects.deleteSubject(subject.id);

  @override
  void dispose() {
    _subjects.removeListener(notifyListeners);
    _progress.removeListener(notifyListeners);
    _settings.removeListener(notifyListeners);
    create.dispose();
    update.dispose();
    delete.dispose();
    super.dispose();
  }
}
