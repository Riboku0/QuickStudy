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
    await _add(
      Bookmark(
        id: _newId(),
        lectureId: lectureId,
        page: page,
        kind: BookmarkKind.page,
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<void> addText(int lectureId, int page, String text, {int? color}) {
    return _add(
      Bookmark(
        id: _newId(),
        lectureId: lectureId,
        page: page,
        kind: BookmarkKind.text,
        createdAt: DateTime.now(),
        text: text,
        color: color,
      ),
    );
  }

  // ---- علامات المذكرات: كل مذكرة علامة واحدة على الأكثر ----

  Bookmark? noteBookmark(int lectureId, String noteId) {
    for (final b in _items) {
      if (b.lectureId == lectureId &&
          b.kind == BookmarkKind.note &&
          b.noteId == noteId) {
        return b;
      }
    }
    return null;
  }

  // إضافة أو تعديل الاسم (بلا تكرار). الاسم الفارغ = بلا اسم
  Future<void> saveNote({
    required int lectureId,
    required String noteId,
    required int page,
    required String preview,
    String? title,
  }) async {
    final clean = title?.trim();
    final named = clean == null || clean.isEmpty ? null : clean;
    final existing = noteBookmark(lectureId, noteId);
    if (existing != null) {
      _replace(
        existing.copyWith(
          page: page,
          text: preview,
          title: named,
          clearTitle: named == null,
        ),
      );
      await _save();
      return;
    }
    await _add(
      Bookmark(
        id: _newId(),
        lectureId: lectureId,
        page: page,
        kind: BookmarkKind.note,
        createdAt: DateTime.now(),
        noteId: noteId,
        text: preview,
        title: named,
      ),
    );
  }

  // بعد تعديل المذكرة: المعاينة والصفحة تتبعانها (الاسم لا يتغير)
  Future<void> syncNote({
    required int lectureId,
    required String noteId,
    required int page,
    required String preview,
  }) async {
    final existing = noteBookmark(lectureId, noteId);
    if (existing == null ||
        (existing.text == preview && existing.page == page)) {
      return;
    }
    _replace(existing.copyWith(page: page, text: preview));
    await _save();
  }

  // إزالة العلامة فقط؛ المذكرة نفسها تبقى
  Future<void> removeNote(int lectureId, String noteId) async {
    final existing = noteBookmark(lectureId, noteId);
    if (existing != null) await remove(existing.id);
  }

  void _replace(Bookmark updated) {
    _items = List.unmodifiable([
      for (final b in _items) b.id == updated.id ? updated : b,
    ]);
    notifyListeners();
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

  // الوقت وحده قد يتكرر لعلامتين في نفس الميكروثانية (فيحذف إزالة إحداهما
  // الأخرى)، فيُضاف عداد
  static int _seq = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
}
