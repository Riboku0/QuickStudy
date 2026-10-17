import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// الوصول المباشر إلى SQLite فقط (بدون منطق).
// نفس اسم قاعدة البيانات والجدول السابقين، فالملفات المحفوظة تبقى كما هي.
class DatabaseService {
  static const String _fileName = 'quickstudy.db';

  Database? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;

    final path = join(await getDatabasesPath(), _fileName);

    final db = await openDatabase(
      path,
      // النسخة 2: المواد والشباتر (Study)
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE lectures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            filePath TEXT NOT NULL,
            fileType TEXT NOT NULL,
            dateAdded TEXT NOT NULL
          )
        ''');
        await _createStudyTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createStudyTables(db);
      },
    );

    _database = db;
    return db;
  }

  // كل ملف PDF في مادة واحدة فقط (lectureId UNIQUE)
  static Future<void> _createStudyTables(Database db) async {
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subjectId INTEGER NOT NULL,
        lectureId INTEGER NOT NULL UNIQUE,
        title TEXT,
        sortOrder INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<List<Map<String, Object?>>> getLectures() async {
    final db = await _open();
    return db.query('lectures', orderBy: 'id DESC');
  }

  Future<int> insertLecture({
    required String name,
    required String filePath,
    required String fileType,
    required DateTime dateAdded,
  }) async {
    final db = await _open();

    return db.insert('lectures', {
      'name': name,
      'filePath': filePath,
      'fileType': fileType,
      'dateAdded': dateAdded.toIso8601String(),
    });
  }

  // حذف الملف يحذف شابتره أيضًا
  Future<void> deleteLecture(int id) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('chapters', where: 'lectureId = ?', whereArgs: [id]);
      await txn.delete('lectures', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------------------------------------------------------------------
  // المواد والشباتر
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getSubjects() async {
    final db = await _open();
    return db.query('subjects', orderBy: 'id ASC');
  }

  Future<List<Map<String, Object?>>> getChapters() async {
    final db = await _open();
    return db.query('chapters', orderBy: 'subjectId ASC, sortOrder ASC, id ASC');
  }

  Future<int> insertSubject({required String name, required int color}) async {
    final db = await _open();
    return db.insert('subjects', {
      'name': name,
      'color': color,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateSubject(
    int id, {
    required String name,
    required int color,
  }) async {
    final db = await _open();
    await db.update(
      'subjects',
      {'name': name, 'color': color},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // يحذف المادة وشباترها فقط، والملفات تبقى في المكتبة
  Future<void> deleteSubject(int id) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('chapters', where: 'subjectId = ?', whereArgs: [id]);
      await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> insertChapters(
    int subjectId,
    List<int> lectureIds,
    int firstOrder,
  ) async {
    final db = await _open();
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final (i, lectureId) in lectureIds.indexed) {
        await txn.insert(
          'chapters',
          {
            'subjectId': subjectId,
            'lectureId': lectureId,
            'sortOrder': firstOrder + i,
            'createdAt': now,
          },
          // ملف موجود في مادة أخرى لا يُضاف مرتين
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> renameChapter(int id, String? title) async {
    final db = await _open();
    await db.update(
      'chapters',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteChapter(int id) async {
    final db = await _open();
    await db.delete('chapters', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderChapters(List<int> orderedIds) async {
    final db = await _open();
    await db.transaction((txn) async {
      for (final (i, id) in orderedIds.indexed) {
        await txn.update(
          'chapters',
          {'sortOrder': i},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
