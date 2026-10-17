import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// يحفظ العلامات المرجعية في ملف JSON صغير داخل مجلد التطبيق
class BookmarkService {
  static const String _fileName = 'quickstudy_bookmarks.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<Object?>> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final data = jsonDecode(await file.readAsString());
      return data is List ? data : const [];
    } catch (_) {
      return const []; // ملف تالف: نبدأ بقائمة فارغة
    }
  }

  Future<void> write(List<Map<String, Object?>> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data), flush: true);
  }
}
