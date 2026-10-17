import 'package:flutter/foundation.dart';

import '../../../domain/models/lecture.dart';
import '../../../utils/result.dart';
import '../../services/file_picker_service.dart';

// المصدر الوحيد لملفات المحاضرات في التطبيق.
// Home وLibrary يقرآن من هنا، وأي تغيير يُبلَّغ للجميع عبر notifyListeners.
abstract class LectureRepository extends ChangeNotifier {
  // الأحدث أولًا
  List<Lecture> get lectures;

  bool get isLoaded;

  Future<Result<void>> load();

  Future<Result<ImportSummary>> importFiles(List<SelectedFile> files);

  Future<Result<void>> delete(Lecture lecture);
}
