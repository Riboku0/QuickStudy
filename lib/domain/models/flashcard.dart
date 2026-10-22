// بطاقة مذاكرة: سؤال في الوجه الأمامي وجواب في الخلف
class Flashcard {
  const Flashcard({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;

  // جاهزة لاستقبال نتيجة الذكاء الاصطناعي (JSON) أو صف من SQLite لاحقًا
  factory Flashcard.fromMap(Map<String, dynamic> map) {
    final question = (map['question'] as String?)?.trim() ?? '';
    final answer = (map['answer'] as String?)?.trim() ?? '';

    if (question.isEmpty || answer.isEmpty) {
      throw const FormatException('Flashcard needs a question and an answer.');
    }

    return Flashcard(
      id: '${map['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      question: question,
      answer: answer,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'question': question,
    'answer': answer,
  };
}
