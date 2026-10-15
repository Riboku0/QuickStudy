
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _database;

  // فتح قاعدة البيانات أو إنشاؤها
  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = join(
      await getDatabasesPath(),
      'quickstudy.db',
    );

    _database = await openDatabase(
      dbPath,
      version: 1,
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
      },
    );

    return _database!;
  }

  // حفظ بيانات محاضرة
  static Future<int> insertLecture({
    required String name,
    required String filePath,
    required String fileType,
    required String dateAdded,
  }) async {
    final db = await database;

    return await db.insert(
      'lectures',
      {
        'name': name,
        'filePath': filePath,
        'fileType': fileType,
        'dateAdded': dateAdded,
      },
    );
  }

  // استرجاع جميع المحاضرات
  static Future<List<Map<String, dynamic>>>
      getLectures() async {
    final db = await database;

    return await db.query(
      'lectures',
      orderBy: 'id DESC',
    );
  }

  // حذف بيانات محاضرة باستخدام رقمها
  static Future<int> deleteLecture(int id) async {
    final db = await database;

    return await db.delete(
      'lectures',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
