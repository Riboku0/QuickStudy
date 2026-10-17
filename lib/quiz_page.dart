import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'flashcards_page.dart';
import 'models/quiz_question.dart';
import 'models/study_deck.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

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
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
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

  void _openFlashcards() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FlashcardsPage(deck: widget.deck),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: studyAppBar(
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
        title: 'No questions in this deck',
        message: 'A quiz made from this lecture will appear here.',
        actionLabel: 'Back to decks',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    return _finished ? _buildResults() : _buildQuestion();
  }

  // ------------------------- السؤال -------------------------

  Widget _buildQuestion() {
    final t = AppTokens.of(context);
    final total = _questions.length;
    final question = _questions[_index];
    final chosen = _answers[_index];
    final answered = chosen != null;
    final last = _index == total - 1;
    final direction = textDirectionFor(question.question);
    final rtl = direction == TextDirection.rtl;

    return ConstrainedContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Question ${_index + 1} of $total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    AppPill(
                      '$_score correct',
                      background: t.correctSoft,
                      foreground: t.correct,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressTrack(value: (_index + (answered ? 1 : 0)) / total),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              children: [
                Text(
                  question.question,
                  textDirection: direction,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      label: _letter(i, rtl),
                      text: question.options[i],
                      state: _stateOf(question, i, chosen),
                      direction: direction,
                      onTap: answered ? null : () => _select(i),
                    ),
                  ),
                if (chosen != null) ...[
                  const SizedBox(height: 8),
                  _Feedback(
                    question: question,
                    chosen: chosen,
                    direction: direction,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                label: !answered
                    ? 'Choose an answer'
                    : (last ? 'See my score' : 'Next question'),
                icon: !answered
                    ? null
                    : (last ? Icons.flag_rounded : Icons.arrow_forward_rounded),
                iconAfter: true,
                onPressed: answered ? _next : null,
              ),
            ),
          ),
        ],
      ),
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
    final t = AppTokens.of(context);
    final total = _questions.length;
    final score = _score;
    final ratio = score / total;

    final (title, message) = ratio >= 0.8
        ? ('Great work', 'You know this lecture well.')
        : ratio >= 0.5
            ? ('Good effort', 'Look over the questions you missed, then try again.')
            : ('Keep practicing', 'Go through the flashcards, then retake the quiz.');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ConstrainedContent(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                 gradient: AppGradients.tinted,
                  border: Border.all(color: t.primaryLine),
                  borderRadius: BorderRadius.circular(t.radiusLarge),
                  boxShadow: AppTokens.heroShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                  child: Column(
                    children: [
                      _ScoreRing(score: score, total: total),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: TextStyle(
                         
                          color: t.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                        color: t.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Retake the quiz',
                icon: Icons.replay_rounded,
                kind: AppButtonKind.accent,
                onPressed: _restart,
              ),
              const SizedBox(height: 10),
              if (widget.deck.flashcards.isNotEmpty) ...[
                AppButton(
                  label: 'Review the flashcards',
                  icon: Icons.style_rounded,
                  onPressed: _openFlashcards,
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: 'Back to decks',
                kind: AppButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 30),
              SectionHeader('YOUR ANSWERS', trailing: '$score / $total'),
              const SizedBox(height: 14),
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
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// حلقة النتيجة (تمتلئ مرة واحدة عند ظهور الشاشة)
// ---------------------------------------------------------------------------

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.total});

  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final ratio = total == 0 ? 0.0 : score / total;

    return Semantics(
      label: 'Score $score out of $total',
      excludeSemantics: true,
      child: SizedBox(
        width: 140,
        height: 140,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
           color: t.primary,
                backgroundColor: t.accentSoft,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score/$total',
                      style: TextStyle(
                        color: t.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        color: t.surface.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    required this.direction,
    required this.onTap,
  });

  final String label;
  final String text;
  final _OptionState state;
  final TextDirection direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = BorderRadius.circular(18);

    // ألوان بدل Opacity (أخف في الرسم)
    final (background, border, badge, badgeText, textColor) = switch (state) {
      _OptionState.idle => (
          t.surface,
          t.ink.withValues(alpha: 0.08),
          t.chip,
          t.ink,
          t.ink,
        ),
      _OptionState.correct => (
          t.correctSoft,
          t.correct,
          t.correct,
          t.surface,
          t.ink,
        ),
      _OptionState.wrong => (
          t.wrongSoft,
          t.wrong,
          t.wrong,
          t.surface,
          t.ink,
        ),
      _OptionState.faded => (
          t.surface.withValues(alpha: 0.6),
          Colors.transparent,
          t.chip,
          t.muted,
          t.muted,
        ),
    };

    final icon = switch (state) {
      _OptionState.correct => Icons.check_rounded,
      _OptionState.wrong => Icons.close_rounded,
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      label: '$label. $text',
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: border, width: 1.6),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Directionality(
                textDirection: direction,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badge,
                        shape: BoxShape.circle,
                      ),
                      child: icon != null
                          ? Icon(icon, size: 18, color: badgeText)
                          : Text(
                              label,
                              style: TextStyle(
                                color: badgeText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    required this.direction,
  });

  final QuizQuestion question;
  final int chosen;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final correct = question.isCorrect(chosen);
    final explanation = question.explanation;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: correct ? t.correctSoft : t.wrongSoft,
        borderRadius: BorderRadius.circular(t.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.info_rounded,
                size: 20,
                color: correct ? t.correct : t.wrong,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'Correct' : 'Not quite',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!correct) ...[
            const SizedBox(height: 10),
            Text(
              'The answer is: ${question.correctAnswer}',
              textDirection: direction,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
          if (explanation != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Text(
                explanation,
                textDirection: direction,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ],
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
    final t = AppTokens.of(context);
    final picked = chosen;
    final correct = picked != null && question.isCorrect(picked);
    final yourAnswer = picked == null ? 'No answer' : question.options[picked];

    return SoftCard(
      radius: t.radiusMedium,
      padding: const EdgeInsets.all(14),
      child: Directionality(
        textDirection: textDirectionFor(question.question),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: correct ? t.correctSoft : t.wrongSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                correct ? Icons.check_rounded : Icons.close_rounded,
                size: 17,
                color: correct ? t.correct : t.wrong,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${question.question}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your answer: $yourAnswer',
                    style: TextStyle(
                      color: correct ? t.muted : t.wrong,
                      fontSize: 13,
                    ),
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Answer: ${question.correctAnswer}',
                      style: TextStyle(
                        color: t.correct,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
