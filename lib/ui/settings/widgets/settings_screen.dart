import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/settings/settings_repository.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/settings_view_model.dart';

// الإعدادات: المظهر (تلقائي / فاتح / داكن) واللغة (الهاتف / English / العربية)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = SettingsViewModel(settings: context.read<SettingsRepository>());
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(overline: s.preferences, title: s.settings),
                  const SizedBox(height: 26),

                  // ---- المظهر ----
                  SectionHeader(s.appearance),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ThemeTile(
                          icon: AppIcons.phone,
                          label: s.themeSystem,
                          preview: _PreviewKind.auto,
                          selected: vm.theme == AppThemeChoice.system,
                          onTap: () => vm.setTheme(AppThemeChoice.system),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeTile(
                          icon: AppIcons.sun,
                          label: s.themeLight,
                          preview: _PreviewKind.light,
                          selected: vm.theme == AppThemeChoice.light,
                          onTap: () => vm.setTheme(AppThemeChoice.light),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeTile(
                          icon: AppIcons.moon,
                          label: s.themeDark,
                          preview: _PreviewKind.dark,
                          selected: vm.theme == AppThemeChoice.dark,
                          onTap: () => vm.setTheme(AppThemeChoice.dark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.themeSystemHint,
                    style: AppText.caption.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 30),

                  // ---- اللغة ----
                  SectionHeader(s.language),
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        _LanguageRow(
                          title: s.languageSystem,
                          subtitle: s.languageSystemHint,
                          badge: null,
                          selected: vm.language == AppLanguageChoice.system,
                          onTap: () => vm.setLanguage(AppLanguageChoice.system),
                        ),
                        _LanguageRow(
                          title: 'English',
                          subtitle: 'English',
                          badge: 'EN',
                          selected: vm.language == AppLanguageChoice.english,
                          onTap: () => vm.setLanguage(AppLanguageChoice.english),
                        ),
                        _LanguageRow(
                          title: 'العربية',
                          subtitle: 'Arabic',
                          badge: 'ع',
                          selected: vm.language == AppLanguageChoice.arabic,
                          onTap: () => vm.setLanguage(AppLanguageChoice.arabic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  InfoNote(s.settingsNote),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '${s.appName} · ${s.version} 1.0.0',
                      style: AppText.caption.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// مربع اختيار المظهر: معاينة مصغّرة للوضع + أيقونة + اسم
// ---------------------------------------------------------------------------

enum _PreviewKind { auto, light, dark }

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.icon,
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final AppIconData icon;
  final String label;
  final _PreviewKind preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellowSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.yellow : AppColors.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: AppTokens.of(context).shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  _MiniPreview(kind: preview),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(
                        icon,
                        size: 16,
                        color: selected ? AppColors.yellowDeep : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// شاشة صغيرة مرسومة بألوان الوضع (لا تتأثر بالوضع الحالي)
class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.kind});

  final _PreviewKind kind;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (kind) {
      _PreviewKind.light => _screen(AppPalette.light),
      _PreviewKind.dark => _screen(AppPalette.dark),
      _PreviewKind.auto => Row(
          children: [
            Expanded(child: _screen(AppPalette.light, half: true)),
            Expanded(child: _screen(AppPalette.dark, half: true)),
          ],
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(height: 74, child: body),
    );
  }

  static Widget _screen(AppPalette p, {bool half = false}) {
    return ColoredBox(
      color: p.background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: half ? 18 : 30,
              height: 5,
              decoration: BoxDecoration(
                color: p.ink,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: AlignmentDirectional.bottomStart,
                padding: const EdgeInsets.all(5),
                child: Container(
                  width: half ? 12 : 20,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// صف لغة: شارة + اسم + علامة اختيار
// ---------------------------------------------------------------------------

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellowSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accentSoft : AppColors.chip,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: badge == null
                        ? AppIcon(
                            AppIcons.language,
                            size: 20,
                            color: selected ? AppColors.onAccentSoft : AppColors.ink,
                          )
                        : Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: selected ? AppColors.onYellow : AppColors.ink,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.headline.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppText.caption.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: AppIcon(
                          AppIcons.check,
                          size: 15,
                          color: AppColors.onYellow,
                          strokeWidth: 2.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
