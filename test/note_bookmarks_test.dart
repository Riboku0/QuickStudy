import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/repositories/bookmarks/bookmark_repository.dart';
import 'package:project/data/services/bookmark_service.dart';
import 'package:project/domain/models/bookmark.dart';

// خدمة في الذاكرة بدل الملف، وتحفظ آخر ما كُتب لاختبار البقاء بعد إعادة الفتح
class _MemoryService extends BookmarkService {
  List<Map<String, Object?>> saved = [];

  @override
  Future<List<Object?>> read() async => saved;

  @override
  Future<void> write(List<Map<String, Object?>> data) async => saved = data;
}

void main() {
  late _MemoryService service;
  late BookmarkRepository repo;

  setUp(() {
    service = _MemoryService();
    repo = BookmarkRepository(service: service);
  });

  test('one bookmark per note, saving again only renames it', () async {
    await repo.saveNote(
      lectureId: 1,
      noteId: 'n1',
      page: 4,
      preview: 'first line',
      title: 'Chapter idea',
    );
    await repo.saveNote(
      lectureId: 1,
      noteId: 'n1',
      page: 4,
      preview: 'first line',
      title: '  ',
    );
    final notes = repo.all.where((b) => b.kind == BookmarkKind.note).toList();
    expect(notes.length, 1);
    expect(notes.single.title, isNull); // الاسم الفارغ = بلا اسم
  });

  test('sync follows the note text and keeps the title', () async {
    await repo.saveNote(
      lectureId: 1,
      noteId: 'n1',
      page: 4,
      preview: 'old',
      title: 'Name',
    );
    await repo.syncNote(lectureId: 1, noteId: 'n1', page: 5, preview: 'new');
    final b = repo.noteBookmark(1, 'n1')!;
    expect(b.text, 'new');
    expect(b.page, 5);
    expect(b.title, 'Name');
  });

  test('removing the bookmark keeps page bookmarks and persists', () async {
    await repo.togglePage(1, 2);
    await repo.saveNote(lectureId: 1, noteId: 'n1', page: 4, preview: 'x');
    await repo.removeNote(1, 'n1');
    expect(repo.noteBookmark(1, 'n1'), isNull);
    expect(repo.pageBookmark(1, 2), isNotNull);

    // إعادة الفتح من المحفوظ
    await repo.saveNote(lectureId: 1, noteId: 'n2', page: 7, preview: 'y');
    final reopened = BookmarkRepository(service: service);
    await reopened.load();
    expect(reopened.noteBookmark(1, 'n2')?.page, 7);
    expect(reopened.pageBookmark(1, 2), isNotNull);
  });
}
