import 'package:flutter/foundation.dart';

import '../../../data/repositories/bookmarks/bookmark_repository.dart';
import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/repositories/settings/settings_repository.dart';
import '../../../data/repositories/stats/reading_stats_repository.dart';
import '../../../data/repositories/subjects/subject_repository.dart';
import '../../../domain/models/reading_progress.dart';
import '../../home/view_models/home_view_model.dart' show DayPart;

// منطق الرئيسية: لوحة أرقام للمكتبة والمذاكرة (عرض فقط، لا إدارة ملفات).
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required LectureRepository lectures,
    required SubjectRepository subjects,
    required ReadingProgressRepository progress,
    required BookmarkRepository bookmarks,
    required ReadingStatsRepository stats,
    required SettingsRepository settings,
  })  : _lectures = lectures,
        _subjects = subjects,
        _progress = progress,
        _bookmarks = bookmarks,
        _stats = stats,
        _settings = settings {
    for (final source in _sources) {
      source.addListener(notifyListeners);
    }
  }

  final LectureRepository _lectures;
  final SubjectRepository _subjects;
  final ReadingProgressRepository _progress;
  final BookmarkRepository _bookmarks;
  final ReadingStatsRepository _stats;
  final SettingsRepository _settings;

  List<Listenable> get _sources =>
      [_lectures, _subjects, _progress, _bookmarks, _stats, _settings];

  String get userName => _settings.userName;

  DayPart get dayPart {
    final hour = DateTime.now().hour;
    if (hour < 12) return DayPart.morning;
    if (hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }

  // ---- وقت القراءة ----
  int get todaySeconds => _stats.todaySeconds;
  int get weekSeconds => _stats.weekSeconds;
  int get totalSeconds => _stats.totalSeconds;
  int get streakDays => _stats.streakDays;
  int get sessions => _stats.sessions;
  List<(DateTime, int)> get lastWeek => _stats.lastWeek;

  // ---- المكتبة ----
  Iterable<ReadingProgress> _progressOf(bool study) sync* {
    for (final l in _lectures.lectures) {
      if (!l.isBook || l.isStudy != study) continue;
      final p = _progress.progressFor(l.id);
      if (p != null && p.pageCount > 0) yield p;
    }
  }

  int get books =>
      _lectures.lectures.where((l) => l.isBook && !l.isStudy).length;

  int get booksFinished =>
      _progressOf(false).where((p) => p.page >= p.pageCount).length;

  int get booksInProgress =>
      _progressOf(false).where((p) => p.page < p.pageCount).length;

  // الصفحات التي وصلت إليها في كل الملفات (المكتبة والمذاكرة)
  int get pagesRead =>
      [..._progressOf(false), ..._progressOf(true)].fold(0, (a, p) => a + p.page);

  int get bookmarks => _bookmarks.all.length;

  // ---- المذاكرة ----
  int get subjects => _subjects.subjects.length;

  int get chapters => _subjects.subjects
      .fold(0, (a, s) => a + _subjects.chapterCount(s.id));

  int get chaptersFinished {
    var n = 0;
    for (final s in _subjects.subjects) {
      for (final c in _subjects.chaptersOf(s.id)) {
        final p = _progress.progressFor(c.lectureId);
        if (p != null && p.pageCount > 0 && p.page >= p.pageCount) n++;
      }
    }
    return n;
  }

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
