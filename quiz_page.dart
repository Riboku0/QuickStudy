import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'models/quiz_question.dart';
import 'models/study_deck.dart';
import 'theme/app_theme.dart';
import 'widgets/brutal_widgets.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.deck});

  final StudyDeck deck;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final ScrollController _scroll = ScrollController();

  late List<int?> _answers; // إجابة المستخدم لكل سؤال (null = لم يُجب)
  int _index = 0;
  bool _finished = false;

  List<QuizQuestion> get _questions => widget.deck.quiz;

  int get _score {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].correctIndex) score++;
    }
    return score;
  }

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(_questions.length, null);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int option) {
    if (_answers[_index] != null) return;

    if (_questions[_index].isCorrect(option)) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    setState(() => _answers[_index] = option);

    // إظهار التوضيح أسفل الخيارات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _next() {
    setState(() {
      if (_index < _questions.length - 1) {
        _index++;
      } else {
        _finished = true;
      }
    });

    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _restart() {
    setState(() {
      _answers = List<int?>.filled(_questions.length, null);
      _index = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: brutalAppBar(
        context,
        subtitle: 'Quiz',
        title: widget.deck.title,
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_questions.isEmpty) {
      return EmptyState(
        icon: Icons.quiz_outlined,
        title: 'No questions yet',
        message: 'This deck does not have a quiz.',
        actionLabel: 'Back to Study',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    return _finished ? _buildResults() : _buildQuestion();
  }

  // ------------------------- السؤال -------------------------

  Widget _buildQuestion() {
    final t = BrutalTheme.of(context);
    final total = _questions.length;
    final question = _questions[_index];
    final chosen = _answers[_index];
    final answered = chosen != null;
    final last = _index == total - 1;
    final rtl = textDirectionFor(question.question) == TextDirection.rtl;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'QUESTION ${_index + 1} / $total',
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  BrutalTag('Score $_score', color: t.accent),
                ],
              ),
              const SizedBox(height: 10),
              BrutalProgressBar(
                value: (_index + (answered ? 1 : 0)) / total,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              BrutalBox(
                padding: const EdgeInsets.all(20),
                child: Text(
                  question.question,
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < question.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OptionTile(
                    label: _letter(i, rtl),
                    text: question.options[i],
                    state: _stateOf(question, i, chosen),
                    rtl: rtl,
                    onTap: answered ? null : () => _select(i),
                  ),
                ),
              if (chosen != null) ...[
                const SizedBox(height: 4),
                _Feedback(question: question, chosen: chosen, rtl: rtl),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: BrutalButton(
              label: !answered
                  ? 'Choose an answer'
                  : (last ? 'See results' : 'Next question'),
              icon: !answered
                  ? null
                  : (last ? Icons.flag_rounded : Icons.arrow_forward_rounded),
              onPressed: answered ? _next : null,
            ),
          ),
        ),
      ],
    );
  }

  static const List<String> _latin = ['A', 'B', 'C', 'D', 'E', 'F'];
  static const List<String> _arabic = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];

  String _letter(int i, bool rtl) {
    final letters = rtl ? _arabic : _latin;
    return i < letters.length ? letters[i] : '${i + 1}';
  }

  _OptionState _stateOf(QuizQuestion q, int i, int? chosen) {
    if (chosen == null) return _OptionState.idle;
    if (i == q.correctIndex) return _OptionState.correct;
    if (i == chosen) return _OptionState.wrong;
    return _OptionState.faded;
  }

  // ------------------------- النتيجة -------------------------

  Widget _buildResults() {
    final t = BrutalTheme.of(context);
    final total = _questions.length;
    final score = _score;
    final percent = (score * 100 / total).round();

    final (title, message) = percent >= 80
        ? ('GREAT JOB', 'You know this material well.')
        : percent >= 50
            ? ('GOOD EFFORT', 'Review the questions you missed and try again.')
            : ('KEEP GOING', 'Go through the flashcards, then retake the quiz.');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BrutalBox(
          color: t.accent,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'YOUR SCORE',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$score / $total',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$percent%',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BrutalButton(
          label: 'Retake quiz',
          icon: Icons.replay_rounded,
          onPressed: _restart,
        ),
        const SizedBox(height: 12),
        BrutalButton(
          label: 'Back to Study',
          icon: Icons.arrow_back_rounded,
          variant: BrutalVariant.light,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 28),
        const SectionLabel('Review'),
        const SizedBox(height: 12),
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewRow(
              number: i + 1,
              question: _questions[i],
              chosen: _answers[i],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// خيار إجابة
// ---------------------------------------------------------------------------

enum _OptionState { idle, correct, wrong, faded }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.state,
    required this.rtl,
    required this.onTap,
  });

  final String label;
  final String text;
  final _OptionState state;
  final bool rtl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    final (background, foreground) = switch (state) {
      _OptionState.correct => (t.correct, t.surface),
      _OptionState.wrong => (t.wrong, t.surface),
      _ => (t.surface, t.ink),
    };

    return Opacity(
      opacity: state == _OptionState.faded ? 0.5 : 1,
      child: BrutalBox(
        color: background,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        semanticLabel: '$label. $text',
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == _OptionState.idle ? t.accent : t.surface,
                  borderRadius: BorderRadius.circular(t.radius),
                  border: Border.all(color: t.ink, width: 2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              if (state == _OptionState.correct)
                Icon(Icons.check_circle_rounded, color: foreground),
              if (state == _OptionState.wrong)
                Icon(Icons.cancel_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// صحيح / خطأ + التوضيح
// ---------------------------------------------------------------------------

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.question,
    required this.chosen,
    required this.rtl,
  });

  final QuizQuestion question;
  final int chosen;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final correct = question.isCorrect(chosen);
    final color = correct ? t.correct : t.wrong;
    final explanation = question.explanation;

    return BrutalBox(
      shadow: false,
      color: Color.alphaBlend(color.withValues(alpha: 0.15), t.surface),
      padding: const EdgeInsets.all(16),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  correct ? 'CORRECT!' : 'NOT QUITE',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            if (!correct) ...[
              const SizedBox(height: 8),
              Text(
                'Correct answer: ${question.correctAnswer}',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (explanation != null) ...[
              const SizedBox(height: 8),
              Text(
                explanation,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// مراجعة الإجابات في صفحة النتيجة
// ---------------------------------------------------------------------------

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.number,
    required this.question,
    required this.chosen,
  });

  final int number;
  final QuizQuestion question;
  final int? chosen;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final picked = chosen;
    final correct = picked != null && question.isCorrect(picked);
    final yourAnswer = picked == null ? '—' : question.options[picked];

    return BrutalBox(
      shadow: false,
      padding: const EdgeInsets.all(14),
      child: Directionality(
        textDirection: textDirectionFor(question.question),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct ? t.correct : t.wrong,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${question.question}',
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your answer: $yourAnswer',
                    style: TextStyle(
                      color: correct ? t.muted : t.wrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!correct)
                    Text(
                      'Correct: ${question.correctAnswer}',
                      style: TextStyle(
                        color: t.correct,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
