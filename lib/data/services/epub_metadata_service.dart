import 'dart:io';

import 'package:archive/archive.dart';

class EpubBookReadingMetadata {
  const EpubBookReadingMetadata({this.language, this.direction});
  final String? language;
  final String? direction;
}

abstract final class EpubMetadataService {
  static Future<EpubBookReadingMetadata> read(String path) async {
    try {
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final container = archive.findFile('META-INF/container.xml');
      if (container == null) return const EpubBookReadingMetadata();
      final xml = String.fromCharCodes(container.content as List<int>);
      final root = RegExp(r'''full-path\s*=\s*["']([^"']+)["']''').firstMatch(xml)?.group(1);
      final opfFile = root == null ? null : archive.findFile(root);
      if (opfFile == null) return const EpubBookReadingMetadata();
      final opf = String.fromCharCodes(opfFile.content as List<int>);
      final language = RegExp(r'''<(?:dc:)?language\b[^>]*>\s*([^<\s]+)''', caseSensitive: false).firstMatch(opf)?.group(1)?.toLowerCase();
      final progression = RegExp(r'''page-progression-direction\s*=\s*["'](rtl|ltr)["']''', caseSensitive: false).firstMatch(opf)?.group(1)?.toLowerCase();
      final rtl = language != null && const {'ar', 'fa', 'he', 'ur', 'ps', 'sd', 'yi'}.contains(language.split('-').first);
      return EpubBookReadingMetadata(language: language, direction: progression ?? (rtl ? 'rtl' : 'ltr'));
    } catch (_) {
      return const EpubBookReadingMetadata();
    }
  }
}
