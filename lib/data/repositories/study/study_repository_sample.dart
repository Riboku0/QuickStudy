import '../../../domain/models/study_deck.dart';
import '../../../utils/result.dart';
import 'sample_study_data.dart';
import 'study_repository.dart';

// بيانات تجريبية لاختبار الواجهة قبل ربط الذكاء الاصطناعي
class SampleStudyRepository extends StudyRepository {
  const SampleStudyRepository();

  @override
  Future<Result<List<StudyDeck>>> getDecks() async => const Result.ok(sampleDecks);
}
