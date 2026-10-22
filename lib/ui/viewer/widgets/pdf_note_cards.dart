import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pdf_ink.dart';

// المذكرات: بطاقة على الصفحة بلون الثيم، يُكتب فيها أو يُرسم بأدوات لوحة القلم،
// وتُطوى إلى أيقونة صغيرة على الصفحة. ملف لكل كتاب: quickstudy_notes/{id}_cards.json.
// المكان نسبة من الصفحة، والحجم نسبة من عرضها، ونقاط الرسم نسبة من البطاقة.
class NoteCard {
  NoteCard({
    required this.id,
    required this.page,
    required this.x,
    required this.y,
    this.w = 0.6,
    this.h = 0.45,
    this.text = '',
    this.color,
    List<InkStroke>? strokes,
  }) : strokes = strokes ?? [];

  final String id;
  final int page; // يبدأ من 0
  double x; // مكان الأيقونة والزاوية العلوية للبطاقة (نسبة من عرض الصفحة)
  double y; // نسبة من ارتفاع الصفحة
  double w; // عرض البطاقة نسبة من عرض الصفحة
  double h; // ارتفاع البطاقة نسبة من عرض الصفحة (حتى تبقى مربعة تقريبًا)
  String text;
  int? color; // لون نص المذكرة (null = لون الحبر الافتراضي)
  final List<InkStroke> strokes; // نقاطها وسماكتها نسبة من البطاقة

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'text': text,
    'color': ?color,
    'strokes': [for (final s in strokes) s.toJson()],
  };

  factory NoteCard.fromJson(Map<String, dynamic> json) => NoteCard(
    id: json['id'] as String,
    page: json['page'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num?)?.toDouble() ?? 0.6,
    h: (json['h'] as num?)?.toDouble() ?? 0.45,
    text: (json['text'] as String?) ?? '',
    color: (json['color'] as num?)?.toInt(),
    strokes: [
      for (final s in (json['strokes'] as List? ?? const []))
        InkStroke.fromJson(s as Map<String, dynamic>),
    ],
  );
}

class PdfNoteCards extends ChangeNotifier {
  PdfNoteCards(this.lectureId);

  final int lectureId;
  final List<NoteCard> _cards = [];

  List<NoteCard> get all => List.unmodifiable(_cards);

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quickstudy_notes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '${lectureId}_cards.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      _cards.addAll([
        for (final item in list)
          NoteCard.fromJson(item as Map<String, dynamic>),
      ]);
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load cards: $e');
    }
  }

  Future<bool> save() async {
    try {
      final data = jsonEncode([for (final c in _cards) c.toJson()]);
      await (await _file()).writeAsString(data, flush: true);
      return true;
    } catch (e) {
      debugPrint('Could not save cards: $e');
      return false;
    }
  }

  void add(NoteCard card) {
    _cards.add(card);
    notifyListeners();
  }

  void remove(NoteCard card) {
    _cards.removeWhere((c) => c.id == card.id);
    notifyListeners();
  }

  void changed() => notifyListeners();
}
