import '../data/sample_study_data.dart';
import '../models/study_deck.dart';

// مصدر بيانات صفحة Study.
// حاليًا: بيانات تجريبية. لاحقًا: نكتب كلاسًا آخر يقرأ من SQLite
// (المواد التي يولدها الذكاء الاصطناعي) دون تغيير الواجهة.
abstract class StudyRepository {
  const StudyRepository();

  Future<List<StudyDeck>> loadDecks();
}

class SampleStudyRepository extends StudyRepository {
  const SampleStudyRepository();

  @override
  Future<List<StudyDeck>> loadDecks() async => sampleDecks;
}
