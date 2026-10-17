import 'package:flutter/foundation.dart';

import '../../../domain/models/bookmark.dart';
import '../../services/bookmark_service.dart';

// المصدر الوحيد للعلامات المرجعية. العارض يضيف ويحذف، والمكتبة تعرض.
class BookmarkRepository extends ChangeNotifier {
  BookmarkRepository({required BookmarkService service}) : _service = service;

  final BookmarkService _service;

  List<Bookmark> _items = const [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  // الأحدث أولًا
  List<Bookmark> get all => _items;

  Future<void> load() async {
    final raw = await _service.read();
    _items = List.unmodifiable(
      raw.map(Bookmark.fromMap).whereType<Bookmark>().toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    _loaded = true;
    notifyListeners();
  }

  Bookmark? pageBookmark(int lectureId, int page) {
    for (final b in _items) {
      if (b.lectureId == lectureId &&
          b.page == page &&
          b.kind == BookmarkKind.page) {
        return b;
      }
    }
    return null;
  }

  // زر العلامة في العارض: يضيف علامة للصفحة أو يزيلها. يرجع true عند الإضافة.
  Future<bool> togglePage(int lectureId, int page) async {
    final existing = pageBookmark(lectureId, page);
    if (existing != null) {
      await remove(existing.id);
      return false;
    }
    await _add(Bookmark(
      id: _newId(),
      lectureId: lectureId,
      page: page,
      kind: BookmarkKind.page,
      createdAt: DateTime.now(),
    ));
    return true;
  }

  Future<void> addText(
    int lectureId,
    int page,
    String text, {
    int? color,
  }) {
    return _add(Bookmark(
      id: _newId(),
      lectureId: lectureId,
      page: page,
      kind: BookmarkKind.text,
      createdAt: DateTime.now(),
      text: text,
      color: color,
    ));
  }

  Future<void> remove(String id) async {
    _items = List.unmodifiable(_items.where((b) => b.id != id));
    notifyListeners();
    await _save();
  }

  // عند حذف الكتاب
  Future<void> removeForLecture(int lectureId) async {
    if (!_items.any((b) => b.lectureId == lectureId)) return;
    _items = List.unmodifiable(_items.where((b) => b.lectureId != lectureId));
    notifyListeners();
    await _save();
  }

  Future<void> _add(Bookmark bookmark) async {
    _items = List.unmodifiable([bookmark, ..._items]);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _service.write([for (final b in _items) b.toMap()]);
    } catch (e) {
      // فشل الحفظ لا يوقف القراءة؛ العلامة تبقى في هذه الجلسة
      debugPrint('[Bookmarks] save failed: $e');
    }
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
