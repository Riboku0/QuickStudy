import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'models/flashcard.dart';
import 'models/study_deck.dart';
import 'quiz_page.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key, required this.deck});

  final StudyDeck deck;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  int _index = 0;
  bool _finished = false;

  List<Flashcard> get _cards => widget.deck.flashcards;

  void _next() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_index < _cards.length - 1) {
        _index++;
      } else {
        _finished = true;
      }
    });
  }

  void _previous() {
    if (_index == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _index--);
  }

  void _restart() {
    setState(() {
      _index = 0;
      _finished = false;
    });
  }

  void _openQuiz() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => QuizPage(deck: widget.deck)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: studyAppBar(
        context,
        subtitle: 'Flashcards',
        title: widget.deck.title,
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_cards.isEmpty) {
      return EmptyState(
        icon: Icons.style_outlined,
        title: 'No cards in this deck',
        message: 'Cards made from this lecture will appear here.',
        actionLabel: 'Back to decks',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    if (_finished) {
      return _FinishedView(
        deck: widget.deck,
        onRestart: _restart,
        onQuiz: widget.deck.quiz.isEmpty ? null : _openQuiz,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    final t = AppTokens.of(context);
    final total = _cards.length;
    final last = _index == total - 1;
    final behind = math.min(total - 1 - _index, 2);

    return ConstrainedContent(
      maxWidth: 560,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Card ${_index + 1} of $total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  last ? 'Last card' : '${total - 1 - _index} left',
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressTrack(value: (_index + 1) / total),
            const SizedBox(height: 24),

            // ضغطة = قلب البطاقة، سحب أفقي = التالي/السابق
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300) {
                    _next();
                  } else if (velocity > 300) {
                    _previous();
                  }
                },
                child: Padding(
                  padding: EdgeInsets.only(bottom: behind * 10.0),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      // البطاقات المتبقية تظهر أسفل البطاقة الحالية
                      for (var k = behind; k >= 1; k--)
                        Positioned(
                          left: 14.0 * k,
                          right: 14.0 * k,
                          top: 10.0 * k,
                          bottom: -10.0 * k,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                t.surface,
                                AppColors.chip,
                                k / 3,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: t.shadow,
                            ),
                          ),
                        ),
                      RepaintBoundary(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          layoutBuilder: (current, previous) => Stack(
                            fit: StackFit.expand,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.97, end: 1)
                                  .animate(animation),
                              child: child,
                            ),
                          ),
                          child: _FlipCard(
                            key: ValueKey(_index),
                            card: _cards[_index],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Previous card',
                  onPressed: _index > 0 ? _previous : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: last ? 'Finish deck' : 'Next card',
                    icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    iconAfter: true,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة تنقلب: سؤال (أبيض) ← جواب (داكن)
// ---------------------------------------------------------------------------

class _FlipCard extends StatefulWidget {
  const _FlipCard({super.key, required this.card});

  final Flashcard card;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  void _toggle() {
    HapticFeedback.selectionClick();

    if (_controller.value >= 0.5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الوجهان يُبنيان مرة واحدة، والحركة تغيّر التحويل فقط
    final front = _Face(card: widget.card, back: false, onTap: _toggle);
    final back = _Face(card: widget.card, back: true, onTap: _toggle);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle =
            Curves.easeInOutCubic.transform(_controller.value) * math.pi;
        final showBack = angle > math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  // حتى لا يظهر نص الجواب معكوسًا
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.card, required this.back, required this.onTap});

  final Flashcard card;
  final bool back;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = back ? card.answer : card.question;
    final foreground = back ? t.surface : t.ink;
    final hintColor = back ? t.surface.withValues(alpha: 0.55) : t.muted;

    return Semantics(
      button: true,
      label: back ? 'Answer: $text' : 'Question: $text',
      hint: back ? 'Double tap to see the question' : 'Double tap to reveal the answer',
      excludeSemantics: true,
      onTap: onTap,
      child: SoftCard(
        onTap: onTap,
           color: back ? t.primary : t.surface,
        radius: 28,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          children: [
            Row(
              children: [
                AppPill(
                  back ? 'Answer' : 'Question',
                  background: back ? t.accent : t.accentSoft,
                  foreground: t.ink,
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    textDirection: textDirectionFor(text),
                    style: TextStyle(
                      color: foreground,
                      fontSize: back ? 19 : 22,
                      fontWeight: back ? FontWeight.w500 : FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  back ? Icons.replay_rounded : Icons.touch_app_outlined,
                  size: 16,
                  color: hintColor,
                ),
                const SizedBox(width: 6),
                Text(
                  back ? 'Tap to see the question' : 'Tap to reveal the answer',
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// نهاية المجموعة
// ---------------------------------------------------------------------------

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    required this.deck,
    required this.onRestart,
    required this.onQuiz,
    required this.onBack,
  });

  final StudyDeck deck;
  final VoidCallback onRestart;
  final VoidCallback? onQuiz;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final total = deck.flashcards.length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoftCard(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded, size: 38, color: t.ink),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Deck complete',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You reviewed all $total cards.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (onQuiz != null) ...[
                AppButton(
                  label: 'Test yourself with the quiz',
                  icon: Icons.quiz_rounded,
                  kind: AppButtonKind.accent,
                  onPressed: onQuiz,
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: 'Study the cards again',
                icon: Icons.replay_rounded,
                onPressed: onRestart,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Back to decks',
                kind: AppButtonKind.secondary,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
