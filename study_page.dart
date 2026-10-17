import 'package:flutter/material.dart';

import 'flashcards_page.dart';
import 'models/study_deck.dart';
import 'quiz_page.dart';
import 'services/study_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/brutal_widgets.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final insets = MediaQuery.paddingOf(context);

    return FutureBuilder<List<StudyDeck>>(
      future: _decks,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: t.ink));
        }

        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load study materials',
              message: '${snapshot.error}',
              actionLabel: 'Try again',
              onAction: _reload,
            ),
          );
        }

        final decks = snapshot.data ?? const <StudyDeck>[];

        if (decks.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: const EmptyState(
              icon: Icons.style_outlined,
              title: 'Nothing to study yet',
              message:
                  'Import a lecture from Home. Its flashcards and quizzes will appear here.',
            ),
          );
        }

        final index = _selected.clamp(0, decks.length - 1).toInt();
        final deck = decks[index];
        final cards = deck.flashcards.length;
        final questions = deck.quiz.length;

        return ListView(
          // insets.bottom يشمل شريط التنقل العائم (extendBody في main.dart)
          padding: EdgeInsets.fromLTRB(
            20,
            insets.top + 16,
            20,
            insets.bottom + 24,
          ),
          children: [
            _Header(isSample: deck.isSample),
            const SizedBox(height: 28),

            // اختيار المجموعة
            SectionLabel('Decks', trailing: '${decks.length}'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < decks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _DeckChip(
                        deck: decks[i],
                        selected: i == index,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DeckSummary(deck: deck),
            const SizedBox(height: 28),

            // أوضاع المذاكرة
            const SectionLabel('Modes'),
            const SizedBox(height: 12),
            _ModeTile(
              color: t.accent,
              foreground: t.ink,
              icon: Icons.style_rounded,
              title: 'Flashcards',
              description: 'Tap a card to reveal the answer.',
              countLabel: cards == 0
                  ? 'No cards yet'
                  : '$cards ${cards == 1 ? 'card' : 'cards'}',
              onTap: cards == 0 ? null : () => _open(FlashcardsPage(deck: deck)),
            ),
            const SizedBox(height: 14),
            _ModeTile(
              color: t.info,
              foreground: t.surface,
              icon: Icons.quiz_rounded,
              title: 'Quiz',
              description: 'Answer multiple-choice questions and get a score.',
              countLabel: questions == 0
                  ? 'No questions yet'
                  : '$questions ${questions == 1 ? 'question' : 'questions'}',
              onTap: questions == 0 ? null : () => _open(QuizPage(deck: deck)),
            ),

            if (deck.isSample) ...[
              const SizedBox(height: 24),
              const _SampleNotice(),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.isSample});

  final bool isSample;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BrutalTag('Study mode', color: t.accent),
            const Spacer(),
            if (isSample) const BrutalTag('Sample data'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'STUDY',
          style: TextStyle(
            color: t.ink,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick a deck, then flip through cards or test yourself with a quiz.',
          style: TextStyle(
            color: t.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DeckChip extends StatelessWidget {
  const _DeckChip({
    required this.deck,
    required this.selected,
    required this.onTap,
  });

  final StudyDeck deck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: BrutalBox(
        color: selected ? t.accent : t.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: onTap,
        semanticLabel: deck.title,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 16, color: t.ink),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                deck.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: textDirectionFor(deck.title),
                style: TextStyle(
                  color: t.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({required this.deck});

  final StudyDeck deck;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);
    final cards = deck.flashcards.length;
    final questions = deck.quiz.length;

    return BrutalBox(
      padding: const EdgeInsets.all(18),
      child: Directionality(
        textDirection: textDirectionFor(deck.title),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deck.subject.toUpperCase(),
              style: TextStyle(
                color: t.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              deck.title,
              style: TextStyle(
                color: t.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BrutalTag('$cards cards', color: t.accent),
                BrutalTag('$questions questions'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.description,
    required this.countLabel,
    required this.onTap,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String title;
  final String description;
  final String countLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: BrutalBox(
        color: color,
        onTap: onTap,
        semanticLabel: title,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.radius),
                border: Border.all(color: t.ink, width: t.borderWidth),
              ),
              child: Icon(icon, size: 28, color: t.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  BrutalTag(countLabel),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 26, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _SampleNotice extends StatelessWidget {
  const _SampleNotice();

  @override
  Widget build(BuildContext context) {
    final t = BrutalTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.muted, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: t.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is sample content for testing. Flashcards and quizzes '
              'generated from your lectures will replace it once AI is connected.',
              style: TextStyle(
                color: t.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
