// آخر موضع قراءة في ملف PDF
class ReadingProgress {
  const ReadingProgress({
    required this.lectureId,
    required this.page,
    required this.pageCount,
    required this.openedAt,
  });

  final int lectureId;
  final int page; // يبدأ من 1
  final int pageCount;
  final DateTime openedAt;

  // 0..1 (الصفحة الأولى = بداية القراءة)
  double get fraction => pageCount <= 1 ? 0 : (page - 1) / (pageCount - 1);

  int get percent => (fraction * 100).round();

  factory ReadingProgress.fromMap(int lectureId, Map<String, Object?> map) {
    return ReadingProgress(
      lectureId: lectureId,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 0,
      openedAt: DateTime.tryParse('${map['openedAt'] ?? ''}') ?? DateTime(2000),
    );
  }

  Map<String, Object?> toMap() => {
    'page': page,
    'pageCount': pageCount,
    'openedAt': openedAt.toIso8601String(),
  };
}
