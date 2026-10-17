import 'package:flutter/foundation.dart';

import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../domain/models/lecture.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

enum TypeFilter { all, pdf, images }

enum SortOrder { newest, oldest, name }

// مجموعات التاريخ (الواجهة تترجم الاسم)
enum DateBucket { all, today, yesterday, thisWeek, thisMonth, earlier }

class LibraryGroup {
  const LibraryGroup(this.bucket, this.items);

  final DateBucket bucket;
  final List<Lecture> items;
}

// منطق المكتبة: الرفع والبحث والتصفية والترتيب والتجميع والحذف
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required LectureRepository lectures,
    required FilePickerService picker,
  })  : _lectures = lectures,
        _picker = picker {
    reload = Command0<void>(_lectures.load);
    importFiles = Command0<ImportSummary>(_importFiles);
    delete = Command1<void, Lecture>(_lectures.delete);
    _lectures.addListener(notifyListeners);
  }

  final LectureRepository _lectures;
  final FilePickerService _picker;

  late final Command0<void> reload;
  late final Command0<ImportSummary> importFiles;
  late final Command1<void, Lecture> delete;

  String _query = '';
  TypeFilter _filter = TypeFilter.all;
  SortOrder _sort = SortOrder.newest;

  String get query => _query;
  TypeFilter get filter => _filter;
  SortOrder get sort => _sort;
  bool get isLoaded => _lectures.isLoaded;
  bool get hasFilters => _query.isNotEmpty || _filter != TypeFilter.all;

  List<Lecture> get all => _lectures.lectures;
  int get pdfCount => all.where((l) => l.isPdf).length;
  int get imageCount => all.where((l) => l.isImage).length;
  int get pdfBytes =>
      all.where((l) => l.isPdf).fold(0, (sum, l) => sum + l.size);
  int get totalBytes => all.fold(0, (sum, l) => sum + l.size);

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setFilter(TypeFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }

  void setSort(SortOrder value) {
    if (value == _sort) return;
    _sort = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _filter = TypeFilter.all;
    notifyListeners();
  }

  List<Lecture> get visible {
    final q = _query.trim().toLowerCase();

    final list = all.where((l) {
      final typeMatches = switch (_filter) {
        TypeFilter.all => true,
        TypeFilter.pdf => l.isPdf,
        TypeFilter.images => l.isImage,
      };
      return typeMatches && (q.isEmpty || l.name.toLowerCase().contains(q));
    }).toList();

    int byDate(Lecture a, Lecture b) {
      final da = a.dateAdded;
      final db = b.dateAdded;
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
      }
      return a.id.compareTo(b.id);
    }

    switch (_sort) {
      case SortOrder.newest:
        list.sort((a, b) => byDate(b, a));
      case SortOrder.oldest:
        list.sort(byDate);
      case SortOrder.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return list;
  }

  // مجموعات حسب التاريخ (أو مجموعة واحدة عند الترتيب بالاسم)
  List<LibraryGroup> get groups {
    final items = visible;
    if (items.isEmpty) return const [];

    if (_sort == SortOrder.name) return [LibraryGroup(DateBucket.all, items)];

    final now = DateTime.now();
    final map = <DateBucket, List<Lecture>>{};
    for (final lecture in items) {
      map.putIfAbsent(_groupOf(lecture.dateAdded, now), () => []).add(lecture);
    }

    return [for (final e in map.entries) LibraryGroup(e.key, e.value)];
  }

  static DateBucket _groupOf(DateTime? date, DateTime now) {
    if (date == null) return DateBucket.earlier;

    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;

    if (days <= 0) return DateBucket.today;
    if (days == 1) return DateBucket.yesterday;
    if (days < 7) return DateBucket.thisWeek;
    if (date.year == now.year && date.month == now.month) {
      return DateBucket.thisMonth;
    }
    return DateBucket.earlier;
  }

  Future<Result<ImportSummary>> _importFiles() async {
    try {
      final picked = await _picker.pickLectureFiles();
      if (picked.isEmpty) return const Result.ok(ImportSummary.none);

      return await _lectures.importFiles(picked);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  @override
  void dispose() {
    _lectures.removeListener(notifyListeners);
    reload.dispose();
    importFiles.dispose();
    delete.dispose();
    super.dispose();
  }
}
