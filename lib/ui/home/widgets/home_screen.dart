import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/models/bookmark.dart';
import '../../../domain/models/lecture.dart';
import '../../../domain/models/reading_progress.dart';
import '../../../routing/app_navigator.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/home_view_model.dart';

// تبويب المكتبة: قراءة ملفات PDF
// الترحيب + زرا الإضافة والإعدادات ← خط فاصل ← تابع القراءة ←
// رفوف الكتب (أغلفة حقيقية) ← العلامات المرجعية.
// زر الإضافة يقبل PDF فقط، والصور تُرفع من الرئيسية (LibraryScreen).
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

  // مقاسات الرفوف: أقل عرض للغلاف، والمسافة بين الكتب
  static const double _minCoverWidth = 92;
  static const double _bookGap = 14;
  static const double _maxContentWidth = 640;

  @override
  void initState() {
    super.initState();
    vm.delete.addListener(_onDeleteResult);
    vm.importPdfs.addListener(_onImportResult);
  }

  @override
  void dispose() {
    vm.delete.removeListener(_onDeleteResult);
    vm.importPdfs.removeListener(_onImportResult);
    super.dispose();
  }

  void _onImportResult() {
    final result = vm.importPdfs.result;
    if (result == null || !mounted) return;
    vm.importPdfs.clearResult();
    final s = AppStrings.of(context);

    switch (result) {
      case Ok(:final value):
        if (value.cancelled) return;
        final skipped = value.skipped > 0 ? s.skipped(value.skipped) : '';
        if (value.added > 0) {
          showAppMessage(
            context,
            '${s.filesAdded(value.added)}$skipped',
            tone: MessageTone.success,
          );
        } else {
          showAppMessage(context, '${s.noNewFiles}$skipped');
        }
      case Err():
        showAppMessage(context, s.filesNotSaved, tone: MessageTone.error);
    }
  }

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

  String _greeting(AppStrings s) => switch (vm.dayPart) {
        DayPart.morning => s.goodMorning,
        DayPart.afternoon => s.goodAfternoon,
        DayPart.evening => s.goodEvening,
      };

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final s = AppStrings.of(context);

    // المحتوى لا يتجاوز 640 على الشاشات الكبيرة، وهامش جانبي 28
    // (أوسع قليلًا حتى لا يجلس المحتوى على خطوط الإطار المزخرف)
    final width = MediaQuery.sizeOf(context).width;
    final side = math.max(28.0, (width - _maxContentWidth) / 2 + 28);
    final hPad = EdgeInsets.symmetric(horizontal: side);

    // عدد الكتب في الرف حسب العرض المتاح (لا حسب نوع الجهاز)
    final contentWidth = width - side * 2;
    final perShelf = math.max(
      3,
      ((contentWidth + _bookGap) / (_minCoverWidth + _bookGap)).floor(),
    );
    final coverWidth = (contentWidth - _bookGap * (perShelf - 1)) / perShelf;

    return Stack(
      children: [
        // خلفية ثابتة بإطار مزخرف (نهاري / ليلي) لا تتحرك مع التمرير
        const Positioned.fill(child: _LibraryBackground()),
        ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final pdfs = vm.pdfs;
        final current = vm.current;
        final bookmarks = vm.bookmarks;
        final shelves = (pdfs.length / perShelf).ceil();

        return CustomScrollView(
          slivers: [
            // الترحيب + الأزرار + خط فاصل
            SliverPadding(
              padding: hPad.copyWith(top: insets.top + 18),
              sliver: SliverToBoxAdapter(
                child: _LibraryHeader(
                  greeting: _greeting(s),
                  importing: vm.importPdfs,
                  onAdd: vm.importPdfs.execute,
                ),
              ),
            ),
            if (!vm.isLoaded)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (current == null)
              SliverPadding(
                padding: hPad.copyWith(top: 28),
                sliver: SliverToBoxAdapter(
                  child: ListenableBuilder(
                    listenable: vm.importPdfs,
                    builder: (context, _) => _NoPdfs(
                      busy: vm.importPdfs.running,
                      onAdd: vm.importPdfs.execute,
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: hPad.copyWith(top: 24),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(s.continueReading),
                ),
              ),
              SliverPadding(
                padding: hPad.copyWith(top: 14),
                sliver: SliverToBoxAdapter(
                  child: _ContinueCard(
                    lecture: current,
                    progress: vm.progressFor(current),
                    onOpen: () => _open(current),
                  ),
                ),
              ),

              // رفوف الكتب
              SliverPadding(
                padding: hPad.copyWith(top: 32),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    s.shelvesTitle,
                    trailing: '${pdfs.length}',
                  ),
                ),
              ),
              SliverPadding(
                padding: hPad.copyWith(top: 18),
                sliver: SliverList.builder(
                  itemCount: shelves,
                  itemBuilder: (context, row) {
                    final start = row * perShelf;
                    final books = pdfs.sublist(
                      start,
                      math.min(start + perShelf, pdfs.length),
                    );
                    return _Shelf(
                      books: books,
                      perShelf: perShelf,
                      coverWidth: coverWidth,
                      gap: _bookGap,
                      progressFor: vm.progressFor,
                      onOpen: _open,
                      onDelete: _confirmDelete,
                    );
                  },
                ),
              ),

              // العلامات المرجعية
              SliverPadding(
                padding: hPad.copyWith(top: 22),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    s.bookmarksTitle,
                    trailing: bookmarks.isEmpty ? null : '${bookmarks.length}',
                  ),
                ),
              ),
              if (bookmarks.isEmpty)
                SliverPadding(
                  padding: hPad.copyWith(top: 14),
                  sliver: const SliverToBoxAdapter(child: _NoBookmarks()),
                )
              else
                SliverPadding(
                  padding: hPad.copyWith(top: 6),
                  sliver: SliverList.separated(
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, thickness: 1, color: _Tone.line),
                    itemBuilder: (context, i) {
                      final entry = bookmarks[i];
                      return _BookmarkRow(
                        key: ValueKey(entry.bookmark.id),
                        entry: entry,
                        onOpen: () => _open(
                          entry.lecture,
                          page: entry.bookmark.page,
                        ),
                        onRemove: () => vm.removeBookmark(entry.bookmark),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 28)),
            ],
          ],
        );
      },
    ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// الرأس: "صباح الخير" كبير + "المكتبة" فوقه، الإعدادات والإضافة، ثم خط رفيع
// ---------------------------------------------------------------------------

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.greeting,
    required this.importing,
    required this.onAdd,
  });

  final String greeting;
  final Command0<ImportSummary> importing;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الترحيب صغير بالذهبي، و"المكتبة" كبيرة بخط أميري
                  Text(
                    greeting,
                    style: AppText.tracked(context, AppText.label).copyWith(
                      color: _Tone.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    header: true,
                    child: Text(
                      s.library,
                      // خط نسخ كلاسيكي يناسب الكتب والإطار المزخرف
                      // (يُحمَّل من الإنترنت أول مرة ثم يُخزَّن، وقبلها يظهر الخط العادي)
                      style: GoogleFonts.getFont(
                        'Amiri',
                        textStyle: AppText.display.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAction(
              icon: AppIcons.settings,
              tooltip: s.settings,
              onPressed: () => AppNavigator.openSettings(context),
            ),
            const SizedBox(width: 10),
            ListenableBuilder(
              listenable: importing,
              builder: (context, _) => CircleAction(
                icon: AppIcons.add,
                tooltip: s.addPdf,
                dark: true,
                // نهارًا: ذهبي من زخارف الخلفية بدل الأسود
                color: AppColors.isDark ? null : _Tone.button,
                iconColor: AppColors.isDark ? null : Colors.white,
                onPressed: importing.running ? null : onAdd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(height: 1, thickness: 1, color: _Tone.line),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// متابعة القراءة: معاينة + اسم + "صفحة 12 من 40" + شريط النسبة + زر
// (العنصر الأصفر الوحيد في الصفحة)
// ---------------------------------------------------------------------------

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.lecture,
    required this.progress,
    required this.onOpen,
  });

  final Lecture lecture;
  final ReadingProgress? progress;
  final VoidCallback onOpen;

  static const double _coverW = 78;
  static const double _coverH = 112;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final p = progress;
    final started = p != null && p.pageCount > 0;

    return SoftCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      // شبه شفافة بإطار ذهبي رفيع: تظهر الخلفية من خلفها
      color: _Tone.card,
      border: BorderSide(color: _Tone.line),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _coverH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الغلاف بظل خفيف كأنه كتاب واقف
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    child: FileThumbnail(
                      lecture: lecture,
                      width: _coverW,
                      height: _coverH,
                      radius: 6,
                      showBadge: false,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        started
                            ? s.openedOn(formatDay(p.openedAt, s))
                            : '${s.lastAdded} · ${formatDay(lecture.dateAdded, s)}',
                        style: AppText.caption.copyWith(color: _Tone.gold),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          lecture.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: textDirectionFor(lecture.title),
                          style: AppText.headline.copyWith(height: 1.35),
                        ),
                      ),
                      const Spacer(),
                      // الصفحة والنسبة في سطر واحد فوق شريط رفيع
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              started
                                  ? s.pageOf(p.page, p.pageCount)
                                  : s.notStarted,
                              style: AppText.caption.copyWith(
                                color: AppColors.muted,
                                fontFeatures: AppText.tabular,
                              ),
                            ),
                          ),
                          Text(
                            '${started ? p.percent : 0}%',
                            style: AppText.caption.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontFeatures: AppText.tabular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressTrack(value: started ? p.fraction : 0),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // زر صغير بالأصفر الخفيف في طرف البطاقة
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: started ? s.resumeReading : s.startReading,
              icon: AppIcons.book,
              kind: AppButtonKind.accent,
              onPressed: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// رف واحد: أغلفة متجاورة واقفة على لوح رفيع، والعناوين تحت اللوح
// ---------------------------------------------------------------------------

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.books,
    required this.perShelf,
    required this.coverWidth,
    required this.gap,
    required this.progressFor,
    required this.onOpen,
    required this.onDelete,
  });

  final List<Lecture> books;
  final int perShelf;
  final double coverWidth;
  final double gap;
  final ReadingProgress? Function(Lecture) progressFor;
  final void Function(Lecture, {int? page}) onOpen;
  final ValueChanged<Lecture> onDelete;

  // نسبة غلاف الكتاب (أطول من عرضه)
  static const double _coverRatio = 1.45;

  @override
  Widget build(BuildContext context) {
    final coverHeight = coverWidth * _coverRatio;

    // خانات فارغة في آخر رف حتى تبقى الكتب بمقاسها
    List<Widget> cells(Widget Function(Lecture book) build) => [
          for (var i = 0; i < perShelf; i++) ...[
            if (i > 0) SizedBox(width: gap),
            SizedBox(
              width: coverWidth,
              child: i < books.length ? build(books[i]) : null,
            ),
          ],
        ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الأغلفة
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: cells(
              (book) => _BookCover(
                lecture: book,
                width: coverWidth,
                height: coverHeight,
                progress: progressFor(book),
                onOpen: () => onOpen(book),
                onDelete: () => onDelete(book),
              ),
            ),
          ),
          // لوح الرف
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _Tone.gold.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
              border: Border(
                bottom: BorderSide(color: _Tone.line),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // العناوين
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cells(
              (book) => Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: textDirectionFor(book.title),
                style: AppText.caption.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// غلاف كتاب: الصفحة الأولى الحقيقية + كعب رفيع + شريط تقدم أصفر في الأسفل
class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.lecture,
    required this.width,
    required this.height,
    required this.progress,
    required this.onOpen,
    required this.onDelete,
  });

  final Lecture lecture;
  final double width;
  final double height;
  final ReadingProgress? progress;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final fraction = p != null && p.pageCount > 0 ? p.fraction : 0.0;

    return Semantics(
      button: true,
      label: lecture.title,
      value: p == null ? null : '${p.percent}%',
      child: GestureDetector(
        onTap: onOpen,
        onLongPress: onDelete,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: const BorderRadiusDirectional.horizontal(
              start: Radius.circular(2),
              end: Radius.circular(5),
            ),
            // ظل خفيف جدًا: الكتاب واقف على الرف
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadiusDirectional.horizontal(
              start: Radius.circular(2),
              end: Radius.circular(5),
            ).resolve(Directionality.of(context)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FileThumbnail(
                  lecture: lecture,
                  width: width,
                  height: height,
                  radius: 0,
                  showBadge: false,
                ),
                // كعب الكتاب
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: 5,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.14),
                  ),
                ),
                // تقدم القراءة
                if (fraction > 0)
                  PositionedDirectional(
                    start: 0,
                    bottom: 0,
                    height: 4,
                    width: width * fraction.clamp(0.04, 1.0),
                    child: const ColoredBox(color: AppColors.yellow),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// علامة مرجعية: غلاف صغير + اسم الكتاب + الصفحة + النص المحفوظ.
// اضغط للانتقال للصفحة، واسحب للحذف.
// ---------------------------------------------------------------------------

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  final BookmarkEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final b = entry.bookmark;
    final text = b.text;
    final isText = b.kind == BookmarkKind.text && (text ?? '').isNotEmpty;
    final accent = b.color == null ? AppColors.yellow : Color(b.color!);

    return Dismissible(
      key: ValueKey('dismiss-${b.id}'),
      onDismissed: (_) => onRemove(),
      background: _SwipeBackground(alignment: AlignmentDirectional.centerStart),
      secondaryBackground:
          _SwipeBackground(alignment: AlignmentDirectional.centerEnd),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: FileThumbnail(
                  lecture: entry.lecture,
                  width: 40,
                  height: 56,
                  radius: 3,
                  showBadge: false,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        entry.lecture.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: textDirectionFor(entry.lecture.title),
                        style: AppText.headline.copyWith(fontSize: 14.5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        AppIcon(
                          AppIcons.bookmark,
                          size: 14,
                          color: AppColors.yellowDeep,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          s.pageNumber(b.page),
                          style: AppText.caption.copyWith(
                            color: AppColors.muted,
                            fontFeatures: AppText.tabular,
                          ),
                        ),
                      ],
                    ),
                    if (isText) ...[
                      const SizedBox(height: 8),
                      // النص المحفوظ مع خط بلون التحديد
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsetsDirectional.only(start: 10),
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            start: BorderSide(color: accent, width: 3),
                          ),
                        ),
                        child: Text(
                          text!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: textDirectionFor(text),
                          style: AppText.body.copyWith(
                            fontSize: 13.5,
                            color: AppColors.ink,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: AppIcon(AppIcons.chevron, size: 18, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.redSoft,
      child: AppIcon(AppIcons.trash, size: 22, color: AppColors.red),
    );
  }
}

// لا علامات بعد: شرح قصير لطريقة الحفظ
class _NoBookmarks extends StatelessWidget {
  const _NoBookmarks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tone.line),
        color: _Tone.card,
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.bookmark, size: 24, color: AppColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppStrings.of(context).bookmarksEmpty,
              style: AppText.body.copyWith(color: AppColors.muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// لا توجد ملفات PDF: زر إضافة مباشر
class _NoPdfs extends StatelessWidget {
  const _NoPdfs({required this.busy, required this.onAdd});

  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: _Tone.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Tone.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: IconTile(icon: AppIcons.pdf, tint: Tint.pdf, size: 52)),
          const SizedBox(height: 14),
          Text(s.noPdfsTitle, textAlign: TextAlign.center, style: AppText.headline),
          const SizedBox(height: 6),
          Text(
            s.noPdfsBody,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: busy ? s.addingFiles : s.addPdf,
            icon: AppIcons.add,
            busy: busy,
            onPressed: busy ? null : onAdd,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// خلفية المكتبة: ورق بإطار مزخرف (نهاري كريمي / ليلي أسود)، ثابتة خلف المحتوى
// ---------------------------------------------------------------------------

class _LibraryBackground extends StatelessWidget {
  const _LibraryBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return RepaintBoundary(
      child: ColoredBox(
        color: AppColors.background, // يظهر لحظة قبل تحميل الصورة
        child: Image.asset(
          AppColors.isDark
              ? 'assets/backgrounds/library_dark.webp'
              : 'assets/backgrounds/library_light.webp',
          // fill لا cover: الزخارف على الأطراف الأربعة، والقص يخفي الجانبية
          fit: BoxFit.fill,
          // عرض الشاشة يكون صفرًا في أول إطار عند فتح التطبيق
          cacheWidth: size.width > 0 ? (size.width * ratio).round() : null,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

// ألوان مأخوذة من زخارف الخلفية، لتنسجم عناصر المكتبة معها
abstract final class _Tone {
  // ذهبي داكن ليلًا، وبيج ذهبي نهارًا
  static Color get gold =>
      AppColors.isDark ? const Color(0xFFB08D57) : const Color(0xFFAE9672);

  // زر الإضافة نهارًا (أغمق قليلًا من gold حتى تظهر الأيقونة البيضاء)
  static const Color button = Color(0xFF9C7F52);

  // الخطوط والإطارات الرفيعة
  static Color get line =>
      gold.withValues(alpha: AppColors.isDark ? 0.32 : 0.42);

  // البطاقات شبه شفافة حتى يظهر ملمس الورق
  static Color get card =>
      AppColors.surface.withValues(alpha: AppColors.isDark ? 0.80 : 0.82);
}
