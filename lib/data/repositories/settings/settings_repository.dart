import 'package:flutter/foundation.dart';

import '../../services/settings_service.dart';

enum AppThemeChoice { system, light, dark }

enum AppLanguageChoice { system, english, arabic }

// مصدر واحد لإعدادات المظهر واللغة.
// التطبيق كله يستمع إليه ويعيد البناء عند أي تغيير.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository({required SettingsService service}) : _service = service;

  final SettingsService _service;

  AppThemeChoice _theme = AppThemeChoice.system;
  AppLanguageChoice _language = AppLanguageChoice.system;
  bool _loaded = false;

  AppThemeChoice get theme => _theme;
  AppLanguageChoice get language => _language;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final data = await _service.read();
    _theme = _byName(AppThemeChoice.values, data['theme'], AppThemeChoice.system);
    _language = _byName(
      AppLanguageChoice.values,
      data['language'],
      AppLanguageChoice.system,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeChoice value) async {
    if (value == _theme) return;
    _theme = value;
    notifyListeners(); // التغيير يظهر فورًا، والحفظ بعده
    await _save();
  }

  Future<void> setLanguage(AppLanguageChoice value) async {
    if (value == _language) return;
    _language = value;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _service.write({'theme': _theme.name, 'language': _language.name});
    } catch (_) {
      // فشل الحفظ لا يمنع استخدام الإعداد في هذه الجلسة
    }
  }

  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
