import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/domain/models/reader_settings.dart';
import 'package:project/ui/viewer/widgets/reader_settings_sheet.dart';

// ثيمات الليلي الأربعة: تُحفظ وتُقرأ، والقديمة تنتقل لأقرب ثيم، وحبر هو الافتراضي
void main() {
  test('night theme survives a save and reload', () {
    const settings = ReaderSettings(
      nightMode: true,
      nightBackground: NightBackground.oliveSmoke,
      background: ReaderBackground.green,
    );
    final back = ReaderSettings.fromMap(settings.toMap());
    expect(back.nightBackground, NightBackground.oliveSmoke);
    expect(back.background, ReaderBackground.green);
    expect(back.paperColor, const Color(0xFF20261F));
    expect(back.chrome.reader, const Color(0xFF141714));
    expect(back.chrome.surface, const Color(0xFF252D24));
  });

  test('settings without a night theme start on Ink', () {
    final old = ReaderSettings.fromMap({'nightMode': true});
    expect(old.nightBackground, NightBackground.ink);
    expect(old.paperColor, const Color(0xFF19212B));
    expect(old.inkColor, const Color(0xFFD4D9DF));
  });

  test('old night choices move to the closest new theme', () {
    NightBackground from(String name) =>
        ReaderSettings.fromMap({'nightBackground': name}).nightBackground;
    expect(from('night'), NightBackground.ink);
    expect(from('slate'), NightBackground.ink);
    expect(from('plum'), NightBackground.ink);
    expect(from('charcoal'), NightBackground.obsidian);
    expect(from('olive'), NightBackground.oliveSmoke);
    expect(from('mocha'), NightBackground.mocha);
  });

  test('day mode keeps the day background and the day sheet', () {
    const settings = ReaderSettings(
      background: ReaderBackground.classic,
      nightBackground: NightBackground.obsidian,
    );
    expect(settings.paperColor, ReaderBackground.classic.color);
    expect(settings.darkPaper, isFalse);
    expect(settings.chrome.night, isNull);
  });

  test('font size is saved and clamped', () {
    const settings = ReaderSettings(textFontSize: 26);
    expect(ReaderSettings.fromMap(settings.toMap()).textFontSize, 26);
    expect(ReaderSettings.fromMap({'textFontSize': 90}).textFontSize, 34);
    expect(ReaderSettings.fromMap({}).textFontSize, 18);
  });

  test('text, icons and buttons are readable in every night theme', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final b in NightBackground.values) {
      final c = ReaderSettings(nightMode: true, nightBackground: b).chrome;
      expect(contrast(b.color, b.ink), greaterThan(7), reason: b.name);
      expect(contrast(c.surface, c.ink), greaterThan(7), reason: b.name);
      expect(contrast(c.card, c.icon), greaterThan(4.5), reason: b.name);
      expect(contrast(c.strong, c.onStrong), greaterThan(4.5), reason: b.name);
    }
  });
}
