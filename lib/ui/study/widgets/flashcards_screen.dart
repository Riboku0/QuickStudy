import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../domain/models/flashcard.dart';
import '../../../domain/models/study_deck.dart';
import '../../../routing/app_navigator.dart';
import '../../core/ui/core_ui.dart';
import '../view_models/flashcards_view_model.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, required this.deck});

  final StudyDeck deck;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late final FlashcardsViewModel vm = FlashcardsViewModel(deck: widget.deck);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    vm.next();
  }

  void _previous() {
    if (vm.isFirst) return;
    HapticFeedback.selectionClick();
    vm.previous();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TwoLineTitle(overline: s.flashcards, title: widget.deck.title),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            if (vm.isEmpty) {
              return EmptyState(
                icon: AppIcons.cards,
                title: s.noCardsTitle,
                message: s.noCardsBody,
                actionLabel: s.backToDecks,
                onAction: () => Navigator.of(context).pop(),
              );
            }

            if (vm.finished) {
              return _FinishedView(
                total: vm.total,
                onRestart: vm.restart,
                onQuiz: vm.hasQuiz
                    ? () => AppNavigator.switchToQuiz(context, widget.deck)
                    : null,
                onBack: () => Navigator.of(context).pop(),
              );
            }

            return _buildSession(s);
          },
        ),
      ),
    );
  }

  Widget _buildSession(AppStrings s) {
    final behind = math.min(vm.total - 1 - vm.index, 2);

    return ConstrainedContent(
      maxWidth: 560,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  s.cardOf(vm.index + 1, vm.total),
                  style: AppText.tracked(context, AppText.label)
                      .copyWith(fontFeatures: AppText.tabular),
                ),
                const Spacer(),
                Text(
                  vm.isLast ? s.lastCard : s.cardsLeft(vm.total - 1 - vm.index),
                  style: AppText.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressTrack(value: vm.progress),
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
                      for (var k = behind; k >= 1; k--)
                        Positioned(
                          left: 14.0 * k,
                          right: 14.0 * k,
                          top: 10.0 * k,
                          bottom: -10.0 * k,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                AppColors.surface,
                                AppColors.chip,
                                k / 2,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: AppTokens.of(context).shadow,
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
                            key: ValueKey(vm.index),
                            card: vm.current,
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
                CircleAction(
                  icon: AppIcons.previous,
                  tooltip: s.previousCard,
                  size: 52,
                  onPressed: vm.isFirst ? null : _previous,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: vm.isLast ? s.finishDeck : s.nextCard,
                    icon: vm.isLast ? AppIcons.check : AppIcons.next,
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
// بطاقة تنقلب: سؤال (أبيض) ← جواب (أسود)
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
    _controller.value >= 0.5 ? _controller.reverse() : _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final front = _Face(card: widget.card, back: false, onTap: _toggle);
    final back = _Face(card: widget.card, back: true, onTap: _toggle);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle =
            Curves.easeInOutCubic.transform(_controller.value) * math.pi;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: angle > math.pi / 2
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
    final s = AppStrings.of(context);
    final text = back ? card.answer : card.question;
    final foreground = back ? Colors.white : AppColors.ink;
    final hint = back ? Colors.white.withValues(alpha: 0.55) : AppColors.muted;

    return Semantics(
      button: true,
      label: '${back ? s.answer : s.question}: $text',
      hint: back ? s.doubleTapForQuestion : s.doubleTapForAnswer,
      excludeSemantics: true,
      onTap: onTap,
      child: SoftCard(
        onTap: onTap,
        color: back ? AppColors.hero : AppColors.surface,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          children: [
            Row(
              children: [
                AppPill(
                  back ? s.answer : s.question,
                  background: back ? AppColors.yellow : AppColors.yellowSoft,
                  foreground: back ? AppColors.onYellow : AppColors.yellowDeep,
                ),
                const Spacer(),
                AppIcon(
                  back ? AppIcons.idea : AppIcons.brain,
                  size: 22,
                  color: back ? AppColors.yellow : AppColors.muted,
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
                      fontWeight: back ? FontWeight.w500 : FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(back ? AppIcons.replay : AppIcons.tap, size: 16, color: hint),
                const SizedBox(width: 6),
                Text(
                  back ? s.tapForQuestion : s.tapForAnswer,
                  style: AppText.caption.copyWith(color: hint),
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
    required this.total,
    required this.onRestart,
    required this.onQuiz,
    required this.onBack,
  });

  final int total;
  final VoidCallback onRestart;
  final VoidCallback? onQuiz;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

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
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [AppColors.surface, AppColors.yellowTint],
                ),
                child: Column(
                  children: [
                    IconTile(
                      icon: AppIcons.trophy,
                      tint: Tint.accent,
                      size: 76,
                      glow: true,
                    ),
                    const SizedBox(height: 18),
                    Text(s.deckComplete, style: AppText.title),
                    const SizedBox(height: 8),
                    Text(
                      s.reviewedAll(total),
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (onQuiz != null) ...[
                AppButton(
                  label: s.testWithQuiz,
                  icon: AppIcons.quiz,
                  kind: AppButtonKind.accent,
                  onPressed: onQuiz,
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: s.studyAgain,
                icon: AppIcons.replay,
                onPressed: onRestart,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: s.backToDecks,
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
