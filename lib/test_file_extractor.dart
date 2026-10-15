
import 'dart:io';

import 'services/file_text_extractor.dart';

Future<void> main() async {
  print('=== QuickStudy File Extraction Test ===');

  final path = stdin.readLineSync()?.trim();

  if (path == null || path.isEmpty) {
    print('No file path provided.');
    return;
  }

  try {
    final text = await FileTextExtractor.extractText(path: path);

    if (text.isEmpty) {
      print('No text was extracted from this file.');
      return;
    }

    print('\n=== Extracted Text ===\n');
    print(text);
    print('\n=== Test Successful ===');
  } catch (e) {
    print('\n=== Test Failed ===');
    print(e);
  }
}
