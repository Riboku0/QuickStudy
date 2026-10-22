import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/progress/reading_progress_repository.dart';
import '../data/repositories/stats/reading_stats_repository.dart';
import '../domain/models/lecture.dart';
import '../domain/models/study_deck.dart';
import '../ui/core/themes/app_theme.dart';
import '../ui/home/view_models/add_book_view_model.dart';
import '../ui/home/widgets/add_book_screen.dart';
import '../ui/settings/widgets/settings_screen.dart';
import '../ui/study/widgets/chapter_screen.dart';
import '../ui/study/widgets/flashcards_screen.dart';
import '../ui/study/widgets/quiz_screen.dart';
import '../ui/study/widgets/subject_screen.dart';
import '../ui/viewer/widgets/document_viewer_screen.dart';
import '../ui/viewer/widgets/epub_reader_screen.dart';
import '../ui/viewer/widgets/pdf_reader_screen.dart';

// كل الانتقالات بين الشاشات في مكان واحد.
// تنقل بسيط (push/pop) لأن التطبيق لا يحتاج روابط عميقة أو نسخة ويب.
abstract final class AppNavigator {
  // نموذج إضافة كتاب للمكتبة. category: التصنيف المفتوح حاليًا يُختار مسبقًا
  static Future<void> openAddBook(BuildContext context, {String? category}) {
    final viewModel = AddBookViewModel(
      lectures: context.read(),
      picker: context.read(),
      settings: context.read(),
      initialCategory: category,
    );
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddBookScreen(viewModel: viewModel),
      ),
    );
  }

  // page: فتح صفحة محددة (من علامة مرجعية) بدل آخر صفحة مقروءة
  // noteId: علامة مذكرة، فتُفتح المذكرة نفسها على صفحتها (PDF)
  static Future<void> openDocument(
    BuildContext context,
    Lecture lecture, {
    int? page,
    String? noteId,
  }) async {
    // كتب EPUB لها قارئ خاص: يحفظ مكانه بنفسه، والتقدم نسبة من 100
    if (lecture.isEpub) {
      final progress = context.read<ReadingProgressRepository>();
      final stats = context.read<ReadingStatsRepository>();
      final watch = Stopwatch()..start();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: AppTheme.lightOnly(),
            child: EpubReaderScreen(
              lectureId: lecture.id,
              title: lecture.title,
              filePath: lecture.filePath,
              onProgress: (f) =>
                  progress.record(lecture.id, 1 + (f * 99).round(), 100),
            ),
          ),
        ),
      );
      watch.stop();
      await stats.addSession(watch.elapsed);
      return;
    }

    // ملفات PDF تفتح على آخر صفحة مقروءة، وتسجّل تقدمها
    final progress = lecture.isPdf
        ? context.read<ReadingProgressRepository>()
        : null;
    // وقت القراءة: من فتح العارض حتى الرجوع منه (لأرقام الرئيسية)
    final stats = context.read<ReadingStatsRepository>();
    final watch = Stopwatch()..start();
    final navigator = Navigator.of(context);
    // الصفحات المختلفة التي مرّ بها في هذه الجلسة (لرقم "صفحة مقروءة" اليوم)
    final visited = <int>{};
    void record(int p, int count) {
      visited.add(p);
      progress?.record(lecture.id, p, count);
    }

    // PDF: العارض الجديد (pdfrx). من قائمته يمكن فتح العارض القديم
    // (القلم والتحديد) على نفس الصفحة حتى تُبنى هذه الميزات فيه.
    int? classicPage;
    if (lecture.isPdf) {
      final result = await navigator.push<OpenClassicViewer>(
        MaterialPageRoute(
          builder: (_) => Theme(
            data: AppTheme.lightOnly(),
            child: PdfReaderScreen(
              fileId: lecture.id,
              fileName: lecture.name,
              filePath: lecture.filePath,
              initialPage: page ?? progress?.progressFor(lecture.id)?.page,
              onPageChanged: record,
              openNoteId: noteId,
            ),
          ),
        ),
      );
      if (result == null) {
        watch.stop();
        await stats.addSession(watch.elapsed, pages: visited.length);
        return;
      }
      classicPage = result.page;
    }

    await navigator.push(
      MaterialPageRoute<void>(
        // العارض يبقى فاتحًا حتى في الوضع الداكن
        builder: (_) => Theme(
          data: AppTheme.lightOnly(),
          child: DocumentViewerPage(
            fileId: lecture.id,
            fileName: lecture.name,
            filePath: lecture.filePath,
            fileType: lecture.fileType,
            initialPage:
                classicPage ?? page ?? progress?.progressFor(lecture.id)?.page,
            onPageChanged: progress == null ? null : record,
          ),
        ),
      ),
    );
    watch.stop();
    await stats.addSession(watch.elapsed, pages: visited.length);
  }

  static Future<void> openSubject(BuildContext context, int subjectId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubjectScreen(subjectId: subjectId),
      ),
    );
  }

  static Future<void> openChapter(BuildContext context, int chapterId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterScreen(chapterId: chapterId),
      ),
    );
  }

  static Future<void> openFlashcards(BuildContext context, StudyDeck deck) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FlashcardsScreen(deck: deck)),
    );
  }

  static Future<void> openQuiz(BuildContext context, StudyDeck deck) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => QuizScreen(deck: deck)));
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
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
}
