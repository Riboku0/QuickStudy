import 'package:flutter/foundation.dart';

import '../../../data/repositories/subjects/subject_repository.dart';
import '../../../domain/models/subject.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

// منطق صفحة Study: قائمة المواد وإنشاؤها وتعديلها وحذفها
class StudyViewModel extends ChangeNotifier {
  StudyViewModel({required SubjectRepository subjects}) : _subjects = subjects {
    _subjects.addListener(notifyListeners);
    create = Command1<int, (String, int)>(_create);
    update = Command1<void, (Subject, String, int)>(_update);
    delete = Command1<void, Subject>(_delete);
  }

  final SubjectRepository _subjects;

  late final Command1<int, (String, int)> create;
  late final Command1<void, (Subject, String, int)> update;
  late final Command1<void, Subject> delete;

  bool get isLoaded => _subjects.isLoaded;
  List<Subject> get subjects => _subjects.subjects;
  int chapterCount(Subject subject) => _subjects.chapterCount(subject.id);

  // لون مقترح للمادة الجديدة: التالي في الترتيب
  int get suggestedColor => subjects.length;

  Future<Result<int>> _create((String, int) input) =>
      _subjects.createSubject(input.$1, input.$2);

  Future<Result<void>> _update((Subject, String, int) input) =>
      _subjects.updateSubject(input.$1.id, input.$2, input.$3);

  Future<Result<void>> _delete(Subject subject) =>
      _subjects.deleteSubject(subject.id);

  @override
  void dispose() {
    _subjects.removeListener(notifyListeners);
    create.dispose();
    update.dispose();
    delete.dispose();
    super.dispose();
  }
}
