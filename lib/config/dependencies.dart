import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/lecture/lecture_repository.dart';
import '../data/repositories/bookmarks/bookmark_repository.dart';
import '../data/repositories/lecture/lecture_repository_local.dart';
import '../data/repositories/progress/reading_progress_repository.dart';
import '../data/repositories/reader/reader_settings_repository.dart';
import '../data/repositories/settings/settings_repository.dart';
import '../data/repositories/stats/reading_stats_repository.dart';
import '../data/repositories/study/study_repository.dart';
import '../data/repositories/study/study_repository_sample.dart';
import '../data/repositories/subjects/subject_repository.dart';
import '../data/services/bookmark_service.dart';
import '../data/services/database_service.dart';
import '../data/services/file_picker_service.dart';
import '../data/services/file_storage_service.dart';
import '../data/services/reader_settings_service.dart';
import '../data/services/reading_progress_service.dart';
import '../data/services/reading_stats_service.dart';
import '../data/services/settings_service.dart';

// كل الخدمات والمستودعات تُنشأ هنا مرة واحدة وتُمرَّر للواجهة.
// لتبديل مصدر بيانات (مثلًا SQLite بدل التجريبي للمذاكرة) غيّر سطرًا واحدًا هنا.
List<SingleChildWidget> get appProviders => [
      Provider(create: (_) => DatabaseService()),
      Provider(create: (_) => FileStorageService()),
      Provider(create: (_) => FilePickerService()),
      Provider(create: (_) => SettingsService()),
      ChangeNotifierProvider<SettingsRepository>(
        create: (context) => SettingsRepository(service: context.read())..load(),
      ),
      ChangeNotifierProvider<LectureRepository>(
        create: (context) => LocalLectureRepository(
          database: context.read(),
          storage: context.read(),
        )..load(),
      ),
      Provider(create: (_) => ReadingProgressService()),
      ChangeNotifierProvider<ReadingProgressRepository>(
        create: (context) =>
            ReadingProgressRepository(service: context.read())..load(),
      ),
      Provider(create: (_) => ReaderSettingsService()),
      ChangeNotifierProvider<ReaderSettingsRepository>(
        create: (context) =>
            ReaderSettingsRepository(service: context.read())..load(),
      ),
      Provider(create: (_) => BookmarkService()),
      ChangeNotifierProvider<BookmarkRepository>(
        create: (context) => BookmarkRepository(service: context.read())..load(),
      ),
      ChangeNotifierProvider<SubjectRepository>(
        create: (context) => SubjectRepository(
          database: context.read(),
          lectures: context.read(),
          storage: context.read(),
        )..load(),
      ),
      Provider(create: (_) => ReadingStatsService()),
      ChangeNotifierProvider<ReadingStatsRepository>(
        create: (context) =>
            ReadingStatsRepository(service: context.read())..load(),
      ),
      Provider<StudyRepository>(create: (_) => const SampleStudyRepository()),
    ];
