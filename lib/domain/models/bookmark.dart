// علامة مرجعية داخل كتاب: صفحة كاملة، أو نص حدده المستخدم، أو مذكرة على صفحة
enum BookmarkKind { page, text, note }

class Bookmark {
  const Bookmark({
    required this.id,
    required this.lectureId,
    required this.page,
    required this.kind,
    required this.createdAt,
    this.text,
    this.color,
    this.noteId,
    this.title,
  });

  final String id;
  final int lectureId;
  final int page; // يبدأ من 1
  final BookmarkKind kind;
  final DateTime createdAt;
  // النص المحدد (للعلامات النصية)، أو بداية نص المذكرة (يتحدث عند طيها)
  final String? text;
  final int? color; // لون التحديد إن وُجد
  final String? noteId; // المذكرة الأصلية (NoteCard.id) لعلامات المذكرات
  final String? title; // اسم يختاره المستخدم للمذكرة (اختياري)

  Bookmark copyWith({
    int? page,
    String? text,
    String? title,
    bool clearTitle = false,
  }) => Bookmark(
    id: id,
    lectureId: lectureId,
    page: page ?? this.page,
    kind: kind,
    createdAt: createdAt,
    text: text ?? this.text,
    color: color,
    noteId: noteId,
    title: clearTitle ? null : (title ?? this.title),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'lectureId': lectureId,
    'page': page,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'text': text,
    'color': color,
    'noteId': ?noteId,
    'title': ?title,
  };

  static Bookmark? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final lectureId = raw['lectureId'];
    final page = raw['page'];
    if (id is! String || lectureId is! int || page is! int) return null;

    return Bookmark(
      id: id,
      lectureId: lectureId,
      page: page,
      kind: BookmarkKind.values.firstWhere(
        (k) => k.name == raw['kind'],
        orElse: () => BookmarkKind.page,
      ),
      createdAt:
          DateTime.tryParse('${raw['createdAt'] ?? ''}') ?? DateTime(2000),
      text: raw['text'] as String?,
      color: raw['color'] as int?,
      noteId: raw['noteId'] as String?,
      title: raw['title'] as String?,
    );
  }
}
