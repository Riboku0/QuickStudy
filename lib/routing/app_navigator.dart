import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/progress/reading_progress_repository.dart';
import '../domain/models/lecture.dart';
import '../domain/models/study_deck.dart';
import '../ui/core/themes/app_theme.dart';
import '../ui/settings/widgets/settings_screen.dart';
import '../ui/study/widgets/flashcards_screen.dart';
import '../ui/study/widgets/quiz_screen.dart';
import '../ui/viewer/widgets/document_viewer_screen.dart';

// كل الانتقالات بين الشاشات في مكان واحد.
// تنقل بسيط (push/pop) لأن التطبيق لا يحتاج روابط عميقة أو نسخة ويب.
abstract final class AppNavigator {
  // page: فتح صفحة محددة (من علامة مرجعية) بدل آخر صفحة مقروءة
  static Future<void> openDocument(
    BuildContext context,
    Lecture lecture, {
    int? page,
  }) {
    // ملفات PDF تفتح على آخر صفحة مقروءة، وتسجّل تقدمها
    final progress = lecture.isPdf ? context.read<ReadingProgressRepository>() : null;

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        // العارض يبقى فاتحًا حتى في الوضع الداكن
        builder: (_) => Theme(
          data: AppTheme.lightOnly(),
          child: DocumentViewerPage(
            fileId: lecture.id,
            fileName: lecture.name,
            filePath: lecture.filePath,
            fileType: lecture.fileType,
            initialPage: page ?? progress?.progressFor(lecture.id)?.page,
            onPageChanged: progress == null
                ? null
                : (page, count) => progress.record(lecture.id, page, count),
          ),
        ),
      ),
    );
  }

  static Future<void> openFlashcards(BuildContext context, StudyDeck deck) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FlashcardsScreen(deck: deck)),
    );
  }

  static Future<void> openQuiz(BuildContext context, StudyDeck deck) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuizScreen(deck: deck)),
    );
  }

  // من نهاية البطاقات إلى الاختبار (بدون تكديس الشاشات)
  static Future<void> switchToQuiz(BuildContext context, StudyDeck deck) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => QuizScreen(deck: deck)),
    );
  }

  static Future<void> switchToFlashcards(BuildContext context, StudyDeck deck) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => FlashcardsScreen(deck: deck)),
    );
  }

  static Future<void> openSettings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }
}
