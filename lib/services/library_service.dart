import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../models/lecture.dart';

// كل عمليات المكتبة في مكان واحد (تحميل + حذف)
abstract final class LibraryService {
  // كل الملفات من SQLite مع الحجم وهل الملف ما زال موجودًا
  static Future<List<Lecture>> loadLectures() async {
    final rows = await AppDatabase.getLectures();

    return Future.wait(
      rows.map((row) async {
        final lecture = Lecture.fromMap(row);
        final file = File(lecture.filePath);

        if (!await file.exists()) return lecture.copyWith(exists: false);

        return lecture.copyWith(size: await file.length());
      }),
    );
  }

  // حذف الملف من قاعدة البيانات ومن مجلد التطبيق مع ملاحظاته ونصه المعدّل.
  // الملف الأصلي في ذاكرة الهاتف لا يتأثر (التطبيق يحتفظ بنسخة خاصة به).
  static Future<void> deleteLecture(Lecture lecture) async {
    await AppDatabase.deleteLecture(lecture.id);

    final appDirectory = await getApplicationDocumentsDirectory();

    final related = [
      lecture.filePath,
      p.join(appDirectory.path, 'quickstudy_notes', '${lecture.id}_notes.json'),
      p.join(appDirectory.path, 'quickstudy_edits', '${lecture.id}_edited.txt'),
    ];

    for (final path in related) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
