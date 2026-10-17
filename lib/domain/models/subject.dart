// مادة دراسية (مثل مجلد): لها اسم ولون، وشباترها خاصة بها
class Subject {
  const Subject({required this.id, required this.name, required this.color});

  final int id;
  final String name;
  final int color; // رقم اللون في SubjectColors

  // أول حرف للغلاف
  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first);
  }

  factory Subject.fromMap(Map<String, Object?> map) {
    return Subject(
      id: map['id'] as int,
      name: map['name'] as String,
      color: map['color'] as int,
    );
  }
}

// شابتر = ملف PDF من المكتبة داخل مادة واحدة
class Chapter {
  const Chapter({
    required this.id,
    required this.subjectId,
    required this.lectureId,
    this.title,
    required this.sortOrder,
  });

  final int id;
  final int subjectId;
  final int lectureId;
  final String? title; // اسم يختاره المستخدم، وإلا اسم الملف
  final int sortOrder;

  factory Chapter.fromMap(Map<String, Object?> map) {
    final title = map['title'] as String?;
    return Chapter(
      id: map['id'] as int,
      subjectId: map['subjectId'] as int,
      lectureId: map['lectureId'] as int,
      title: (title == null || title.trim().isEmpty) ? null : title,
      sortOrder: map['sortOrder'] as int,
    );
  }
}
