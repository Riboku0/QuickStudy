import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// كل التعامل مع ملفات مجلد التطبيق في مكان واحد.
class FileStorageService {
  Future<Directory> _documents() => getApplicationDocumentsDirectory();

  // نسخ ملف من الهاتف إلى مجلد التطبيق (الأصل لا يتغير)
  Future<String> copyIntoApp(String sourcePath, String fileName) async {
    final directory = await _documents();
    final savedName =
        '${DateTime.now().microsecondsSinceEpoch}_${p.basename(fileName)}';
    final savedPath = p.join(directory.path, savedName);

    await File(sourcePath).copy(savedPath);
    return savedPath;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<int> sizeOf(String path) => File(path).length();

  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  // حذف نسخة الملف + ملاحظاته وتحديداته (العارض) + نصه المعدّل (المحرر)
  Future<void> deleteLectureData({
    required int lectureId,
    required String filePath,
  }) async {
    final directory = await _documents();

    await deleteIfExists(filePath);
    await deleteIfExists(
      p.join(directory.path, 'quickstudy_notes', '${lectureId}_notes.json'),
    );
    await deleteIfExists(
      p.join(directory.path, 'quickstudy_notes', '${lectureId}_marks.json'),
    );
    await deleteIfExists(
      p.join(directory.path, 'quickstudy_edits', '${lectureId}_edited.txt'),
    );
    // نتائج التعرف الضوئي للصفحات
    final ocr = Directory(p.join(directory.path, 'quickstudy_ocr', '$lectureId'));
    if (await ocr.exists()) await ocr.delete(recursive: true);
  }
}
