import '../../../domain/models/study_deck.dart';
import '../../../utils/result.dart';

// مصدر مجموعات المذاكرة.
// الآن: بيانات تجريبية. لاحقًا: مجموعات يولدها الذكاء الاصطناعي ومحفوظة في SQLite.
abstract class StudyRepository {
  const StudyRepository();

  Future<Result<List<StudyDeck>>> getDecks();
}
