import 'package:flutter/material.dart';

import '../../../domain/models/lecture.dart';
import '../../../routing/app_navigator.dart';
import '../../../utils/result.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/library_view_model.dart';

// Library: أرشيف بشريط بحث وفلاتر مثبت + شريط تخزين + قائمة مجمّعة بالتاريخ
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _search = TextEditingController();

  LibraryViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.delete.addListener(_onDeleteResult);
    vm.importFiles.addListener(_onImportResult);
  }

  @override
  void dispose() {
    vm.delete.removeListener(_onDeleteResult);
    vm.importFiles.removeListener(_onImportResult);
    _search.dispose();
    super.dispose();
  }

  void _onImportResult() {
    final result = vm.importFiles.result;
    if (result == null || !mounted) return;
    vm.importFiles.clearResult();
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

  // زر الرفع (داكن) — يتعطل أثناء الرفع
  Widget _uploadButton(AppStrings s) => ListenableBuilder(
        listenable: vm.importFiles,
        builder: (context, _) => CircleAction(
          icon: AppIcons.upload,
          tooltip: s.uploadFiles,
          dark: true,
          onPressed: vm.importFiles.running ? null : vm.importFiles.execute,
        ),
      );

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

  Future<void> _open(Lecture lecture) async {
    if (!lecture.exists) {
      showAppMessage(
        context,
        AppStrings.of(context).fileMissing,
        tone: MessageTone.error,
      );
      return;
    }
    await AppNavigator.openDocument(context, lecture);
  }

  // يسأل أولًا ثم يحذف. يرجع true عند الموافقة.
  Future<bool> _confirmAndDelete(Lecture lecture) async {
    final confirmed = await confirmDeleteFile(context, lecture.name);
    if (!confirmed) return false;
    await vm.delete.execute(lecture);
    // نجح الحذف إذا لم يعد الملف في القائمة
    return !vm.all.any((l) => l.id == lecture.id);
  }

  void _clearFilters() {
    _search.clear();
    FocusScope.of(context).unfocus();
    vm.clearFilters();
  }

  static String _bucketTitle(DateBucket bucket, AppStrings s) => switch (bucket) {
        DateBucket.all => s.allFiles,
        DateBucket.today => s.today,
        DateBucket.yesterday => s.yesterday,
        DateBucket.thisWeek => s.thisWeek,
        DateBucket.thisMonth => s.thisMonth,
        DateBucket.earlier => s.earlier,
      };

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final s = AppStrings.of(context);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (!vm.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.all.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: EmptyState(
              icon: AppIcons.archive,
              title: s.libraryEmptyTitle,
              message: s.libraryEmptyBody,
              actionLabel: s.uploadFiles,
              onAction: vm.importFiles.execute,
            ),
          );
        }

        final groups = vm.groups;

        return RefreshIndicator(
          color: AppColors.ink,
          edgeOffset: insets.top,
          onRefresh: vm.reload.execute,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: ConstrainedContent(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(
                          overline: s.yourArchive,
                          title: s.home,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAction(
                                icon: AppIcons.settings,
                                tooltip: s.settings,
                                onPressed: () =>
                                    AppNavigator.openSettings(context),
                              ),
                              const SizedBox(width: 10),
                              _SortButton(
                                value: vm.sort,
                                onChanged: vm.setSort,
                              ),
                              const SizedBox(width: 10),
                              _uploadButton(s),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _StorageCard(
                          files: vm.all.length,
                          pdfs: vm.pdfCount,
                          images: vm.imageCount,
                          totalBytes: vm.totalBytes,
                          pdfBytes: vm.pdfBytes,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // البحث والفلاتر يبقيان ظاهرين أثناء التمرير
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedControls(
                  search: _search,
                  vm: vm,
                ),
              ),

              if (groups.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, insets.bottom + 24),
                  sliver: SliverToBoxAdapter(
                    child: _NoResults(onClear: _clearFilters),
                  ),
                )
              else
                for (final group in groups) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: ConstrainedContent(
                        maxWidth: 720,
                        child: SectionHeader(
                          _bucketTitle(group.bucket, s),
                          trailing: '${group.items.length}',
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: group.items.length,
                      itemBuilder: (context, i) {
                        final lecture = group.items[i];

                        return ConstrainedContent(
                          maxWidth: 720,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Dismissible(
                              key: ValueKey('lecture_${lecture.id}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmAndDelete(lecture),
                              background: const _DeleteBackground(),
                              child: _LectureTile(
                                lecture: lecture,
                                onOpen: () => _open(lecture),
                                onDelete: () => _confirmAndDelete(lecture),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

              SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 24)),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ترتيب
// ---------------------------------------------------------------------------

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final SortOrder value;
  final ValueChanged<SortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final labels = {
      SortOrder.newest: s.newestFirst,
      SortOrder.oldest: s.oldestFirst,
      SortOrder.name: s.nameAZ,
    };

    return PopupMenuButton<SortOrder>(
      tooltip: s.sortFiles,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final entry in labels.entries)
          PopupMenuItem(
            value: entry.key,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: entry.key == value
                      ? AppIcon(AppIcons.check, size: 18, color: AppColors.ink)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(entry.value),
              ],
            ),
          ),
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: Center(
          child: AppIcon(AppIcons.sort, size: 21, color: AppColors.ink),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة التخزين: عدد الملفات + شريط نسبة PDF/الصور
// ---------------------------------------------------------------------------

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.files,
    required this.pdfs,
    required this.images,
    required this.totalBytes,
    required this.pdfBytes,
  });

  final int files;
  final int pdfs;
  final int images;
  final int totalBytes;
  final int pdfBytes;

  @override
  Widget build(BuildContext context) {
    final pdfShare = totalBytes == 0 ? 0.5 : pdfBytes / totalBytes;
    final s = AppStrings.of(context);

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatBytes(totalBytes),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontFeatures: AppText.tabular,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  s.usedBy(files),
                  style: AppText.caption.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ShareBar(pdfShare: pdfShare),
          const SizedBox(height: 12),
          Row(
            children: [
              _Legend(color: AppColors.red, label: s.pdf),
              const SizedBox(width: 6),
              Text('$pdfs', style: _legendValue),
              const SizedBox(width: 18),
              _Legend(color: AppColors.blue, label: s.images),
              const SizedBox(width: 6),
              Text('$images', style: _legendValue),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _legendValue = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    fontFeatures: AppText.tabular,
  );
}

// شريط النسبة: كل جزء له ارتفاع صريح (ColoredBox بلا ابن يأخذ ارتفاع صفر)
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.pdfShare});

  final double pdfShare;

  @override
  Widget build(BuildContext context) {
    final share = pdfShare.isFinite ? pdfShare.clamp(0.02, 0.98) : 0.5;
    final pdfFlex = (share * 100).round();

    return Row(
      children: [
        Expanded(
          flex: pdfFlex,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          flex: 100 - pdfFlex,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.caption.copyWith(color: AppColors.muted)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// البحث + فلتر النوع (مثبتان أعلى الشاشة)
// ---------------------------------------------------------------------------

class _PinnedControls extends SliverPersistentHeaderDelegate {
  _PinnedControls({required this.search, required this.vm});

  final TextEditingController search;
  final LibraryViewModel vm;

  static const double _searchHeight = 50;
  static const double _height = 8 + _searchHeight + 10 + _TypeTabs.height + 12;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_PinnedControls oldDelegate) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final s = AppStrings.of(context);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: ConstrainedContent(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _searchHeight,
              child: TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: search,
                onChanged: vm.setQuery,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.search,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: s.searchYourFiles,
                  hintStyle: AppText.body.copyWith(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(14),
                    child: AppIcon(AppIcons.search, size: 20, color: AppColors.muted),
                  ),
                  suffixIcon: vm.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: s.clearSearch,
                          icon: AppIcon(
                            AppIcons.close,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          onPressed: () {
                            search.clear();
                            vm.setQuery('');
                          },
                        ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.ink, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _TypeTabs(
              value: vm.filter,
              onChanged: vm.setFilter,
              counts: {
                TypeFilter.all: vm.all.length,
                TypeFilter.pdf: vm.pdfCount,
                TypeFilter.images: vm.imageCount,
              },
            ),
          ],
        ),
      ),
    );
  }
}

// تبويبات النوع: مؤشر داكن ينزلق تحت النص، والنص في المنتصف تمامًا
class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.value,
    required this.onChanged,
    required this.counts,
  });

  static const double height = 46;

  final TypeFilter value;
  final ValueChanged<TypeFilter> onChanged;
  final Map<TypeFilter, int> counts;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final labels = {
      TypeFilter.all: s.all,
      TypeFilter.pdf: s.pdf,
      TypeFilter.images: s.images,
    };
    final items = TypeFilter.values;
    final index = items.indexOf(value);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // المؤشر
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            // AlignmentDirectional: في العربية "الكل" يبدأ من اليمين
            alignment: AlignmentDirectional(-1 + index * 2 / (items.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / items.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.hero,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: item == value,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(item),
                      child: Center(
                        child: _TabLabel(
                          label: labels[item]!,
                          count: counts[item] ?? 0,
                          selected: item == value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.count,
    required this.selected,
  });

  final String label;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.yellow : AppColors.ink;
    final countColor = selected ? AppColors.yellow : AppColors.muted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppText.body.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            height: 1,
          ),
          child: Text(label),
        ),
        const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.yellow.withValues(alpha: 0.18)
                : AppColors.ink.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: countColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
              fontFeatures: AppText.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ملف في القائمة
// ---------------------------------------------------------------------------

class _LectureTile extends StatelessWidget {
  const _LectureTile({
    required this.lecture,
    required this.onOpen,
    required this.onDelete,
  });

  final Lecture lecture;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tint = lecture.isPdf
        ? Tint.pdf
        : (lecture.isImage ? Tint.image : Tint.neutral);
    final s = AppStrings.of(context);
    final meta = lecture.exists
        ? '${formatBytes(lecture.size)} · ${formatDay(lecture.dateAdded, s)}'
        : formatDay(lecture.dateAdded, s);

    return SoftCard(
      onTap: onOpen,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      child: Row(
        children: [
          FileThumbnail(
            lecture: lecture,
            width: 58,
            height: 74,
            radius: 14,
            showBadge: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    lecture.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: textDirectionFor(lecture.name),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppPill(
                      lecture.fileType.toUpperCase(),
                      background: tint.background,
                      foreground: tint.foreground,
                    ),
                    Text(
                      meta,
                      style: AppText.caption.copyWith(
                        color: AppColors.muted,
                        fontFeatures: AppText.tabular,
                      ),
                    ),
                    if (!lecture.exists)
                      AppPill(
                        s.missing,
                        background: AppColors.redSoft,
                        foreground: AppColors.red,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: s.fileOptions,
            icon: AppIcon(AppIcons.more, size: 20, color: AppColors.muted),
            onSelected: (value) => value == 'open' ? onOpen() : onDelete(),
            itemBuilder: (_) => [
              if (lecture.exists)
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      AppIcon(AppIcons.book, size: 20, color: AppColors.ink),
                      const SizedBox(width: 12),
                      Text(s.open),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    AppIcon(AppIcons.trash, size: 20, color: AppColors.red),
                    const SizedBox(width: 12),
                    Text(s.delete, style: TextStyle(color: AppColors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.trash, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            AppStrings.of(context).delete,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        IconTile(icon: AppIcons.search, tint: Tint.neutral, size: 60),
        const SizedBox(height: 14),
        Text(s.noMatchTitle, style: AppText.headline),
        const SizedBox(height: 6),
        Text(
          s.noMatchBody,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: s.clearFilters,
          kind: AppButtonKind.secondary,
          onPressed: onClear,
        ),
      ],
    );
  }
}
