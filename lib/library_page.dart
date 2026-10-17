import 'package:flutter/material.dart';
import 'theme/app_icons.dart';
import 'database/app_database.dart';
import 'home/document_viewer_page.dart';
import 'models/lecture.dart';
import 'services/library_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

enum _TypeFilter { all, pdf, images }

enum _SortOrder { newest, oldest, name }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const double _maxContentWidth = 720;

  final TextEditingController _search = TextEditingController();

  List<Lecture> _lectures = const [];
  bool _loading = true;
  String? _error;

  String _query = '';
  _TypeFilter _filter = _TypeFilter.all;
  _SortOrder _sort = _SortOrder.newest;

  @override
  void initState() {
    super.initState();
    // أي إضافة أو حذف (من Home أو من هنا) تُحدِّث القائمة تلقائيًا
    AppDatabase.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppDatabase.changes.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  // ------------------------- البيانات -------------------------

  Future<void> _load() async {
    try {
      final items = await LibraryService.loadLectures();
      if (!mounted) return;

      setState(() {
        _lectures = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<Lecture> get _visible {
    final query = _query.trim().toLowerCase();

    final list = _lectures.where((lecture) {
      final typeMatches = switch (_filter) {
        _TypeFilter.all => true,
        _TypeFilter.pdf => lecture.isPdf,
        _TypeFilter.images => lecture.isImage,
      };

      return typeMatches &&
          (query.isEmpty || lecture.name.toLowerCase().contains(query));
    }).toList();

    int byDate(Lecture a, Lecture b) {
      final da = a.dateAdded;
      final db = b.dateAdded;

      if (da != null && db != null) {
        final result = da.compareTo(db);
        if (result != 0) return result;
      }

      return a.id.compareTo(b.id);
    }

    switch (_sort) {
      case _SortOrder.newest:
        list.sort((a, b) => byDate(b, a));
      case _SortOrder.oldest:
        list.sort(byDate);
      case _SortOrder.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    return list;
  }

  // تقسيم القائمة إلى مجموعات حسب التاريخ (أو قائمة واحدة عند الترتيب بالاسم)
  List<_Entry> _entries(List<Lecture> visible) {
    if (_sort == _SortOrder.name) {
      return [
        _Entry.header('All files', visible.length),
        for (final lecture in visible) _Entry.file(lecture),
      ];
    }

    final now = DateTime.now();
    final groups = <String, List<Lecture>>{};

    for (final lecture in visible) {
      groups
          .putIfAbsent(_groupOf(lecture.dateAdded, now), () => [])
          .add(lecture);
    }

    return [
      for (final group in groups.entries) ...[
        _Entry.header(group.key, group.value.length),
        for (final lecture in group.value) _Entry.file(lecture),
      ],
    ];
  }

  void _clearFilters() {
    _search.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _query = '';
      _filter = _TypeFilter.all;
    });
  }

  // ------------------------- الإجراءات -------------------------

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    showAppMessage(
      context,
      message,
      tone: error ? MessageTone.error : MessageTone.success,
    );
  }

  Future<void> _open(Lecture lecture) async {
    if (!lecture.exists) {
      _showMessage(
        'This file is no longer in the app. Delete it to clean up the list.',
        error: true,
      );
      return;
    }

    if (!lecture.isPdf && !lecture.isImage) {
      _showMessage('This file type cannot be opened.', error: true);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerPage(
          fileId: lecture.id,
          fileName: lecture.name,
          filePath: lecture.filePath,
          fileType: lecture.fileType,
        ),
      ),
    );
  }

  // يسأل أولًا، ثم يحذف. يرجع true إذا تم الحذف.
  Future<bool> _confirmAndDelete(Lecture lecture) async {
    final confirmed = await confirmDeleteFile(context, lecture.name);

    if (!confirmed) return false;

    try {
      await LibraryService.deleteLecture(lecture);
      _showMessage('File deleted.');
      return true;
    } catch (e) {
      debugPrint('Library delete error: $e');
      _showMessage('The file was not deleted. Try again.', error: true);
      return false;
    }
  }

  void _removeLocally(Lecture lecture) {
    setState(() {
      _lectures = _lectures.where((l) => l.id != lecture.id).toList();
    });
  }

  Future<void> _deleteFromMenu(Lecture lecture) async {
    if (await _confirmAndDelete(lecture)) _removeLocally(lecture);
  }

  // ------------------------- الواجهة -------------------------

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final insets = MediaQuery.paddingOf(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: t.ink));
    }

    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Your library did not load',
          message: _error!,
          actionLabel: 'Try again',
          onAction: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    }

    if (_lectures.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: const EmptyState(
          icon: Icons.folder_open_rounded,
          title: 'Your library is empty',
          message:
              'Upload lecture files from Home. Everything you add is listed here.',
        ),
      );
    }

    final visible = _visible;
    final entries = _entries(visible);

    return RefreshIndicator(
      color: t.ink,
      edgeOffset: insets.top,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, insets.top + 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: ConstrainedContent(
                maxWidth: _maxContentWidth,
                child: _buildTop(),
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, insets.bottom + 24),
              sliver: SliverToBoxAdapter(
                child: _NoResults(onClear: _clearFilters),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, insets.bottom + 24),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) => ConstrainedContent(
                  maxWidth: _maxContentWidth,
                  child: _buildEntry(entries[i], first: i == 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTop() {
    final t = AppTokens.of(context);
    final pdfCount = _lectures.where((l) => l.isPdf).length;
    final imageCount = _lectures.where((l) => l.isImage).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTitle(
          'Library',
          trailing: AppPill(
            '${_lectures.length} ${_lectures.length == 1 ? 'file' : 'files'}',
            background: t.chip,
            foreground: t.muted,
          ),
        ),
        const SizedBox(height: 24),
        _StatsCard(lectures: _lectures),
        const SizedBox(height: 18),
        _SearchField(
          controller: _search,
          hasText: _query.isNotEmpty,
          onChanged: (value) => setState(() => _query = value),
          onClear: () {
            _search.clear();
            setState(() => _query = '');
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: _lectures.length,
                      selected: _filter == _TypeFilter.all,
                      onTap: () => setState(() => _filter = _TypeFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'PDF',
                      count: pdfCount,
                      selected: _filter == _TypeFilter.pdf,
                      onTap: () => setState(() => _filter = _TypeFilter.pdf),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Images',
                      count: imageCount,
                      selected: _filter == _TypeFilter.images,
                      onTap: () =>
                          setState(() => _filter = _TypeFilter.images),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SortButton(
              value: _sort,
              onChanged: (value) => setState(() => _sort = value),
            ),
          ],
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildEntry(_Entry entry, {required bool first}) {
    final lecture = entry.lecture;

    if (lecture == null) {
      return Padding(
        padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 12),
        child: SectionHeader(entry.title!, trailing: '${entry.count}'),
      );
    }

    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // سحب لليسار = حذف (بعد التأكيد)
      child: Dismissible(
        key: ValueKey('lecture_${lecture.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmAndDelete(lecture),
        onDismissed: (_) => _removeLocally(lecture),
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: t.wrong,
            borderRadius: BorderRadius.circular(t.radiusMedium),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        child: _LectureTile(
          lecture: lecture,
          onOpen: () => _open(lecture),
          onDelete: () => _deleteFromMenu(lecture),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عنصر في القائمة: عنوان مجموعة أو ملف
// ---------------------------------------------------------------------------

class _Entry {
  const _Entry.header(this.title, this.count) : lecture = null;
  const _Entry.file(this.lecture)
      : title = null,
        count = 0;

  final String? title;
  final int count;
  final Lecture? lecture;
}

String _groupOf(DateTime? date, DateTime now) {
  if (date == null) return 'Earlier';

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;

  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return 'This week';
  if (date.year == now.year && date.month == now.month) return 'This month';
  return 'Earlier';
}

// ---------------------------------------------------------------------------
// تنسيق الحجم والتاريخ (بدون حزم إضافية)
// ---------------------------------------------------------------------------

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown date';

  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;

  // اليوم وأمس: الوقت فقط (عنوان المجموعة يوضح اليوم)
  if (days >= 0 && days < 2) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  final month = _months[date.month - 1];
  return date.year == now.year
      ? '$month ${date.day}'
      : '$month ${date.day}, ${date.year}';
}

// ---------------------------------------------------------------------------
// إحصائيات حقيقية من قاعدة البيانات
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.lectures});

  final List<Lecture> lectures;

  @override
  Widget build(BuildContext context) {
    final pdfs = lectures.where((l) => l.isPdf).length;
    final images = lectures.where((l) => l.isImage).length;
    final storage = lectures.fold<int>(0, (sum, l) => sum + l.size);

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          _Stat(value: '${lectures.length}', label: 'Files'),
          _Stat(value: '$pdfs', label: 'PDFs'),
          _Stat(value: '$images', label: 'Images'),
          _Stat(value: _formatSize(storage), label: 'Storage'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.title.copyWith(
                height: 1,
                fontFeatures: AppText.tabular,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppText.caption.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// البحث والتصفية والترتيب
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = BorderRadius.circular(18);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: t.shadow),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.search,
        cursorColor: t.ink,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: 'Search your files',
          hintStyle: AppText.body.copyWith(color: t.muted),
          filled: true,
          fillColor: t.surface,
          prefixIcon: Icon(Icons.search_rounded, color: t.muted),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded, color: t.muted),
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: t.ink, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
   final foreground = selected ? t.primary : t.ink;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? t.primarySoft : t.surface,
        shape: StadiumBorder(
          side: BorderSide(
             color: selected ? t.primaryLine : t.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                   color: selected ? t.surface : t.chip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final _SortOrder value;
  final ValueChanged<_SortOrder> onChanged;

  static const Map<_SortOrder, String> _labels = {
    _SortOrder.newest: 'Newest first',
    _SortOrder.oldest: 'Oldest first',
    _SortOrder.name: 'Name (A to Z)',
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return PopupMenuButton<_SortOrder>(
      tooltip: 'Sort files',
      initialValue: value,
      onSelected: onChanged,
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final entry in _labels.entries)
          PopupMenuItem(
            value: entry.key,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: entry.key == value
                      ? Icon(Icons.check_rounded, size: 18, color: t.ink)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(entry.value),
              ],
            ),
          ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
         color: t.chip,
          shape: BoxShape.circle,
        ),
        child: Icon(AppIcons.sort, size: 21, color: t.ink),
      ),
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
    final t = AppTokens.of(context);

    // نفس ألوان أنواع الملفات في Home
    final (background, foreground, icon) = lecture.isPdf
        ? (t.wrongSoft, t.wrong, Icons.picture_as_pdf_rounded)
        : lecture.isImage
            ? (t.infoSoft, t.info, Icons.image_rounded)
            : (t.chip, t.muted, Icons.description_rounded);

    final meta = lecture.exists
        ? '${_formatSize(lecture.size)}, ${_formatDate(lecture.dateAdded)}'
        : _formatDate(lecture.dateAdded);

    return SoftCard(
      onTap: onOpen,
      radius: t.radiusMedium,
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: foreground, size: 26),
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppPill(
                      lecture.fileType.toUpperCase(),
                      background: background,
                      foreground: foreground,
                    ),
                    Text(
                      meta,
                      style: AppText.caption.copyWith(
                        color: t.muted,
                        fontFeatures: AppText.tabular,
                      ),
                    ),
                    if (!lecture.exists)
                      AppPill(
                        'Missing',
                        background: t.wrongSoft,
                        foreground: t.wrong,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'File options',
            icon: Icon(Icons.more_vert_rounded, color: t.muted),
            color: t.surface,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) => value == 'open' ? onOpen() : onDelete(),
            itemBuilder: (_) => [
              if (lecture.exists)
                const PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Open'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: t.wrong),
                    const SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: t.wrong)),
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

// ---------------------------------------------------------------------------
// لا توجد نتائج للبحث / التصفية
// ---------------------------------------------------------------------------

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: t.chip, shape: BoxShape.circle),
          child: Icon(Icons.search_off_rounded, size: 30, color: t.muted),
        ),
        const SizedBox(height: 14),
        const Text('No files match', style: AppText.headline),
        const SizedBox(height: 6),
        Text(
          'Try another name, or clear the search and filters.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: t.muted),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Clear search and filters',
          kind: AppButtonKind.secondary,
          onPressed: onClear,
        ),
      ],
    );
  }
}
