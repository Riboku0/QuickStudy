// ملف محاضرة محفوظ في التطبيق (صف من جدول lectures)
class Lecture {
  const Lecture({
    required this.id,
    required this.name,
    required this.filePath,
    required this.fileType,
    this.dateAdded,
    this.size = 0,
    this.exists = true,
  });

  final int id;
  final String name;
  final String filePath;
  final String fileType; // pdf / png / jpg / jpeg
  final DateTime? dateAdded;
  final int size; // بالبايت
  final bool exists; // هل الملف ما زال موجودًا في مجلد التطبيق؟

  String get type => fileType.toLowerCase();
  bool get isPdf => type == 'pdf';
  bool get isImage => const ['png', 'jpg', 'jpeg'].contains(type);

  factory Lecture.fromMap(Map<String, dynamic> map) {
    return Lecture(
      id: map['id'] as int,
      name: map['name'] as String,
      filePath: map['filePath'] as String,
      fileType: map['fileType'] as String,
      dateAdded: DateTime.tryParse('${map['dateAdded'] ?? ''}'),
    );
  }

  Lecture copyWith({int? size, bool? exists}) {
    return Lecture(
      id: id,
      name: name,
      filePath: filePath,
      fileType: fileType,
      dateAdded: dateAdded,
      size: size ?? this.size,
      exists: exists ?? this.exists,
    );
  }
}
