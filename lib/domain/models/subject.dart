// مادة دراسية: اسم وأيقونة وصورة غلاف اختيارية، وشباترها خاصة بها
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.icon,
    this.coverPath,
  });

  final int id;
  final String name;
  final String? icon; // مفتاح في SubjectIcons
  final String? coverPath; // صورة الغلاف داخل مجلد التطبيق

  factory Subject.fromMap(Map<String, Object?> map) {
    return Subject(
      id: map['id'] as int,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      coverPath: map['coverPath'] as String?,
    );
  }
}

// ما يدخله المستخدم عند إنشاء مادة أو تعديلها.
// cover: مسار صورة مختارة من الهاتف، أو مسار الغلاف الحالي، أو null بلا غلاف.
class SubjectDraft {
  const SubjectDraft({required this.name, this.icon, this.cover});

  final String name;
  final String? icon;
  final String? cover;
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
