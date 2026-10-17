import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// يحفظ الإعدادات في ملف JSON صغير داخل مجلد التطبيق (بدون حزم إضافية)
class SettingsService {
  static const String _fileName = 'quickstudy_settings.json';

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
      return {}; // ملف تالف: نرجع للإعدادات الافتراضية
    }
  }

  Future<void> write(Map<String, Object?> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data), flush: true);
  }
}
