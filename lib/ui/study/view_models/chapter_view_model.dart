import 'package:flutter/foundation.dart';

import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/progress/reading_progress_repository.dart';
import '../../../data/repositories/study/study_repository.dart';
import '../../../data/repositories/subjects/subject_repository.dart';
import '../../../domain/models/lecture.dart';
import '../../../domain/models/reading_progress.dart';
import '../../../domain/models/study_deck.dart';
import '../../../domain/models/subject.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

// منطق صفحة الشابتر: الملف وتقدم قراءته، ومجموعة تجريبية للبطاقات والاختبار
// حتى يولّدها الذكاء الاصطناعي من الشابتر نفسه (المرحلة 4).
class ChapterViewModel extends ChangeNotifier {
  ChapterViewModel({
    required this.chapterId,
    required SubjectRepository subjects,
    required LectureRepository lectures,
    required ReadingProgressRepository progress,
    required StudyRepository studies,
  })  : _subjects = subjects,
        _lectures = lectures,
        _progress = progress,
        _studies = studies {
    _subjects.addListener(notifyListeners);
    _lectures.addListener(notifyListeners);
    _progress.addListener(notifyListeners);
    loadDeck = Command0<void>(_loadDeck)..execute();
  }

  final int chapterId;
  final SubjectRepository _subjects;
  final LectureRepository _lectures;
  final ReadingProgressRepository _progress;
  final StudyRepository _studies;

  late final Command0<void> loadDeck;

  StudyDeck? _deck;

  Chapter? get chapter => _subjects.chapter(chapterId);

  Subject? get subject {
    final c = chapter;
    return c == null ? null : _subjects.subject(c.subjectId);
  }

  Lecture? get lecture {
    final c = chapter;
    if (c == null) return null;
    for (final l in _lectures.lectures) {
      if (l.id == c.lectureId) return l;
    }
    return null;
  }

  String get title => chapter?.title ?? lecture?.title ?? '';

  // رقم الشابتر داخل مادته (يبدأ من 1)
  int get number {
    final c = chapter;
    if (c == null) return 1;
    final list = _subjects.chaptersOf(c.subjectId);
    return list.indexWhere((x) => x.id == c.id) + 1;
  }

  ReadingProgress? get progress {
    final l = lecture;
    return l == null ? null : _progress.progressFor(l.id);
  }

  StudyDeck? get deck => _deck;

  Future<Result<void>> _loadDeck() async {
    final result = await _studies.getDecks();
    switch (result) {
      case Ok(:final value):
        _deck = value.isEmpty ? null : value.first;
        notifyListeners();
        return const Result.ok(null);
      case Err(:final error):
        return Result.error(error);
    }
  }

  @override
  void dispose() {
    _subjects.removeListener(notifyListeners);
    _lectures.removeListener(notifyListeners);
    _progress.removeListener(notifyListeners);
    loadDeck.dispose();
    super.dispose();
  }
}
