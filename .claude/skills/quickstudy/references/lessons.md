# Past bugs: symptom → real cause → fix

Check this table before debugging. Several symptoms look unrelated to their cause.

| Symptom | Real cause | Fix |
|---|---|---|
| `The getter 'platform' isn't defined for FilePicker` | file_picker 13 API | `FilePicker.pickFiles()` / `FilePicker.saveFile()` (static) |
| `IconData can't be extended outside of its library` | phosphor_flutter is outdated | use hugeicons |
| `Undefined name 'LucideIcons'` / `BrutalTheme` / `onOpenTab` | old files left in `lib/` | don't import or analyze old folders; analyze only the live ones |
| `Could not find the correct Provider<ThumbnailService>` | new service + hot reload | `ThumbnailService.instance` singleton; full restart |
| Red screen `_elements.contains(element)` | follow-on error from an earlier exception | ask for the first `EXCEPTION CAUGHT BY` block; `flutter clean` if stale |
| Storage bar invisible | `ColoredBox` with no child has zero height | `Container(height: 10, decoration: ...)` |
| `SegmentedButton` text drops at height 40 | height constraints | custom `_TypeTabs` with `Center` |
| `context.read` error inside a `late` field | it runs during `build` | create ViewModels in `initState` |
| PDF cover flashes then disappears; never shows after restart | `whenComplete(() => _inFlight.remove(k))` returns the future, so it waits on itself forever | block body `{ _inFlight.remove(k); }` |
| `LateInitializationError` after adding a VM field | hot reload keeps old VM instances | hot restart `R` or a new `flutter run` |
| Selection works in one book, not another | the second book is scanned (text layer only has "Tele: @Arab_Books") | OCR when < 25 words |
| `object is unsendable ... _Future` in `Isolate.run` | the closure was created inside a class and captured fields | top-level function that captures only bytes and the page index |
| App freezes when saving a note on a selection; shows `_dependents.isEmpty` | the first error was `TextEditingController used after being disposed`: it was disposed right after `showDialog` while the dialog was still animating out | a StatefulWidget dialog that owns and disposes the controller |
| White note text invisible at night | the paper filter covered the whole tile | filter the page image only; notes outside it |
| `cacheWidth` 0 on first frame | width 0 before layout | pass null when the width is 0 |
| Subject page shows only a centered "إضافة شابتر" although chapters exist | `ConstrainedContent` (with `Center`) in `bottomNavigationBar` expanded to full height | `Center(heightFactor: 1)` in bottom bars |
| Duplicate-definition compile error after adding a string | the name already existed (`comingSoon`, `notStarted`) | grep `app_strings.dart` before adding |
| Disk full during Gradle build | caches | with the user's OK: `flutter clean`, delete `~/.gradle/caches`, stop the Gradle daemon, delete `android/.gradle` |
| sed/perl edit inserted text at file top or broke strings | `\|\|` in the pattern with `\|` delimiter; `\\n` turned into a real newline | use the Edit tool for those lines |
| `crash_dump` lines in logcat | system process (pid 1365), not the app | ignore |
