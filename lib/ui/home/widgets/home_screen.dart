import 'package:flutter/material.dart';

import '../../../domain/models/bookmark.dart';
import '../../../domain/models/lecture.dart';
import '../../../domain/models/reading_progress.dart';
import '../../../routing/app_navigator.dart';
import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../../shell/profile_menu.dart';
import '../view_models/home_view_model.dart';

// تبويب المكتبة: قراءة ملفات PDF (مقتبس من مرجع المستخدم، بنفس ثيم المذاكرة البنفسجي)
// الترحيب والعنوان + البحث وقائمة الحساب ← بطاقة آخر ما قرأت (تقليب بالسحب) ←
// "كتبك" + إضافة كتاب ← تبويبات التصنيف ← شبكة الكتب (غلاف، عنوان، تصنيف، ⋯).
// علامات كل كتاب تظهر من قائمة ⋯ الخاصة به.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.onOpenTab,
  });

  final HomeViewModel viewModel;
  final ValueChanged<int> onOpenTab; // 0 = الرئيسية

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.delete.addListener(_onDeleteResult);
  }

  @override
  void dispose() {
    vm.delete.removeListener(_onDeleteResult);
    super.dispose();
  }

  // نموذج إضافة كتاب (الملف + الاسم + التصنيف)
  void _addBook() => AppNavigator.openAddBook(context, category: vm.category);

  void _onDeleteResult() {
    final result = vm.delete.result;
    if (result == null || !mounted) return;
    vm.delete.clearResult();
    final s = AppStrings.of(context);

    showAppMessage(
      context,
      result is Ok ? s.fileDeleted : s.fileNotDeleted,
      tone: result is Ok ? MessageTone.success : MessageTone.error,
    );
  }

  Future<void> _confirmDelete(Lecture lecture) async {
    if (await confirmDeleteFile(context, lecture.name)) {
      vm.delete.execute(lecture);
    }
  }

  void _open(Lecture lecture, {int? page}) =>
      AppNavigator.openDocument(context, lecture, page: page);

  Future<void> _bookMenu(Lecture lecture) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StudyTone.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          // الكتاب بآخر حالته (التصنيف يتغير والقائمة مفتوحة)
          final current = vm.pdfs.firstWhere(
            (l) => l.id == lecture.id,
            orElse: () => lecture,
          );
          return _BookSheet(
            lecture: current,
            bookmarks: vm.bookmarksFor(current),
            categories: vm.allCategories,
            onCategory: (c) => vm.setBookCategory.execute((current, c)),
            onOpenBookmark: (b) {
              Navigator.of(sheetContext).pop();
              _open(current, page: b.page);
            },
            onRemoveBookmark: vm.removeBookmark,
            onDelete: () {
              Navigator.of(sheetContext).pop();
              _confirmDelete(current);
            },
          );
        },
      ),
    );
  }

  String _greeting(AppStrings s) => switch (vm.dayPart) {
    DayPart.morning => s.goodMorning,
    DayPart.afternoon => s.goodAfternoon,
    DayPart.evening => s.goodEvening,
  };

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final s = AppStrings.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // كتابان في السطر على الهاتف (مساحة وأزرار أوسع)، وأكثر على الشاشات العريضة
    final columns = (width / 200).floor().clamp(2, 5);

    return RepaintBoundary(
      child: ColoredBox(
        color: StudyTone.background,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            final pdfs = vm.pdfs;
            final recent = vm.recent;
            final books = vm.visible;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, insets.top + 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: ConstrainedContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            greeting: _greeting(s),
                            dayPart: vm.dayPart,
                          ),
                          if (!vm.isLoaded)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (pdfs.isEmpty) ...[
                            const SizedBox(height: 24),
                            _NoBooks(
                              busy: false,
                              onAdd: _addBook,
                            ),
                          ] else ...[
                            if (recent.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              _RecentCarousel(
                                books: recent,
                                progressFor: vm.progressFor,
                                onOpen: _open,
                              ),
                            ],
                            const SizedBox(height: 26),
                            _SectionTitle(
                              count: pdfs.length,
                              busy: false,
                              onAdd: _addBook,
                            ),
                            const SizedBox(height: 14),
                            _CategoryTabs(
                              categories: vm.allCategories,
                              selected: vm.category,
                              onSelect: vm.setCategory,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (vm.isLoaded && pdfs.isNotEmpty)
                  if (books.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          s.noBooksInCategory,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(color: AppColors.muted),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        insets.bottom + 28,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.56,
                        ),
                        itemCount: books.length,
                        itemBuilder: (context, i) {
                          final book = books[i];
                          return _BookCard(
                            lecture: book,
                            progress: vm.progressFor(book),
                            bookmarked: vm.hasBookmarks(book),
                            onOpen: () => _open(book),
                            onMenu: () => _bookMenu(book),
                          );
                        },
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرأس: التحية بالبنفسجي + "المكتبة" + سطر قصير، والبحث وقائمة الحساب
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.dayPart,
  });

  final String greeting;
  final DayPart dayPart;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(
                    dayPart == DayPart.evening ? AppIcons.moon : AppIcons.sun,
                    size: 18,
                    color: StudyTone.purple,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    greeting,
                    style: AppText.label.copyWith(color: StudyTone.purple),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  AppIcon(
                    AppIcons.libraryTab,
                    size: 28,
                    color: StudyTone.purple,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        s.library,
                        style: AppText.display.copyWith(fontSize: 30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.librarySubtitle,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const ProfileMenuButton(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة آخر ما قرأت: حتى 4 كتب تُقلَّب بالسحب، والنقاط تحتها
// ---------------------------------------------------------------------------

class _RecentCarousel extends StatefulWidget {
  const _RecentCarousel({
    required this.books,
    required this.progressFor,
    required this.onOpen,
  });

  final List<Lecture> books;
  final ReadingProgress? Function(Lecture) progressFor;
  final void Function(Lecture, {int? page}) onOpen;

  @override
  State<_RecentCarousel> createState() => _RecentCarouselState();
}

class _RecentCarouselState extends State<_RecentCarousel> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.books.length;

    return Column(
      children: [
        SizedBox(
          height: 268,
          child: PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final book = widget.books[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: _RecentCard(
                  lecture: book,
                  progress: widget.progressFor(book),
                  onOpen: () => widget.onOpen(book),
                ),
              );
            },
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? StudyTone.purple
                        : StudyTone.purple.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.lecture,
    required this.progress,
    required this.onOpen,
  });

  final Lecture lecture;
  final ReadingProgress? progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final p = progress;
    final started = p != null && p.pageCount > 0;

    return StudyCard(
      onTap: onOpen,
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // الغلاف فوق بقعة بنفسجية ناعمة
          SizedBox(
            width: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 128,
                  height: 170,
                  decoration: BoxDecoration(
                    color: StudyTone.purple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                Transform.rotate(
                  angle: -0.05,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: RepaintBoundary(
                      child: FileThumbnail(
                        lecture: lecture,
                        width: 108,
                        height: 156,
                        radius: 6,
                        showBadge: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppPill(
                  s.recentlyRead,
                  background: StudyTone.purple.withValues(alpha: 0.12),
                  foreground: StudyTone.purple,
                ),
                const SizedBox(height: 10),
                Text(
                  lecture.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: textDirectionFor(lecture.title),
                  style: AppText.title.copyWith(height: 1.35),
                ),
                const SizedBox(height: 12),
                Text(
                  '${started ? p.percent : 0}%',
                  textDirection: TextDirection.ltr,
                  style: AppText.label.copyWith(
                    color: AppColors.ink,
                    fontFeatures: AppText.tabular,
                  ),
                ),
                const SizedBox(height: 6),
                _PurpleBar(value: started ? p.fraction : 0),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppIcon(AppIcons.book, size: 15, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        started ? s.pageOf(p.page, p.pageCount) : s.notStarted,
                        style: AppText.caption.copyWith(
                          color: AppColors.muted,
                          fontFeatures: AppText.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: StudyButton(
                    label: started ? s.resumeReading : s.startReading,
                    icon: AppIcons.next,
                    onPressed: onOpen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// شريط تقدم بنفسجي رفيع
class _PurpleBar extends StatelessWidget {
  const _PurpleBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: StudyTone.purple.withValues(alpha: 0.14),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              alignment: AlignmentDirectional.centerStart,
              child: ColoredBox(color: StudyTone.purple),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "كتبك" + عدد الكتب + إضافة كتاب
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.count,
    required this.busy,
    required this.onAdd,
  });

  final int count;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Row(
      children: [
        AppIcon(AppIcons.libraryTab, size: 22, color: StudyTone.purple),
        const SizedBox(width: 8),
        Text(s.shelvesTitle, style: AppText.headline.copyWith(fontSize: 17)),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: AppText.caption.copyWith(
            color: AppColors.muted,
            fontFeatures: AppText.tabular,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: busy ? null : onAdd,
          style: TextButton.styleFrom(
            foregroundColor: StudyTone.purple,
            minimumSize: const Size(44, 44),
          ),
          icon: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: StudyTone.purple,
                  ),
                )
              : AppIcon(AppIcons.add, size: 18, color: StudyTone.purple),
          label: Text(
            s.addPdf,
            style: AppText.label.copyWith(color: StudyTone.purple),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// تبويبات التصنيف: الكل + التصنيفات (المختار بنفسجي)
// ---------------------------------------------------------------------------

// لون وأيقونة كل تصنيف (يُستخدمان في التبويبات والشارة على الكتاب)
(Color, AppIconData) categoryStyle(String? key) => switch (key) {
  'novel' => (const Color(0xFFCF5A93), AppIcons.book),
  'study' => (const Color(0xFF4A72D9), AppIcons.study),
  'philosophy' => (const Color(0xFF2A97A8), AppIcons.idea),
  'works' => (const Color(0xFFD08A2E), AppIcons.file),
  _ => (StudyTone.purple, AppIcons.dashboard),
};

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final items = <(String?, String)>[
      (null, s.allCategories),
      for (final c in categories) (c, s.categoryPlural(c)),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (key, label) = items[i];
          final on = key == selected;
          final icon = categoryStyle(key).$2;

          return Semantics(
            button: true,
            selected: on,
            child: Material(
              color: on ? StudyTone.purple : StudyTone.card,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      AppIcon(
                        icon,
                        size: 18,
                        color: on ? StudyTone.onPurple : AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: AppText.label.copyWith(
                          color: on ? StudyTone.onPurple : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة كتاب في الشبكة: الغلاف (+ علامة إن كان له علامات + تقدم)،
// العنوان، شارة التصنيف، و⋯ لقائمة الكتاب
// ---------------------------------------------------------------------------

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.lecture,
    required this.progress,
    required this.bookmarked,
    required this.onOpen,
    required this.onMenu,
  });

  final Lecture lecture;
  final ReadingProgress? progress;
  final bool bookmarked;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final p = progress;
    final fraction = p != null && p.pageCount > 0 ? p.fraction : 0.0;
    final category = lecture.category;
    final (catColor, catIcon) = categoryStyle(category);

    return Semantics(
      button: true,
      label: lecture.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: StudyTone.shadow,
        ),
        child: Material(
          color: StudyTone.card,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            onLongPress: onMenu,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: FileThumbnail(
                                lecture: lecture,
                                width: box.maxWidth,
                                height: box.maxHeight,
                                radius: 0,
                                showBadge: false,
                              ),
                            ),
                            if (bookmarked)
                              PositionedDirectional(
                                top: 6,
                                end: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: StudyTone.purple,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Center(
                                    child: AppIcon(
                                      AppIcons.bookmarkSaved,
                                      size: 15,
                                      color: StudyTone.onPurple,
                                    ),
                                  ),
                                ),
                              ),
                            if (fraction > 0)
                              PositionedDirectional(
                                start: 0,
                                bottom: 0,
                                height: 4,
                                width: box.maxWidth * fraction.clamp(0.04, 1.0),
                                child: ColoredBox(color: StudyTone.purple),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lecture.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: textDirectionFor(lecture.title),
                    style: AppText.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  Row(
                    children: [
                      if (category != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(catIcon, size: 14, color: catColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    s.categoryName(category),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption.copyWith(
                                      color: catColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      // زر ⋯ (منطقة لمس 40)
                      IconButton(
                        onPressed: onMenu,
                        tooltip: s.bookCategory,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        icon: AppIcon(
                          AppIcons.moreHorizontal,
                          size: 20,
                          color: AppColors.muted,
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

// ---------------------------------------------------------------------------
// قائمة الكتاب: التصنيف، علامات هذا الكتاب، الحذف
// ---------------------------------------------------------------------------

class _BookSheet extends StatelessWidget {
  const _BookSheet({
    required this.lecture,
    required this.bookmarks,
    required this.categories,
    required this.onCategory,
    required this.onOpenBookmark,
    required this.onRemoveBookmark,
    required this.onDelete,
  });

  final Lecture lecture;
  final List<Bookmark> bookmarks;
  final List<String> categories;
  final ValueChanged<String?> onCategory;
  final ValueChanged<Bookmark> onOpenBookmark;
  final ValueChanged<Bookmark> onRemoveBookmark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final labelStyle = AppText.label.copyWith(color: AppColors.muted);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lecture.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: textDirectionFor(lecture.title),
                style: AppText.title,
              ),
              const SizedBox(height: 18),

              // التصنيف
              Text(s.bookCategory, style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in <String?>[
                    null,
                    ...categories,
                  ])
                    ChoiceChip(
                      label: Text(
                        key == null ? s.noCategory : s.categoryName(key),
                      ),
                      selected: lecture.category == key,
                      onSelected: (_) => onCategory(key),
                      selectedColor: StudyTone.purple.withValues(alpha: 0.16),
                      labelStyle: AppText.label.copyWith(
                        color: lecture.category == key
                            ? StudyTone.purple
                            : AppColors.ink,
                      ),
                      side: BorderSide(
                        color: lecture.category == key
                            ? StudyTone.purple
                            : AppColors.line,
                      ),
                      backgroundColor: StudyTone.card,
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 22),

              // علامات هذا الكتاب
              Text(s.bookmarksTitle, style: labelStyle),
              const SizedBox(height: 8),
              if (bookmarks.isEmpty)
                Text(
                  s.noBookmarksInBook,
                  style: AppText.body.copyWith(color: AppColors.muted),
                )
              else
                StudyCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, b) in bookmarks.indexed) ...[
                        if (i > 0) Divider(height: 1, color: AppColors.line),
                        ListTile(
                          onTap: () => onOpenBookmark(b),
                          leading: AppIcon(
                            AppIcons.bookmarkSaved,
                            size: 20,
                            color: StudyTone.purple,
                          ),
                          title: Text(
                            s.pageNumber(b.page),
                            style: AppText.label,
                          ),
                          subtitle: b.text == null
                              ? null
                              : Text(
                                  b.text!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: textDirectionFor(b.text!),
                                  style: AppText.caption.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                          trailing: IconButton(
                            tooltip: s.delete,
                            onPressed: () => onRemoveBookmark(b),
                            icon: AppIcon(
                              AppIcons.close,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 22),

              TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                  minimumSize: const Size(0, 48),
                ),
                icon: AppIcon(AppIcons.trash, size: 20, color: AppColors.red),
                label: Text(s.deleteFile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// لا كتب بعد
class _NoBooks extends StatelessWidget {
  const _NoBooks({required this.busy, required this.onAdd});

  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return StudyCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: StudyTone.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.libraryTab,
                  size: 28,
                  color: StudyTone.purple,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.noPdfsTitle,
            textAlign: TextAlign.center,
            style: AppText.headline,
          ),
          const SizedBox(height: 6),
          Text(
            s.noPdfsBody,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          StudyButton(
            label: s.addPdf,
            icon: AppIcons.add,
            busy: busy,
            onPressed: busy ? null : onAdd,
          ),
        ],
      ),
    );
  }
}
