import 'package:flutter/foundation.dart';

import '../../../data/repositories/settings/settings_repository.dart';

// منطق صفحة الإعدادات: يقرأ ويغيّر المظهر واللغة عبر المستودع
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required SettingsRepository settings})
      : _settings = settings {
    _settings.addListener(notifyListeners);
  }

  final SettingsRepository _settings;

  AppThemeChoice get theme => _settings.theme;
  AppLanguageChoice get language => _settings.language;

  void setTheme(AppThemeChoice value) => _settings.setTheme(value);
  void setLanguage(AppLanguageChoice value) => _settings.setLanguage(value);

  @override
  void dispose() {
    _settings.removeListener(notifyListeners);
    super.dispose();
  }
}
