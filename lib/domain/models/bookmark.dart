// علامة مرجعية داخل كتاب: صفحة كاملة، أو نص حدده المستخدم
enum BookmarkKind { page, text }

class Bookmark {
  const Bookmark({
    required this.id,
    required this.lectureId,
    required this.page,
    required this.kind,
    required this.createdAt,
    this.text,
    this.color,
  });

  final String id;
  final int lectureId;
  final int page; // يبدأ من 1
  final BookmarkKind kind;
  final DateTime createdAt;
  final String? text; // النص المحدد (للعلامات النصية)
  final int? color; // لون التحديد إن وُجد

  Map<String, Object?> toMap() => {
        'id': id,
        'lectureId': lectureId,
        'page': page,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'color': color,
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
      kind: raw['kind'] == BookmarkKind.text.name
          ? BookmarkKind.text
          : BookmarkKind.page,
      createdAt:
          DateTime.tryParse('${raw['createdAt'] ?? ''}') ?? DateTime(2000),
      text: raw['text'] as String?,
      color: raw['color'] as int?,
    );
  }
}
