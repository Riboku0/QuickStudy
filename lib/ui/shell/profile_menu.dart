import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/settings/settings_repository.dart';
import '../core/ui/core_ui.dart';

// صورة الحساب (مؤقتة من المستخدم حتى نربط حساب قوقل)
const String profileAvatarAsset = 'assets/avatars/avatar.png';

// زر الثلاث نقاط في أعلى كل التبويبات: يفتح قائمة الحساب
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CircleAction(
      icon: AppIcons.more,
      tooltip: AppStrings.of(context).account,
      onPressed: () => showProfileMenu(context),
    );
  }
}

// صورة الحساب في دائرة (تفتح القائمة نفسها عند اللمس)
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 68, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: StudyTone.card,
        border: Border.all(
          color: StudyTone.purple.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: StudyTone.shadow,
      ),
      child: const ClipOval(
        child: Image(
          image: ResizeImage(AssetImage(profileAvatarAsset), width: 220),
          fit: BoxFit.cover,
        ),
      ),
    );
    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label: AppStrings.of(context).account,
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }
}

Future<void> showProfileMenu(BuildContext context) {
  final settings = context.read<SettingsRepository>();
  // لوحة جانبية تنزلق من جهة زر ⋮ (اليسار في العربية، اليمين في الإنجليزية).
  // لونها يُقرأ داخل البناء لا عند الفتح، فيتبع تغيير المظهر والثيم فورًا.
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _ProfileSheet(settings: settings),
    transitionBuilder: (context, animation, _, child) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: Offset(rtl ? -1 : 1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

// قائمة الحساب: الصورة والاسم، ثم المظهر واللون واللغة
class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({required this.settings});

  final SettingsRepository settings;

  Future<void> _editName(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: settings.userName),
    );
    if (name != null) await settings.setUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final name = settings.userName;
        final width = (MediaQuery.sizeOf(context).width * 0.88).clamp(
          0.0,
          380.0,
        );

        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Material(
            color: StudyTone.background,
            elevation: 12,
            shadowColor: Colors.black54,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadiusDirectional.horizontal(
                start: Radius.circular(28),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // العنوان وزر الإغلاق
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.account,
                              style: AppText.title.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: AppIcon(
                              AppIcons.close,
                              size: 22,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // الصورة والاسم (لمسة على الاسم لتغييره)
                      StudyCard(
                        onTap: () => _editName(context),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const ProfileAvatar(size: 60),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? s.addYourName : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: textDirectionFor(name),
                                    style: AppText.title.copyWith(
                                      color: name.isEmpty
                                          ? AppColors.muted
                                          : AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.accountLocalNote,
                                    style: AppText.caption.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppIcon(
                              AppIcons.edit,
                              size: 20,
                              color: StudyTone.purple,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(s.appearance, style: _labelStyle),
                      const SizedBox(height: 8),
                      _Choices<AppThemeChoice>(
                        value: settings.theme,
                        onChanged: settings.setTheme,
                        options: [
                          (
                            AppThemeChoice.system,
                            AppIcons.phone,
                            s.themeSystem,
                          ),
                          (AppThemeChoice.light, AppIcons.sun, s.themeLight),
                          (AppThemeChoice.dark, AppIcons.moon, s.themeDark),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // لون التطبيق (الثيم): يتغير كل التطبيق فورًا
                      Text(s.appColor, style: _labelStyle),
                      const SizedBox(height: 10),
                      _AccentChoices(
                        value: settings.accent,
                        onChanged: settings.setAccent,
                      ),
                      const SizedBox(height: 18),

                      Text(s.language, style: _labelStyle),
                      const SizedBox(height: 8),
                      _Choices<AppLanguageChoice>(
                        value: settings.language,
                        onChanged: settings.setLanguage,
                        options: [
                          (
                            AppLanguageChoice.system,
                            AppIcons.phone,
                            s.languageSystem,
                          ),
                          (
                            AppLanguageChoice.arabic,
                            AppIcons.language,
                            'العربية',
                          ),
                          (
                            AppLanguageChoice.english,
                            AppIcons.language,
                            'English',
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
      },
    );
  }

  TextStyle get _labelStyle => AppText.label.copyWith(color: AppColors.muted);
}

// اختيارات متجاورة (المظهر / اللغة)، المختار بنفسجي
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, AppIconData, String)> options;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, (option, icon, label)) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: option == value,
              label: label,
              excludeSemantics: true,
              child: Material(
                color: option == value
                    ? StudyTone.purple.withValues(alpha: 0.14)
                    : StudyTone.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: option == value ? StudyTone.purple : AppColors.line,
                    width: option == value ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(option),
                  child: SizedBox(
                    height: 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          icon,
                          size: 20,
                          color: option == value
                              ? StudyTone.purple
                              : AppColors.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// نافذة الاسم: تملك الـ controller وتتخلص منه في dispose
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(s.yourName, style: AppText.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 30,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: InputDecoration(labelText: s.yourName, counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          style: FilledButton.styleFrom(
            backgroundColor: StudyTone.purple,
            foregroundColor: StudyTone.onPurple,
            minimumSize: const Size(0, 44),
          ),
          child: Text(s.save),
        ),
      ],
    );
  }
}

// دوائر ألوان الثيمات: كل دائرة بتدرج الثيم، والمختار بعلامة وإطار
class _AccentChoices extends StatelessWidget {
  const _AccentChoices({required this.value, required this.onChanged});

  final AppAccent value;
  final ValueChanged<AppAccent> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final dark = AppColors.isDark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final accent in AppAccent.values)
          () {
            final tone = AppTone.all[accent]!;
            final selected = accent == value;
            final colors = dark ? tone.gradientDark : tone.gradient;
            final ring = dark ? tone.mainDark : tone.main;

            return Semantics(
              button: true,
              selected: selected,
              label: accent == AppAccent.violet
                  ? '${s.accentName(accent.name)}, ${s.defaultLabel}'
                  : s.accentName(accent.name),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(accent),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? ring : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                        ),
                        child: selected
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.accentName(accent.name),
                      style: AppText.caption.copyWith(
                        fontSize: 10.5,
                        color: selected ? ring : AppColors.muted,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    // البنفسجي هو لون التطبيق الافتراضي
                    if (accent == AppAccent.violet)
                      Text(
                        s.defaultLabel,
                        style: AppText.caption.copyWith(
                          fontSize: 9,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}
