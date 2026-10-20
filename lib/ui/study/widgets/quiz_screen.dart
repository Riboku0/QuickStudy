import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

import '../../../domain/models/quiz_question.dart';
import '../../../domain/models/study_deck.dart';
import '../../../routing/app_navigator.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/quiz_view_model.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.deck});

  final StudyDeck deck;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final QuizViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = QuizViewModel(deck: widget.deck, stats: context.read());
  }
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    vm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(int option) {
    if (vm.isAnswered) return;

    final correct = vm.select(option);
    correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();

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
    vm.next();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TwoLineTitle(overline: s.quiz, title: widget.deck.title),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            if (vm.isEmpty) {
              return EmptyState(
                icon: AppIcons.quiz,
                title: s.noQuestionsTitle,
                message: s.noQuestionsBody,
                actionLabel: s.backToDecks,
                onAction: () => Navigator.of(context).pop(),
              );
            }

            return vm.finished ? _buildResults(s) : _buildQuestion(s);
          },
        ),
      ),
    );
  }

  // ------------------------- السؤال -------------------------

  Widget _buildQuestion(AppStrings s) {
    final question = vm.current;
    final direction = textDirectionFor(question.question);
    final rtl = direction == TextDirection.rtl;
    final chosen = vm.chosen;

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
                      s.questionOf(vm.index + 1, vm.total),
                      style: AppText.tracked(context, AppText.label).copyWith(
                        fontFeatures: AppText.tabular,
                      ),
                    ),
                    const Spacer(),
                    AppPill(
                      s.score(vm.score),
                      background: AppColors.yellow,
                      foreground: AppColors.onYellow,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressTrack(value: vm.progress),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                SoftCard(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    question.question,
                    textDirection: direction,
                    style: AppText.title.copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      label: _letter(i, rtl),
                      text: question.options[i],
                      state: vm.stateOf(i),
                      direction: direction,
                      onTap: vm.isAnswered ? null : () => _select(i),
                    ),
                  ),
                if (chosen != null) ...[
                  const SizedBox(height: 6),
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
                label: !vm.isAnswered
                    ? s.chooseAnswer
                    : (vm.isLast ? s.seeScore : s.nextQuestion),
                icon: !vm.isAnswered
                    ? null
                    : (vm.isLast ? AppIcons.award : AppIcons.next),
                iconAfter: true,
                onPressed: vm.isAnswered ? _next : null,
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

  // ------------------------- النتيجة -------------------------

  Widget _buildResults(AppStrings s) {
    final t = AppTokens.of(context);
    final ratio = vm.ratio;

    final (title, message) = ratio >= 0.8
        ? (s.greatWork, s.greatWorkBody)
        : ratio >= 0.5
            ? (s.goodEffort, s.goodEffortBody)
            : (s.keepPracticing, s.keepPracticingBody);

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
                  color: AppColors.hero,
                  borderRadius: BorderRadius.circular(t.radiusLarge),
                  boxShadow: t.heroShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                  child: Column(
                    children: [
                      _ScoreRing(score: vm.score, total: vm.total),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: AppText.title.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: s.retakeQuiz,
                icon: AppIcons.replay,
                kind: AppButtonKind.accent,
                onPressed: vm.restart,
              ),
              const SizedBox(height: 10),
              if (vm.hasFlashcards) ...[
                AppButton(
                  label: s.reviewFlashcards,
                  icon: AppIcons.cards,
                  onPressed: () =>
                      AppNavigator.switchToFlashcards(context, widget.deck),
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: s.backToDecks,
                kind: AppButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 30),
              SectionHeader(s.yourAnswers, trailing: '${vm.score}/${vm.total}'),
              const SizedBox(height: 14),
              for (var i = 0; i < vm.total; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewRow(
                    number: i + 1,
                    question: vm.questions[i],
                    chosen: vm.answers[i],
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
    final ratio = total == 0 ? 0.0 : score / total;

    return Semantics(
      label: AppStrings.of(context).scoreOutOf(score, total),
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
                color: AppColors.yellow,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        fontFeatures: AppText.tabular,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(value * 100).round()}%',
                      style: AppText.caption.copyWith(
                        color: AppColors.yellow,
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
  final OptionState state;
  final TextDirection direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    // ألوان بدل Opacity (أخف في الرسم)
    final (background, border, badge, badgeText, textColor) = switch (state) {
      OptionState.idle => (
          AppColors.surface,
          AppColors.line,
          AppColors.yellowSoft,
          AppColors.ink,
          AppColors.ink,
        ),
      OptionState.correct => (
          AppColors.greenSoft,
          AppColors.green,
          AppColors.green,
          Colors.white,
          AppColors.ink,
        ),
      OptionState.wrong => (
          AppColors.redSoft,
          AppColors.red,
          AppColors.red,
          Colors.white,
          AppColors.ink,
        ),
      OptionState.faded => (
          AppColors.surface.withValues(alpha: 0.6),
          Colors.transparent,
          AppColors.chip,
          AppColors.muted,
          AppColors.muted,
        ),
    };

    final AppIconData? icon = switch (state) {
      OptionState.correct => AppIcons.check,
      OptionState.wrong => AppIcons.close,
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
                          ? AppIcon(icon, size: 18, color: badgeText, strokeWidth: 2.2)
                          : Text(
                              label,
                              style: TextStyle(
                                color: badgeText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        text,
                        style: AppText.body.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
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
    final s = AppStrings.of(context);
    final correct = question.isCorrect(chosen);
    final explanation = question.explanation;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: correct ? AppColors.greenSoft : AppColors.redSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                correct ? AppIcons.correct : AppIcons.wrong,
                size: 20,
                color: correct ? AppColors.green : AppColors.red,
              ),
              const SizedBox(width: 8),
              Text(correct ? s.correct : s.notQuite, style: AppText.headline),
            ],
          ),
          if (!correct) ...[
            const SizedBox(height: 10),
            Text(
              s.theAnswerIs(question.correctAnswer),
              textDirection: direction,
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (explanation != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Text(
                explanation,
                textDirection: direction,
                style: AppText.body,
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
    final s = AppStrings.of(context);
    final picked = chosen;
    final correct = picked != null && question.isCorrect(picked);
    final yourAnswer = picked == null ? s.noAnswer : question.options[picked];

    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Directionality(
        textDirection: textDirectionFor(question.question),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon: correct ? AppIcons.check : AppIcons.close,
              tint: correct ? Tint.green : Tint.pdf,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${question.question}',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.yourAnswer(yourAnswer),
                    style: AppText.caption.copyWith(
                      color: correct ? AppColors.muted : AppColors.red,
                    ),
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.answerIs(question.correctAnswer),
                      style: AppText.caption.copyWith(
                        color: AppColors.greenDeep,
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
