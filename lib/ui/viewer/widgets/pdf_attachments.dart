import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// مرفقات الصفحات: مقاطع صوتية وصور يضعها المستخدم على صفحة.
// ملف لكل كتاب: quickstudy_notes/{id}_attachments.json، والملفات نفسها تُنسخ إلى
// quickstudy_notes/attachments/{id}/ فتبقى حتى لو حُذف الأصل من الهاتف.
// المكان نسبة من الصفحة، وعرض الصورة نسبة من عرض الصفحة.
enum AttachmentKind { audio, image }

class PageAttachment {
  PageAttachment({
    required this.id,
    required this.page,
    required this.kind,
    required this.file,
    required this.x,
    required this.y,
    this.w = 0.4,
    this.aspect = 0.75,
    this.durationMs,
    this.noteId,
  });

  final String id;
  int page; // يبدأ من 0 (للمرفق داخل مذكرة: صفحة المذكرة)
  final AttachmentKind kind;
  String file; // اسم الملف داخل مجلد مرفقات الكتاب
  double x; // الزاوية العلوية (نسبة من عرض الصفحة)
  double y; // نسبة من ارتفاع الصفحة
  double w; // عرض الصورة نسبة من عرض الصفحة (الصوت أيقونة ثابتة)
  double aspect; // ارتفاع الصورة ÷ عرضها
  int? durationMs; // مدة المقطع إن عُرفت
  // داخل مذكرة (NoteCard.id): يظهر في شريط المذكرة لا على الصفحة
  String? noteId;

  bool get isAudio => kind == AttachmentKind.audio;

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'kind': kind.name,
    'file': file,
    'x': x,
    'y': y,
    'w': w,
    'aspect': aspect,
    'durationMs': ?durationMs,
    'noteId': ?noteId,
  };

  factory PageAttachment.fromJson(Map<String, dynamic> json) => PageAttachment(
    id: json['id'] as String,
    page: json['page'] as int,
    kind: AttachmentKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => AttachmentKind.image,
    ),
    file: json['file'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num?)?.toDouble() ?? 0.4,
    aspect: (json['aspect'] as num?)?.toDouble() ?? 0.75,
    durationMs: (json['durationMs'] as num?)?.toInt(),
    noteId: json['noteId'] as String?,
  );
}

class PdfAttachments extends ChangeNotifier {
  PdfAttachments(this.lectureId);

  final int lectureId;
  final List<PageAttachment> _items = [];
  String? _dir;

  List<PageAttachment> get all => List.unmodifiable(_items);

  Future<Directory> _notesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quickstudy_notes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // مجلد ملفات هذا الكتاب
  Future<Directory> filesDir() async {
    final dir = Directory(
      p.join((await _notesDir()).path, 'attachments', '$lectureId'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir.path;
    return dir;
  }

  // المسار الكامل (بعد load أو filesDir)
  String? pathOf(PageAttachment a) =>
      _dir == null ? null : p.join(_dir!, a.file);

  Future<File> _file() async =>
      File(p.join((await _notesDir()).path, '${lectureId}_attachments.json'));

  Future<void> load() async {
    try {
      await filesDir();
      final file = await _file();
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        _items.addAll([
          for (final item in list)
            PageAttachment.fromJson(item as Map<String, dynamic>),
        ]);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load attachments: $e');
    }
  }

  Future<bool> save() async {
    try {
      final data = jsonEncode([for (final a in _items) a.toJson()]);
      await (await _file()).writeAsString(data, flush: true);
      return true;
    } catch (e) {
      debugPrint('Could not save attachments: $e');
      return false;
    }
  }

  // نسخ ملف من الهاتف إلى مجلد الكتاب. يرجع اسمه الجديد
  Future<String> importFile(String source) async {
    final dir = await filesDir();
    final ext = p.extension(source);
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(source).copy(p.join(dir.path, name));
    return name;
  }

  // مسار لتسجيل جديد داخل مجلد الكتاب
  Future<String> newRecordingPath() async {
    final dir = await filesDir();
    return p.join(dir.path, 'rec_${DateTime.now().microsecondsSinceEpoch}.m4a');
  }

  void add(PageAttachment a) {
    _items.add(a);
    notifyListeners();
  }

  void changed() => notifyListeners();

  // حذف المرفق وملفه
  Future<void> remove(PageAttachment a) async {
    _items.removeWhere((x) => x.id == a.id);
    notifyListeners();
    await _deleteFile(a.file);
    await save();
  }

  // استبدال ملف صورة بملف آخر (الملف القديم يُحذف)
  Future<void> replaceFile(
    PageAttachment a,
    String newName,
    double aspect,
  ) async {
    final old = a.file;
    a.file = newName;
    a.aspect = aspect;
    notifyListeners();
    await _deleteFile(old);
    await save();
  }

  Future<void> _deleteFile(String name) async {
    try {
      final dir = await filesDir();
      final f = File(p.join(dir.path, name));
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Could not delete attachment file: $e');
    }
  }
}
