import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum EpubAnnotationKind { highlight, underline, strike, wavy, note, bookmark }

class EpubAnnotation {
  const EpubAnnotation({
    required this.id,
    required this.lectureId,
    required this.kind,
    required this.cfi,
    required this.text,
    required this.color,
    required this.createdAt,
    this.note,
  });

  final String id;
  final int lectureId;
  final EpubAnnotationKind kind;
  final String cfi;
  final String text;
  final int color;
  final DateTime createdAt;
  final String? note;

  EpubAnnotation copyWith({EpubAnnotationKind? kind, int? color, String? note}) =>
      EpubAnnotation(
        id: id,
        lectureId: lectureId,
        kind: kind ?? this.kind,
        cfi: cfi,
        text: text,
        color: color ?? this.color,
        createdAt: createdAt,
        note: note ?? this.note,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'lectureId': lectureId,
    'kind': kind.name,
    'cfi': cfi,
    'text': text,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    if (note != null) 'note': note,
  };

  factory EpubAnnotation.fromMap(Map<String, Object?> map) => EpubAnnotation(
    id: map['id'] as String,
    lectureId: (map['lectureId'] as num).toInt(),
    kind: EpubAnnotationKind.values.firstWhere(
      (value) => value.name == map['kind'],
      orElse: () => EpubAnnotationKind.highlight,
    ),
    cfi: map['cfi'] as String,
    text: map['text'] as String? ?? '',
    color: (map['color'] as num?)?.toInt() ?? 0xFFFFD54F,
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    note: map['note'] as String?,
  );
}

class EpubAnnotationService {
  EpubAnnotationService._();
  static final instance = EpubAnnotationService._();
  static const _fileName = 'quickstudy_epub_annotations.json';
  List<EpubAnnotation>? _cache;

  Future<File> _file() async => File(
    p.join((await getApplicationDocumentsDirectory()).path, _fileName),
  );

  Future<List<EpubAnnotation>> _all() async {
    if (_cache case final value?) return value;
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is List) {
          return _cache = data
              .whereType<Map>()
              .map((e) => EpubAnnotation.fromMap(Map<String, Object?>.from(e)))
              .toList();
        }
      }
    } catch (_) {}
    return _cache = [];
  }

  Future<List<EpubAnnotation>> forLecture(int lectureId) async =>
      List.unmodifiable((await _all()).where((a) => a.lectureId == lectureId));

  Future<void> save(EpubAnnotation annotation) async {
    final all = await _all();
    final index = all.indexWhere((a) => a.id == annotation.id);
    if (index < 0) {
      all.add(annotation);
    } else {
      all[index] = annotation;
    }
    await _write();
  }

  Future<void> remove(String id) async {
    (await _all()).removeWhere((a) => a.id == id);
    await _write();
  }

  Future<void> _write() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode((await _all()).map((a) => a.toMap()).toList()),
      flush: true,
    );
  }
}
