import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/reader_settings.dart';
import '../../services/reader_settings_service.dart';

// مصدر واحد لإعدادات العارض. التغيير يظهر فورًا، والحفظ بعده.
class ReaderSettingsRepository extends ChangeNotifier {
  ReaderSettingsRepository({required ReaderSettingsService service})
      : _service = service;

  final ReaderSettingsService _service;

  ReaderSettings _settings = ReaderSettings.defaults;
  Timer? _saveTimer;

  ReaderSettings get settings => _settings;

  Future<void> load() async {
    _settings = ReaderSettings.fromMap(await _service.read());
    notifyListeners();
  }

  void update(ReaderSettings value) {
    _settings = value;
    notifyListeners();
    // شريط السطوع يرسل قيمًا كثيرة، فنجمع الحفظ في كتابة واحدة
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  void reset() => update(ReaderSettings.defaults);

  Future<void> _save() async {
    try {
      await _service.write(_settings.toMap());
    } catch (_) {
      // فشل الحفظ لا يمنع استخدام الإعداد في هذه الجلسة
    }
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    super.dispose();
  }
}
