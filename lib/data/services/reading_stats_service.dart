import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// يحفظ وقت القراءة في ملف JSON صغير:
// { "days": { "2026-10-19": ثوانٍ }, "sessions": عدد مرات فتح الكتب }
class ReadingStatsService {
  static const String _fileName = 'quickstudy_stats.json';

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
      return {}; // ملف تالف: نبدأ من جديد
    }
  }

  Future<void> write(Map<String, Object?> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data), flush: true);
  }
}
