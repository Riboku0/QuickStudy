import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/domain/models/reader_settings.dart';
import 'package:project/ui/viewer/widgets/reader_settings_sheet.dart';

void main() {
  test('Obsidian is a normal paper color', () {
    const settings = ReaderSettings(background: ReaderBackground.dark);
    expect(settings.paperColor, const Color(0xFF0B0F14));
    expect(settings.darkPaper, isTrue);
    expect(settings.chrome.night, isNull);
  });

  test('old dark paper choices migrate to Obsidian', () {
    for (final name in ['black', 'charcoal', 'dark']) {
      expect(
        ReaderSettings.fromMap({'background': name}).background,
        ReaderBackground.dark,
      );
    }
  });

  test('removed night and text settings are ignored', () {
    final settings = ReaderSettings.fromMap({
      'nightMode': true,
      'nightBackground': 'mocha',
      'textFontSize': 90,
      'background': 'green',
    });
    expect(settings.background, ReaderBackground.green);
    expect(settings.paperColor, ReaderBackground.green.color);
    expect(settings.toMap(), isNot(contains('nightMode')));
    expect(settings.toMap(), isNot(contains('nightBackground')));
    expect(settings.toMap(), isNot(contains('textFontSize')));
  });
}
