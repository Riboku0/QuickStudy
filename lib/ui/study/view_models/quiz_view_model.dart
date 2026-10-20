import 'package:flutter/foundation.dart';

import '../../../data/repositories/stats/reading_stats_repository.dart';
import '../../../domain/models/quiz_question.dart';
import '../../../domain/models/study_deck.dart';

enum OptionState { idle, correct, wrong, faded }

// منطق الاختبار: الإجابات، النتيجة، الانتقال بين الأسئلة
class QuizViewModel extends ChangeNotifier {
  QuizViewModel({required this.deck, ReadingStatsRepository? stats})
      : _stats = stats,
        _answers = List<int?>.filled(deck.quiz.length, null);

  final StudyDeck deck;
  final ReadingStatsRepository? _stats;

  List<int?> _answers;
  int _index = 0;
  bool _finished = false;

  List<QuizQuestion> get questions => deck.quiz;
  int get total => questions.length;
  int get index => _index;
  bool get finished => _finished;
  bool get isEmpty => questions.isEmpty;
  bool get isLast => _index == total - 1;
  QuizQuestion get current => questions[_index];
  int? get chosen => _answers[_index];
  bool get isAnswered => chosen != null;
  List<int?> get answers => List.unmodifiable(_answers);
  bool get hasFlashcards => deck.flashcards.isNotEmpty;

  int get score {
    var score = 0;
    for (var i = 0; i < total; i++) {
      if (_answers[i] == questions[i].correctIndex) score++;
    }
    return score;
  }

  double get ratio => total == 0 ? 0 : score / total;

  double get progress =>
      total == 0 ? 0 : (_index + (isAnswered ? 1 : 0)) / total;

  OptionState stateOf(int option) {
    final picked = chosen;
    if (picked == null) return OptionState.idle;
    if (option == current.correctIndex) return OptionState.correct;
    if (option == picked) return OptionState.wrong;
    return OptionState.faded;
  }

  // يرجع true إذا كانت الإجابة صحيحة
  bool select(int option) {
    if (isAnswered) return current.isCorrect(chosen!);
    _answers[_index] = option;
    _stats?.addQuestions(1);
    notifyListeners();
    return current.isCorrect(option);
  }

  void next() {
    if (!isAnswered) return;
    if (isLast) {
      _finished = true;
    } else {
      _index++;
    }
    notifyListeners();
  }

  void restart() {
    _answers = List<int?>.filled(total, null);
    _index = 0;
    _finished = false;
    notifyListeners();
  }
}
