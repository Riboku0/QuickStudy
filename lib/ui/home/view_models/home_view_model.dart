import 'package:flutter/foundation.dart';

import '../../../data/repositories/bookmarks/bookmark_repository.dart';
import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/services/file_picker_service.dart';
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
    required FilePickerService picker,
    required BookmarkRepository bookmarks,
  })  : _lectures = lectures,
        _progress = progress,
        _picker = picker,
        _bookmarks = bookmarks {
    importPdfs = Command0<ImportSummary>(_importPdfs);
    delete = Command1<void, Lecture>(_delete);

    // أي تغيير في الملفات (من هنا أو من Library) أو في التقدم يعيد بناء Home
    _lectures.addListener(notifyListeners);
    _progress.addListener(notifyListeners);
    _bookmarks.addListener(notifyListeners);
  }

  final LectureRepository _lectures;
  final ReadingProgressRepository _progress;
  final FilePickerService _picker;
  final BookmarkRepository _bookmarks;

  late final Command0<ImportSummary> importPdfs;
  late final Command1<void, Lecture> delete;

  bool get isLoaded => _lectures.isLoaded;

  // ملفات PDF الموجودة فعلًا، الأحدث إضافة أولًا
  List<Lecture> get pdfs => _lectures.lectures
      .where((l) => l.exists && l.isPdf)
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

  // الواجهة تحوّلها لنص باللغة الحالية
  DayPart get dayPart {
    final hour = DateTime.now().hour;
    if (hour < 12) return DayPart.morning;
    if (hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }

  Future<Result<ImportSummary>> _importPdfs() async {
    try {
      final picked = await _picker.pickLectureFiles(
        extensions: FilePickerService.pdfOnly,
      );
      if (picked.isEmpty) return const Result.ok(ImportSummary.none);

      return await _lectures.importFiles(picked);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  Future<Result<void>> _delete(Lecture lecture) async {
    final result = await _lectures.delete(lecture);
    if (result is Ok) {
      _progress.remove(lecture.id);
      _bookmarks.removeForLecture(lecture.id);
    }
    return result;
  }

  @override
  void dispose() {
    _lectures.removeListener(notifyListeners);
    _progress.removeListener(notifyListeners);
    _bookmarks.removeListener(notifyListeners);
    importPdfs.dispose();
    delete.dispose();
    super.dispose();
  }
}
