import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/repositories/settings/settings_repository.dart';
import '../../../data/repositories/stats/reading_stats_repository.dart';
import '../../../data/repositories/subjects/subject_repository.dart';
import '../../../domain/models/lecture.dart';
import '../../../domain/models/reading_progress.dart';
import '../../home/view_models/home_view_model.dart' show DayPart;

// آخر ما فتحه المستخدم: كتاب من المكتبة أو شابتر من مادة
class ContinueItem {
  const ContinueItem({
    required this.lecture,
    required this.progress,
    required this.title,
    this.subjectName,
  });

  final Lecture lecture;
  final ReadingProgress progress;
  final String title; // اسم الشابتر أو الكتاب
  final String? subjectName; // للشباتر فقط
}

// منطق الرئيسية: المشهد حسب الوقت، متابعة القراءة، اختصارات المذاكرة
// والمكتبة، وأرقام اليوم (عرض فقط، لا إدارة ملفات).
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required LectureRepository lectures,
    required SubjectRepository subjects,
    required ReadingProgressRepository progress,
    required ReadingStatsRepository stats,
    required SettingsRepository settings,
  })  : _lectures = lectures,
        _subjects = subjects,
        _progress = progress,
        _stats = stats,
        _settings = settings {
    for (final source in _sources) {
      source.addListener(notifyListeners);
    }
    // المشهد والتحية وأرقام "اليوم" تتغير مع الوقت حتى لو لم يحدث شيء
    _dayPart = _currentDayPart();
    _day = DateTime.now().day;
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  final LectureRepository _lectures;
  final SubjectRepository _subjects;
  final ReadingProgressRepository _progress;
  final ReadingStatsRepository _stats;
  final SettingsRepository _settings;

  late final Timer _clock;
  late DayPart _dayPart;
  late int _day;

  List<Listenable> get _sources =>
      [_lectures, _subjects, _progress, _stats, _settings];

  String get userName => _settings.userName;

  // صباح حتى 12، ظهر حتى 17، ثم مساء وليل حتى 5 فجرًا
  DayPart get dayPart => _dayPart;

  static DayPart _currentDayPart() {
    final hour = DateTime.now().hour;
    if (hour < 5) return DayPart.evening;
    if (hour < 12) return DayPart.morning;
    if (hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }

  void _tick() {
    final part = _currentDayPart();
    final day = DateTime.now().day;
    if (part == _dayPart && day == _day) return;
    _dayPart = part;
    _day = day;
    notifyListeners();
  }

  // ---- متابعة القراءة ----
  ContinueItem? get continueItem {
    final byId = {for (final l in _lectures.lectures) l.id: l};
    for (final p in _progress.recent) {
      final lecture = byId[p.lectureId];
      if (lecture == null || !lecture.isBook || p.pageCount <= 0) continue;
      if (!lecture.isStudy) {
        return ContinueItem(
          lecture: lecture,
          progress: p,
          title: lecture.title,
        );
      }
      for (final subject in _subjects.subjects) {
        for (final c in _subjects.chaptersOf(subject.id)) {
          if (c.lectureId != lecture.id) continue;
          return ContinueItem(
            lecture: lecture,
            progress: p,
            title: c.title ?? lecture.title,
            subjectName: subject.name,
          );
        }
      }
    }
    return null;
  }

  // ---- الاختصارات ----
  int get books =>
      _lectures.lectures.where((l) => l.isBook && !l.isStudy).length;

  int get subjects => _subjects.subjects.length;

  // ---- أرقام اليوم ----
  int get todayPages => _stats.todayPages;
  int get todaySeconds => _stats.todaySeconds;
  int get todayCards => _stats.todayCards;
  int get todayQuestions => _stats.todayQuestions;

  @override
  void dispose() {
    _clock.cancel();
    for (final source in _sources) {
      source.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
