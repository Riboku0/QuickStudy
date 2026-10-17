import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui/core_ui.dart';
import '../home/view_models/home_view_model.dart';
import '../home/widgets/home_screen.dart';
import '../library/view_models/library_view_model.dart';
import '../library/widgets/library_screen.dart';
import '../study/view_models/study_view_model.dart';
import '../study/widgets/study_screen.dart';
import 'floating_nav_bar.dart';

// الهيكل الرئيسي: ثلاث صفحات + شريط التنقل العائم.
// كل صفحة لها ViewModel خاص بها يُنشأ مرة واحدة ويعيش طوال عمر التطبيق.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final HomeViewModel _home;
  late final StudyViewModel _study;
  late final LibraryViewModel _library;

  @override
  void initState() {
    super.initState();
    // context.read مسموح في initState (وليس داخل build)
    _home = HomeViewModel(
      lectures: context.read(),
      progress: context.read(),
      picker: context.read(),
      bookmarks: context.read(),
    );
    _study = StudyViewModel(subjects: context.read());
    _library = LibraryViewModel(lectures: context.read(), picker: context.read());
  }

  void _openTab(int index) => setState(() => _index = index);

  @override
  void dispose() {
    _home.dispose();
    _study.dispose();
    _library.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      // IndexedStack يحافظ على حالة كل صفحة عند التنقل
      body: IndexedStack(
        index: _index,
        children: [
          // الرئيسية: إدارة الملفات والرفع (شاشة Library سابقًا)
          LibraryScreen(viewModel: _library),
          StudyScreen(viewModel: _study),
          // المكتبة: قراءة ملفات PDF (شاشة Home سابقًا)
          HomeScreen(viewModel: _home, onOpenTab: _openTab),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        items: [
          NavItem(AppIcons.home, s.home),
          NavItem(AppIcons.study, s.study),
          NavItem(AppIcons.libraryTab, s.library),
        ],
        index: _index,
        onChanged: _openTab,
      ),
    );
  }
}
