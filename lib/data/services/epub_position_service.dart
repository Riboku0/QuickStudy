import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// مكان القراءة في كتب EPUB (CFI لكل كتاب) وحجم الخط، في quickstudy_epub.json:
// { "cfi": { "<lectureId>": "<cfi>" }, "fontSize": 18 }
class EpubPositionService {
  EpubPositionService._();

  static final EpubPositionService instance = EpubPositionService._();

  static const String _fileName = 'quickstudy_epub.json';

  Map<String, Object?>? _data;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Map<String, Object?>> _load() async {
    final cached = _data;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map<String, Object?>) return _data = data;
      }
    } catch (_) {
      // ملف تالف: نبدأ من جديد
    }
    return _data = {};
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(_data ?? {}), flush: true);
    } catch (_) {
      // فشل الحفظ لا يوقف القراءة
    }
  }

  Future<String?> cfiFor(int lectureId) async {
    final cfi = (await _load())['cfi'];
    if (cfi is Map) {
      final value = cfi['$lectureId'];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> saveCfi(int lectureId, String cfi) async {
    final data = await _load();
    final map = Map<String, Object?>.from((data['cfi'] as Map?) ?? {});
    map['$lectureId'] = cfi;
    data['cfi'] = map;
    await _save();
  }

  Future<void> remove(int lectureId) async {
    final data = await _load();
    final map = Map<String, Object?>.from((data['cfi'] as Map?) ?? {});
    if (map.remove('$lectureId') == null) return;
    data['cfi'] = map;
    await _save();
  }

  Future<int> fontSize() async {
    final value = (await _load())['fontSize'];
    return value is int ? value : 18;
  }

  Future<void> saveFontSize(int size) async {
    final data = await _load();
    data['fontSize'] = size;
    await _save();
  }
}
