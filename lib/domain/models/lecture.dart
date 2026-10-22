// مكان الملف: المكتبة (قراءة حرة) أو المذاكرة (شابتر في مادة). لا يختلطان.
enum LectureOrigin { library, study }

// ملف محاضرة محفوظ في التطبيق (صف من جدول lectures + معلومات الملف)
class Lecture {
  const Lecture({
    required this.id,
    required this.name,
    required this.filePath,
    required this.fileType,
    this.dateAdded,
    this.size = 0,
    this.exists = true,
    this.origin = LectureOrigin.library,
    this.category,
  });

  final int id;
  final String name;
  final String filePath;
  final String fileType; // pdf / epub / png / jpg / jpeg
  final DateTime? dateAdded;
  final int size; // بالبايت
  final bool exists; // هل الملف ما زال موجودًا في مجلد التطبيق؟
  final LectureOrigin origin;

  final String? category; // تصنيف كتاب المكتبة (مفتاح في BookCategory)

  bool get isStudy => origin == LectureOrigin.study;

  String get type => fileType.toLowerCase();
  bool get isPdf => type == 'pdf';
  bool get isEpub => type == 'epub';
  // كتاب يُقرأ في المكتبة أو المذاكرة (PDF أو EPUB)
  bool get isBook => isPdf || isEpub;
  bool get isImage => const ['png', 'jpg', 'jpeg'].contains(type);

  // الاسم بدون الامتداد ("Chapter 1.pdf" ← "Chapter 1")
  String get title {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  factory Lecture.fromMap(Map<String, Object?> map) {
    return Lecture(
      id: map['id'] as int,
      name: map['name'] as String,
      filePath: map['filePath'] as String,
      fileType: map['fileType'] as String,
      dateAdded: DateTime.tryParse('${map['dateAdded'] ?? ''}'),
      origin: map['origin'] == 'study'
          ? LectureOrigin.study
          : LectureOrigin.library,
      category: map['category'] as String?,
    );
  }

  // تغيير التصنيف (يقبل null لإزالته)
  Lecture withCategory(String? value) => Lecture(
    id: id,
    name: name,
    filePath: filePath,
    fileType: fileType,
    dateAdded: dateAdded,
    size: size,
    exists: exists,
    origin: origin,
    category: value,
  );

  Lecture copyWith({int? size, bool? exists}) {
    return Lecture(
      id: id,
      name: name,
      filePath: filePath,
      fileType: fileType,
      dateAdded: dateAdded,
      size: size ?? this.size,
      exists: exists ?? this.exists,
      origin: origin,
      category: category,
    );
  }
}

// نتيجة رفع مجموعة ملفات
class ImportSummary {
  const ImportSummary({required this.added, required this.skipped});

  static const ImportSummary none = ImportSummary(added: 0, skipped: 0);

  final int added;
  final int skipped; // مكرر أو غير مدعوم

  bool get cancelled => added == 0 && skipped == 0;
}
