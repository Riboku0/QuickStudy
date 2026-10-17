import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// يحفظ إعدادات العارض في ملف JSON صغير داخل مجلد التطبيق
class ReaderSettingsService {
  static const String _fileName = 'quickstudy_reader.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Map<String, Object?>> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, Object?> ? data : {};
    } catch (_) {
      return {}; // ملف تالف: الإعدادات الافتراضية
    }
  }

  Future<void> write(Map<String, Object?> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data), flush: true);
  }
}
