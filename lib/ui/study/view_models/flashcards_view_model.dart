import 'package:flutter/foundation.dart';

import '../../../domain/models/flashcard.dart';
import '../../../domain/models/study_deck.dart';

// منطق جلسة البطاقات: البطاقة الحالية، التالي/السابق، نهاية المجموعة.
// (حالة قلب البطاقة نفسها حالة بصرية مؤقتة، تبقى داخل الويدجت)
class FlashcardsViewModel extends ChangeNotifier {
  FlashcardsViewModel({required this.deck});

  final StudyDeck deck;

  int _index = 0;
  bool _finished = false;

  List<Flashcard> get cards => deck.flashcards;
  int get total => cards.length;
  int get index => _index;
  bool get finished => _finished;
  bool get isEmpty => cards.isEmpty;
  bool get isFirst => _index == 0;
  bool get isLast => _index == total - 1;
  Flashcard get current => cards[_index];
  double get progress => total == 0 ? 0 : (_index + 1) / total;
  bool get hasQuiz => deck.quiz.isNotEmpty;

  void next() {
    if (isLast) {
      _finished = true;
    } else {
      _index++;
    }
    notifyListeners();
  }

  void previous() {
    if (isFirst) return;
    _index--;
    notifyListeners();
  }

  void restart() {
    _index = 0;
    _finished = false;
    notifyListeners();
  }
}
