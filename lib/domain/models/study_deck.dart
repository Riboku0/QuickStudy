import 'flashcard.dart';
import 'quiz_question.dart';

// مجموعة مواد مذاكرة لمحاضرة واحدة
class StudyDeck {
  const StudyDeck({
    required this.id,
    required this.title,
    required this.subject,
    this.fileId,
    this.isSample = false,
    this.flashcards = const [],
    this.quiz = const [],
  });

  final String id;
  final String title;
  final String subject;

  // رقم الملف في SQLite (يُربط لاحقًا بالمحاضرة الأصلية)
  final int? fileId;

  // بيانات تجريبية مؤقتة
  final bool isSample;

  final List<Flashcard> flashcards;
  final List<QuizQuestion> quiz;
}
