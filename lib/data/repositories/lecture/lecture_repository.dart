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

  // origin: المكتبة أو المذاكرة. التكرار يُفحص داخل المكان نفسه فقط.
  // ids: يُملأ بأرقام الملفات الجديدة (لربطها بمادة بعد الرفع)
  Future<Result<ImportSummary>> importFiles(
    List<SelectedFile> files, {
    LectureOrigin origin = LectureOrigin.library,
    List<int>? ids,
  });

  Future<Result<void>> delete(Lecture lecture);

  // تصنيف كتاب المكتبة، أو null لإزالته
  Future<Result<void>> setCategory(Lecture lecture, String? category);
}
