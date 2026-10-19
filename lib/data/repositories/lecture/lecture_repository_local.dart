import '../../../domain/models/lecture.dart';
import '../../../utils/result.dart';
import '../../services/database_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/file_storage_service.dart';
import 'lecture_repository.dart';

// تخزين محلي: SQLite للمعلومات + مجلد التطبيق للملفات
class LocalLectureRepository extends LectureRepository {
  LocalLectureRepository({
    required DatabaseService database,
    required FileStorageService storage,
  })  : _database = database,
        _storage = storage;

  final DatabaseService _database;
  final FileStorageService _storage;

  List<Lecture> _lectures = const [];
  bool _loaded = false;

  @override
  List<Lecture> get lectures => _lectures;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<Result<void>> load() async {
    try {
      final rows = await _database.getLectures();

      final items = await Future.wait(
        rows.map((row) async {
          final lecture = Lecture.fromMap(row);

          if (!await _storage.exists(lecture.filePath)) {
            return lecture.copyWith(exists: false);
          }

          return lecture.copyWith(size: await _storage.sizeOf(lecture.filePath));
        }),
      );

      _lectures = List.unmodifiable(items);
      _loaded = true;
      notifyListeners();

      return const Result.ok(null);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  @override
  Future<Result<ImportSummary>> importFiles(
    List<SelectedFile> files, {
    LectureOrigin origin = LectureOrigin.library,
    List<int>? ids,
  }) async {
    var added = 0;
    var skipped = 0;

    try {
      for (final file in files) {
        final path = file.path;
        final ext = file.name.split('.').last.toLowerCase();

        if (path == null ||
            !FilePickerService.allowedExtensions.contains(ext) ||
            !await _storage.exists(path)) {
          skipped++;
          continue;
        }

        // نفس الاسم ونفس الحجم = ملف مكرر
        final size = await _storage.sizeOf(path);
        final duplicate = _lectures.any(
          (l) =>
              l.exists &&
              l.origin == origin &&
              l.name == file.name &&
              l.size == size,
        );

        if (duplicate) {
          skipped++;
          continue;
        }

        final savedPath = await _storage.copyIntoApp(path, file.name);

        try {
          final id = await _database.insertLecture(
            name: file.name,
            filePath: savedPath,
            fileType: ext,
            dateAdded: DateTime.now(),
            origin: origin.name,
          );
          ids?.add(id);
        } catch (_) {
          // لا نترك نسخة يتيمة إذا فشل الحفظ في قاعدة البيانات
          await _storage.deleteIfExists(savedPath);
          rethrow;
        }

        added++;
      }

      final reload = await load();
      if (reload is Err<void>) return Result.error(reload.error);

      return Result.ok(ImportSummary(added: added, skipped: skipped));
    } catch (e) {
      if (added > 0) await load();
      return Result.error(asException(e));
    }
  }

  @override
  Future<Result<void>> setCategory(Lecture lecture, String? category) async {
    try {
      await _database.updateLectureCategory(lecture.id, category);
      _lectures = List.unmodifiable([
        for (final l in _lectures)
          l.id == lecture.id ? l.withCategory(category) : l,
      ]);
      notifyListeners();
      return const Result.ok(null);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  @override
  Future<Result<void>> delete(Lecture lecture) async {
    try {
      await _database.deleteLecture(lecture.id);
      await _storage.deleteLectureData(
        lectureId: lecture.id,
        filePath: lecture.filePath,
      );

      _lectures = List.unmodifiable(
        _lectures.where((l) => l.id != lecture.id),
      );
      notifyListeners();

      return const Result.ok(null);
    } catch (e) {
      return Result.error(asException(e));
    }
  }
}
