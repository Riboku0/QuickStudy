// سؤال اختيار من متعدد
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  bool isCorrect(int index) => index == correctIndex;

  String get correctAnswer => options[correctIndex];

  // يتحقق من صحة البيانات (مهم لاحقًا مع ردود الذكاء الاصطناعي)
  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final question = (map['question'] as String?)?.trim() ?? '';
    final options = (map['options'] as List?)
            ?.map((o) => o.toString().trim())
            .where((o) => o.isNotEmpty)
            .toList() ??
        const <String>[];
    final correct = map['correctIndex'];

    if (question.isEmpty) {
      throw const FormatException('Quiz question text is empty.');
    }
    if (options.length < 2) {
      throw const FormatException('Quiz question needs at least 2 options.');
    }
    if (correct is! int || correct < 0 || correct >= options.length) {
      throw const FormatException('Quiz question has an invalid answer index.');
    }

    final explanation = (map['explanation'] as String?)?.trim();

    return QuizQuestion(
      id: '${map['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      question: question,
      options: options,
      correctIndex: correct,
      explanation:
          (explanation == null || explanation.isEmpty) ? null : explanation,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };
}
