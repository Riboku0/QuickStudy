import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/dependencies.dart';
import 'data/repositories/settings/settings_repository.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/shell/app_shell.dart';

void main() {
  runApp(
    MultiProvider(
      providers: appProviders,
      child: const QuickStudyApp(),
    ),
  );
}

// يطبّق إعدادات المظهر واللغة على كل التطبيق.
class QuickStudyApp extends StatefulWidget {
  const QuickStudyApp({super.key});

  @override
  State<QuickStudyApp> createState() => _QuickStudyAppState();
}

class _QuickStudyAppState extends State<QuickStudyApp>
    with WidgetsBindingObserver {
  late final SettingsRepository _settings;

  ThemeData? _theme;
  Brightness? _builtFor;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsRepository>();
    _settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // تغيّر وضع الهاتف (فاتح/داكن) أثناء فتح التطبيق
  @override
  void didChangePlatformBrightness() => _onSettingsChanged();

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    // بعض الويدجت ثابتة (const) ولا تعيد البناء وحدها،
    // فنعلّم كل الشجرة لإعادة البناء بعد تغيير الألوان أو اللغة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildAll(context);
    });
  }

  static void _rebuildAll(BuildContext context) {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  Brightness _brightness() {
    return switch (_settings.theme) {
      AppThemeChoice.light => Brightness.light,
      AppThemeChoice.dark => Brightness.dark,
      AppThemeChoice.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  Locale? _locale() {
    return switch (_settings.language) {
      AppLanguageChoice.english => const Locale('en'),
      AppLanguageChoice.arabic => const Locale('ar'),
      AppLanguageChoice.system => null, // لغة الهاتف
    };
  }

  @override
  Widget build(BuildContext context) {
    // لا نعرض شيئًا حتى تُقرأ الإعدادات (جزء من الثانية)،
    // حتى لا يظهر الوضع الفاتح لحظة ثم يتحول للداكن
    if (!_settings.isLoaded) {
      final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
      return ColoredBox(
        color: dark ? AppPalette.dark.background : AppPalette.light.background,
      );
    }

    final brightness = _brightness();
    if (_theme == null || _builtFor != brightness) {
      AppColors.use(
        brightness == Brightness.dark ? AppPalette.dark : AppPalette.light,
      );
      _theme = AppTheme.build();
      _builtFor = brightness;
    }

    return MaterialApp(
      title: 'QuickStudy',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      themeMode: ThemeMode.light, // الثيم نفسه يتبدل أعلاه
      locale: _locale(),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // لغة الهاتف إن كانت عربية، وإلا الإنجليزية
      localeResolutionCallback: (device, supported) {
        if (device?.languageCode == 'ar') return const Locale('ar');
        return const Locale('en');
      },
      home: const AppShell(),
    );
  }
}
