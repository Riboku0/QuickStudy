import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/reading_progress.dart';
import '../../services/reading_progress_service.dart';

// مصدر واحد لتقدم القراءة. العارض يكتب فيه، وHome تقرأ منه.
class ReadingProgressRepository extends ChangeNotifier {
  ReadingProgressRepository({required ReadingProgressService service})
      : _service = service;

  final ReadingProgressService _service;

  Map<int, ReadingProgress> _items = {};
  bool _loaded = false;
  Timer? _saveTimer;

  bool get isLoaded => _loaded;

  ReadingProgress? progressFor(int lectureId) => _items[lectureId];

  // الأحدث فتحًا أولًا
  List<ReadingProgress> get recent {
    final list = _items.values.toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  Future<void> load() async {
    final data = await _service.read();
    final items = <int, ReadingProgress>{};
    for (final entry in data.entries) {
      final id = int.tryParse(entry.key);
      final value = entry.value;
      if (id == null || value is! Map<String, Object?>) continue;
      items[id] = ReadingProgress.fromMap(id, value);
    }
    _items = items;
    _loaded = true;
    notifyListeners();
  }

  // يُستدعى عند فتح الملف وعند كل تغيير صفحة
  void record(int lectureId, int page, int pageCount) {
    if (pageCount <= 0) return;
    _items = {
      ..._items,
      lectureId: ReadingProgress(
        lectureId: lectureId,
        page: page.clamp(1, pageCount).toInt(),
        pageCount: pageCount,
        openedAt: DateTime.now(),
      ),
    };
    // التمرير يغيّر الصفحة مرات كثيرة في الثانية (خصوصًا والصفحات مصغرة)،
    // وكل إشعار كان يعيد بناء المكتبة والرئيسية المخفيتين تحت العارض. القيمة
    // تتحدث فورًا، والإشعار مرة بعد أن يتوقف التغيير.
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 400), notifyListeners);
    _scheduleSave();
  }

  Timer? _notifyTimer;

  void remove(int lectureId) {
    if (!_items.containsKey(lectureId)) return;
    _items = {..._items}..remove(lectureId);
    notifyListeners();
    _scheduleSave();
  }

  // التمرير يغيّر الصفحة كثيرًا، فنجمع الحفظ في كتابة واحدة
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    try {
      await _service.write({
        for (final p in _items.values) '${p.lectureId}': p.toMap(),
      });
    } catch (_) {
      // فشل الحفظ لا يوقف القراءة
    }
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    super.dispose();
  }
}
