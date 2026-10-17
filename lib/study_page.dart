import 'package:flutter/material.dart';

import 'flashcards_page.dart';
import 'models/study_deck.dart';
import 'quiz_page.dart';
import 'services/study_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({
    super.key,
    this.repository = const SampleStudyRepository(),
  });

  // مصدر البيانات (تجريبي الآن، SQLite لاحقًا)
  final StudyRepository repository;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  // عرض يكفي لعمودين (تابلت أو هاتف بالوضع الأفقي)
  static const double _twoColumnWidth = 720;

  late Future<List<StudyDeck>> _decks;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _decks = widget.repository.loadDecks();
  }

  void _reload() {
    setState(() => _decks = widget.repository.loadDecks());
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudyDeck>>(
      future: _decks,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _padForNavBar(
            context,
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Study materials did not load',
              message: '${snapshot.error}',
              actionLabel: 'Try again',
              onAction: _reload,
            ),
          );
        }

        final decks = snapshot.data ?? const <StudyDeck>[];

        if (decks.isEmpty) {
          return _padForNavBar(
            context,
            const EmptyState(
              icon: Icons.style_outlined,
              title: 'No decks yet',
              message:
                  'Upload a lecture from Home. Its flashcards and quiz will show up here.',
            ),
          );
        }

        final index = _selected.clamp(0, decks.length - 1).toInt();
        return _buildContent(context, decks, index);
      },
    );
  }

  // شريط التنقل العائم يغطي أسفل الصفحة (extendBody في main.dart)
  Widget _padForNavBar(BuildContext context, Widget child) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: child,
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<StudyDeck> decks,
    int index,
  ) {
    final t = AppTokens.of(context);
    final deck = decks[index];
    final insets = MediaQuery.paddingOf(context);

    final hero = _DeckHero(
      deck: deck,
      onFlashcards: deck.flashcards.isEmpty
          ? null
          : () => _open(FlashcardsPage(deck: deck)),
      onQuiz: deck.quiz.isEmpty ? null : () => _open(QuizPage(deck: deck)),
    );

    final deckList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Your decks', trailing: '${decks.length}'),
        const SizedBox(height: 12),
        for (var i = 0; i < decks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeckRow(
              deck: decks[i],
              selected: i == index,
              onTap: () => setState(() => _selected = i),
            ),
          ),
        if (deck.isSample) ...[
          const SizedBox(height: 8),
          const InfoNote(
            'These are sample decks for trying things out. '
            'Decks made from your lectures will replace them.',
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= _twoColumnWidth;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            insets.top + 20,
            20,
            insets.bottom + 24,
          ),
          children: [
            ConstrainedContent(
              maxWidth: twoColumns ? 1040 : 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTitle(
                    'Study',
                    trailing: deck.isSample
                        ? AppPill(
                            'Sample decks',
                            background: t.chip,
                            foreground: t.muted,
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (twoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: hero),
                        const SizedBox(width: 32),
                        Expanded(flex: 4, child: deckList),
                      ],
                    )
                  else ...[
                    hero,
                    const SizedBox(height: 32),
                    deckList,
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// البطاقة الرئيسية: حزمة بطاقات (العنصر المميز في الصفحة)
// ---------------------------------------------------------------------------

class _DeckHero extends StatelessWidget {
  const _DeckHero({
    required this.deck,
    required this.onFlashcards,
    required this.onQuiz,
  });

  final StudyDeck deck;
  final VoidCallback? onFlashcards;
  final VoidCallback? onQuiz;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = BorderRadius.circular(28);

    return Padding(
      // مساحة للبطاقتين الظاهرتين خلف البطاقة الأمامية
      padding: const EdgeInsets.only(top: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 28,
            right: 28,
            top: -16,
            bottom: 16,
            child: Transform.rotate(
              angle: -0.02,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: radius,
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: -8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: radius,
                boxShadow: t.shadow,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.ink,
              borderRadius: radius,
              boxShadow: AppTokens.heroShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              // تغيير المجموعة: انتقال ناعم للمحتوى فقط
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                child: _HeroContent(
                  key: ValueKey(deck.id),
                  deck: deck,
                  onFlashcards: onFlashcards,
                  onQuiz: onQuiz,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    super.key,
    required this.deck,
    required this.onFlashcards,
    required this.onQuiz,
  });

  final StudyDeck deck;
  final VoidCallback? onFlashcards;
  final VoidCallback? onQuiz;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final preview =
        deck.flashcards.isEmpty ? null : deck.flashcards.first.question;
    final faded = t.surface.withValues(alpha: 0.65);

    return Directionality(
      textDirection: textDirectionFor(deck.title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppPill(
                deck.subject,
                background: t.surface.withValues(alpha: 0.1),
                foreground: t.accent,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            deck.title,
            style: AppText.largeTitle.copyWith(
              color: t.surface,
              fontSize: 26,
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: faded),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              _Count(value: deck.flashcards.length, label: 'cards'),
              const SizedBox(width: 32),
              _Count(value: deck.quiz.length, label: 'questions'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Flip cards',
                  icon: Icons.style_rounded,
                  kind: AppButtonKind.accent,
                  onPressed: onFlashcards,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Take quiz',
                  icon: Icons.quiz_outlined,
                  kind: AppButtonKind.secondary,
                  onPressed: onQuiz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: AppText.largeTitle.copyWith(
            color: t.surface,
            fontSize: 26,
            fontFeatures: AppText.tabular,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppText.caption.copyWith(
            color: t.surface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// صف مجموعة في القائمة
// ---------------------------------------------------------------------------

class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.deck,
    required this.selected,
    required this.onTap,
  });

  final StudyDeck deck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final subject = SubjectStyle.of(deck.subject);
    final cards = deck.flashcards.length;
    final questions = deck.quiz.length;

    return Semantics(
      selected: selected,
      child: SoftCard(
        onTap: onTap,
        radius: t.radiusMedium,
        padding: const EdgeInsets.all(14),
        border: BorderSide(
          color: selected ? t.ink : Colors.transparent,
          width: 2,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: subject.background,
                borderRadius: BorderRadius.circular(t.radiusSmall),
              ),
              child: Icon(
                Icons.layers_rounded,
                color: subject.foreground,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      deck.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: textDirectionFor(deck.title),
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$cards cards, $questions questions',
                    style: AppText.caption.copyWith(
                      color: t.muted,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? t.ink : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? t.ink : t.ink.withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 14, color: t.accent)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
