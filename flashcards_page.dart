import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'models/flashcard.dart';
import 'models/study_deck.dart';
import 'theme/app_theme.dart';
import 'widgets/brutal_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: brutalAppBar(
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
        title: 'No flashcards yet',
        message: 'This deck does not have any cards.',
        actionLabel: 'Back to Study',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    if (_finished) {
      return _FinishedView(
        total: _cards.length,
        onRestart: _restart,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    final t = BrutalTheme.of(context);
    final total = _cards.length;
    final last = _index == total - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'CARD ${_index + 1} / $total',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                'SWIPE ← →',
                style: TextStyle(
                  color: t.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BrutalProgressBar(value: (_index + 1) / total),
          const SizedBox(height: 20),

          // البطاقة: ضغطة = قلب، سحب أفقي = التالي/السابق
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previous,
                    if (current != null) current,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: _FlipCard(
                  key: ValueKey(_index),
                  card: _cards[_index],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: BrutalButton(
                  label: 'Previous',
                  icon: Icons.arrow_back_rounded,
                  variant: BrutalVariant.light,
                  onPressed: _index > 0 ? _previous : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BrutalButton(
                  label: last ? 'Finish' : 'Next',
                  icon: last ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة تنقلب (سؤال في الأمام، جواب في الخلف)
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
    duration: const Duration(milliseconds: 380),
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
                  // تعديل حتى لا يظهر النص الخلفي معكوسًا
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: _face(context, back: true),
                )
              : _face(context, back: false),
        );
      },
    );
  }

  Widget _face(BuildContext context, {required bool back}) {
    final t = BrutalTheme.of(context);
    final text = back ? widget.card.answer : widget.card.question;

    return BrutalBox(
      color: back ? t.accent : t.surface,
      padding: const EdgeInsets.all(20),
      onTap: _toggle,
      semanticLabel: back ? 'Answer: $text' : 'Question: $text',
      child: Column(
        children: [
          Row(
            children: [
              BrutalTag(
                back ? 'Answer' : 'Question',
                color: back ? t.surface : t.accent,
              ),
              const Spacer(),
              Icon(
                back ? Icons.lightbulb_rounded : Icons.help_outline_rounded,
                color: t.ink,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  textDirection: textDirectionFor(text),
                  style: TextStyle(
                    color: t.ink,
                    fontSize: back ? 20 : 22,
                    fontWeight: back ? FontWeight.w700 : FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          Text(
            back ? 'TAP TO FLIP BACK' : 'TAP TO REVEAL',
            style: TextStyle(
              color: back ? t.ink : t.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
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
    required this.onBack,
  });

  final int total;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalBox(
              color: t.accent,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.emoji_events_rounded, size: 48, color: t.ink),
                  const SizedBox(height: 12),
                  Text(
                    'DECK COMPLETE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You went through all $total cards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BrutalButton(
              label: 'Study again',
              icon: Icons.replay_rounded,
              onPressed: onRestart,
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: 'Back to Study',
              icon: Icons.arrow_back_rounded,
              variant: BrutalVariant.light,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
