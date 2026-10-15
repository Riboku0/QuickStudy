
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter_pdf_text/flutter_pdf_text.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:xml/xml.dart';

class FileTextExtractor {
  /// Extract text from a supported file.
  ///
  /// Supported formats:
  /// PDF, DOCX, PPTX, TXT, and common image formats.
  static Future<String> extractText({
    required String path,
  }) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('File not found.');
    }

    final extension = path.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return _readPdf(file);

      case 'docx':
        return _readDocx(file);

      case 'pptx':
        return _readPowerPoint(file);

      case 'txt':
        return _readTxt(file);

      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'bmp':
      case 'webp':
        return _readImage(file);

      default:
        throw UnsupportedError(
          'This file format is not supported: .$extension',
        );
    }
  }

  /// Read selectable text from a PDF file.
  static Future<String> _readPdf(File file) async {
    final pdf = await PDFDoc.fromFile(file);
    return (await pdf.text).trim();
  }

  /// Read text from a Word DOCX file.
  static Future<String> _readDocx(File file) async {
    final bytes = await file.readAsBytes();
    return docxToText(bytes).trim();
  }

  /// Read text from PowerPoint PPTX slides.
  static Future<String> _readPowerPoint(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final slideFiles = archive.where((entry) {
      if (!entry.isFile) return false;

      final name = entry.name;
      return RegExp(
        r'^ppt/slides/slide\d+\.xml$',
      ).hasMatch(name);
    }).toList();

    // Keep slides in their correct numerical order.
    slideFiles.sort((a, b) {
      final aNumber = int.parse(
        RegExp(r'slide(\d+)\.xml$')
            .firstMatch(a.name)!
            .group(1)!,
      );

      final bNumber = int.parse(
        RegExp(r'slide(\d+)\.xml$')
            .firstMatch(b.name)!
            .group(1)!,
      );

      return aNumber.compareTo(bNumber);
    });

    final result = <String>[];

    for (final slide in slideFiles) {
      final xmlText = utf8.decode(slide.content);
      final document = XmlDocument.parse(xmlText);

      final textNodes = document
          .findAllElements('a:t')
          .map((node) => node.innerText)
          .toList();

      if (textNodes.isNotEmpty) {
        result.add(textNodes.join(' '));
      }
    }

    return result.join('\n\n').trim();
  }

  /// Read a plain text file.
  static Future<String> _readTxt(File file) async {
    return (await file.readAsString(
      encoding: utf8,
    )).trim();
  }

  /// Extract text from an image using OCR.
  static Future<String> _readImage(File file) async {
    final inputImage = InputImage.fromFilePath(file.path);

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final result = await recognizer.processImage(inputImage);
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
