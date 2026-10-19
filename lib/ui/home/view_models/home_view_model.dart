import 'package:flutter/foundation.dart';

import '../../../data/repositories/bookmarks/bookmark_repository.dart';
import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/repositories/settings/settings_repository.dart';
import '../../../data/services/epub_position_service.dart';
import '../../../domain/models/bookmark.dart';
import '../../../domain/models/lecture.dart';
import '../../../domain/models/reading_progress.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

enum DayPart { morning, afternoon, evening }

// علامة مرجعية مع كتابها (للعرض في المكتبة)
class BookmarkEntry {
  const BookmarkEntry(this.bookmark, this.lecture);

  final Bookmark bookmark;
  final Lecture lecture;
}

// منطق صفحة Home: قراءة ملفات PDF فقط (متابعة القراءة + كل الملفات).
// زر الإضافة هنا يقبل PDF فقط، والصور تُرفع من الرئيسية.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required LectureRepository lectures,
    required ReadingProgressRepository progress,
    required SettingsRepository settings,
    required BookmarkRepository bookmarks,
  }) : _lectures = lectures,
       _progress = progress,
       _settings = settings,
       _bookmarks = bookmarks {
    delete = Command1<void, Lecture>(_delete);
    setBookCategory = Command1<void, (Lecture, String?)>(_setBookCategory);

    // أي تغيير في الملفات (من هنا أو من Library) أو في التقدم يعيد بناء Home
    _lectures.addListener(notifyListeners);
    _progress.addListener(notifyListeners);
    _bookmarks.addListener(notifyListeners);
    _settings.addListener(notifyListeners);
  }

  final LectureRepository _lectures;
  final ReadingProgressRepository _progress;
  final SettingsRepository _settings;
  final BookmarkRepository _bookmarks;

  late final Command1<void, Lecture> delete;
  late final Command1<void, (Lecture, String?)> setBookCategory;

  bool get isLoaded => _lectures.isLoaded;

  // ملفات PDF الموجودة فعلًا، الأحدث إضافة أولًا
  List<Lecture> get pdfs => _lectures.lectures
      .where((l) => l.exists && l.isBook && !l.isStudy)
      .toList(growable: false);

  ReadingProgress? progressFor(Lecture lecture) =>
      _progress.progressFor(lecture.id);

  // آخر ملف فُتح، وإن لم يُفتح شيء بعد فآخر ملف أُضيف
  Lecture? get current {
    final files = pdfs;
    if (files.isEmpty) return null;

    for (final p in _progress.recent) {
      for (final l in files) {
        if (l.id == p.lectureId) return l;
      }
    }
    return files.first;
  }

  // العلامات المرجعية لكتب موجودة فقط، الأحدث أولًا
  List<BookmarkEntry> get bookmarks {
    final byId = {for (final l in pdfs) l.id: l};
    return [
      for (final b in _bookmarks.all)
        if (byId[b.lectureId] case final lecture?) BookmarkEntry(b, lecture),
    ];
  }

  void removeBookmark(Bookmark bookmark) => _bookmarks.remove(bookmark.id);

  // ---- تصنيفات الكتب والبحث ----

  // التصنيفات بالترتيب الذي يظهر في التبويبات
  static const List<String> categories = [
    'novel',
    'study',
    'philosophy',
    'works',
  ];

  // الثابتة ثم ما أضافه المستخدم (التبويبات وقائمة الكتاب)
  List<String> get allCategories => [...categories, ..._settings.bookCategories];

  String? _category; // null = الكل
  String _query = '';

  String? get category => _category;
  String get query => _query;

  void setCategory(String? value) {
    if (value == _category) return;
    _category = value;
    notifyListeners();
  }

  void setQuery(String value) {
    final clean = value.trim();
    if (clean == _query) return;
    _query = clean;
    notifyListeners();
  }

  // الكتب بعد التصنيف والبحث (للشبكة)
  List<Lecture> get visible {
    final q = _query.toLowerCase();
    return [
      for (final l in pdfs)
        if ((_category == null || l.category == _category) &&
            (q.isEmpty || l.title.toLowerCase().contains(q)))
          l,
    ];
  }

  // آخر الكتب المفتوحة (حتى 4) لبطاقة الأعلى، وإن لم يُفتح شيء فآخر ما أُضيف
  List<Lecture> get recent {
    final files = pdfs;
    final byId = {for (final l in files) l.id: l};
    final list = <Lecture>[
      for (final p in _progress.recent)
        if (byId[p.lectureId] case final lecture?) lecture,
    ];
    if (list.isEmpty && files.isNotEmpty) list.add(files.first);
    return list.take(4).toList(growable: false);
  }

  bool hasBookmarks(Lecture lecture) =>
      _bookmarks.all.any((b) => b.lectureId == lecture.id);

  List<Bookmark> bookmarksFor(Lecture lecture) => [
    for (final b in _bookmarks.all)
      if (b.lectureId == lecture.id) b,
  ];

  Future<Result<void>> _setBookCategory((Lecture, String?) input) =>
      _lectures.setCategory(input.$1, input.$2);

  // الواجهة تحوّلها لنص باللغة الحالية
  DayPart get dayPart {
    final hour = DateTime.now().hour;
    if (hour < 12) return DayPart.morning;
    if (hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }

  Future<Result<void>> _delete(Lecture lecture) async {
    final result = await _lectures.delete(lecture);
    if (result is Ok) {
      _progress.remove(lecture.id);
      _bookmarks.removeForLecture(lecture.id);
      if (lecture.isEpub) EpubPositionService.instance.remove(lecture.id);
    }
    return result;
  }

  @override
  void dispose() {
    _lectures.removeListener(notifyListeners);
    _progress.removeListener(notifyListeners);
    _bookmarks.removeListener(notifyListeners);
    _settings.removeListener(notifyListeners);
    delete.dispose();
    setBookCategory.dispose();
    super.dispose();
  }
}
