---
name: quickstudy
description: Everything needed to work on QuickStudy, the Arabic-first Flutter study app (PDF library, reader with notes/highlights/OCR, Study subjects and chapters, flashcards and quizzes). Use this skill for ANY task in the QuickStudy project at C:\study\FlutterProjects\project\project, whether adding a feature, fixing a bug or red screen, changing a screen's design, touching the PDF viewer, the database, strings or translations, colors or dark mode, or running and testing the app on the phone. Use it even when the user only describes the problem in Arabic or mentions a screen name (المكتبة، المذاكرة، الرئيسية، العارض، القلم، الشابتر).
---

# QuickStudy

QuickStudy is a Flutter app for Android, tested on a moto g75 5G. Development happens on Windows.

Users upload lectures and books (PDF or images), read them in a custom viewer with notes and highlights, and study with flashcards and quizzes. The end goal is AI-generated summaries, cards and quizzes from the user's own files. That AI work goes through a proxy server later (phase 4).

The user writes in Arabic. Reply in Arabic, briefly and plainly. Keep code, identifiers and file names in English.

## How to work with this user

These rules came from real friction in past sessions. Each one has a reason.

1. **Never run git**, not even `git status` or `git diff`. The user asked for this explicitly. Don't use git to read history either.
2. **Ask before major work.** The user said "قبل ان تعمل اي شيء اسئلني".
   - For anything bigger than a small fix, explain what you plan to build and how it will look.
   - Ask the open questions with AskUserQuestion (2–4 options, put the recommended one first).
   - Then build.
   - When a message is ambiguous, ask instead of guessing.
3. **Make one major change at a time.** Don't rebuild things that work unless the user asks.
4. **Keep the existing design.** The original colors and the floating bottom bar change only on request.
5. **Run analyze after every edit.** The project's `lib/` contains old unused files that have errors, so analyze only the live folders:
   `flutter analyze lib/main.dart lib/config lib/data lib/domain lib/routing lib/ui lib/utils`
   - Fix every error.
   - Fix warnings your own edit introduced.
6. **Check package APIs in the installed version** (in `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<pkg>-<ver>`). Don't rely on memory. For example, file_picker 13 has static `FilePicker.pickFiles()` and no `FilePicker.platform`.
7. **For runtime errors, ask for the first `EXCEPTION CAUGHT BY` block**, not the red-screen text. The visible message is usually a follow-on error, like `_elements.contains(element)`.
8. **No secret API keys inside the app.**
9. **Remind the user when hot reload isn't enough.** After a new provider, a DB version bump, or a new field in an existing ViewModel, a full restart (`R`) or a fresh `flutter run` is needed.
10. **Track the status of every feature honestly**: "tested by the user", "added, not tested", or "planned". Nothing is done until the user has tried it on the phone.
11. **After each stage, update `CLAUDE.md`**:
    - section 6: status
    - section 7: plan
    - section 8: lessons, when there was a bug
    - section 10: changelog

When you finish, explain in Arabic what changed and give a short numbered list of what to try on the phone.

## Running and verifying on the phone

Install and keep a debug connection:

```bash
flutter run -d <deviceId> --print-dtd > "$TEMP/claude/qs/run.log" 2>&1   # run in background
```

- adb lives at `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`. `adb devices -l` shows the phone (model `moto_g75_5G`).
- After the run log shows "Flutter run key commands", connect the Dart MCP with the printed DTD URI.
  - `mcp__dart__dtd connect` gives you hot_reload, hot_restart, get_runtime_errors and widget_inspector.
- To see the screen yourself:
  - Take a screenshot with `adb exec-out screencap -p > file.png`, then Read the png.
  - Tap with `adb shell input tap x y`. The screenshot shows a scaled image, and the read result gives the multiplier back to device pixels.
  - If the phone is locked, stop and tell the user. Never try to unlock it.
- "Lost connection to device" in the log usually means the cable was unplugged. Ask the user to reconnect.
- The widget inspector tree is large. Save it to a file and grep it for widget names or `textPreview`.

There is no python on PATH, so edit files with Write/Edit or sed.

- With sed, a pattern containing `\|\|` and `|` delimiters inserts text at the top of the file.
- In perl, `\\n` in a replacement becomes a real newline.
- For lines containing `||`, `\n` or quotes, use the Edit tool.

## Architecture in one paragraph

The app uses MVVM, following the official Flutter architecture guide.

- Data flows one way: Service → Repository (ChangeNotifier) → ViewModel (ChangeNotifier) → View, through `ListenableBuilder`.
- Events go back as Commands (`Command0`/`Command1` with `running`/`result`/`clearResult`) returning `Result` (`Ok`/`Err`).
- All providers live in `lib/config/dependencies.dart`.
- Read providers with `context.read` only in `initState` or event handlers, never inside `build`.
- All navigation is in `lib/routing/app_navigator.dart`.

Full layout, models, database schema and repository APIs: **read `references/architecture.md`** before adding data, screens or routes.

## UI rules you will hit on almost every change

- **Strings.** Never hard-code visible text.
  - Add a getter to `AppStrings` (abstract), then to `_En` and `_Ar` in `lib/ui/core/l10n/app_strings.dart`. Use it as `final s = AppStrings.of(context);`.
  - Grep first: many names already exist (`notStarted`, `comingSoon`, `save`...), and a duplicate is a compile error.
  - Plurals use `_n`. The Arabic version handles 1, 2, 3–10 and 11+.
- **Direction.**
  - Use `EdgeInsetsDirectional`, `AlignmentDirectional` and `PositionedDirectional`.
  - Apply `textDirectionFor(text)` to user content.
  - Never use `letterSpacing` on text that may be Arabic.
  - New arrow icons go into `AppIcons.directional`.
- **Colors.**
  - `AppColors.x` are getters (they switch for dark mode), so they can't appear in `const` expressions or default parameters. The exceptions are `AppColors.yellow` and `onYellow`.
  - Use `AppColors.surface` and `line`, not `Colors.white` or hex values.
  - The viewer is always light (`AppTheme.lightOnly()`).
- **Icons.** Use hugeicons only, through `AppIcon` and `AppIcons`. The type is `List<List<dynamic>>`, not `IconData`.
  - Verify an icon name exists in `hugeicons-1.2.0` before adding it.
  - The user calls these icons "emojis". Real emoji characters are not used in the UI.
- **Copy.** Short, specific sentences. No marketing words, no emoji.
- **Layout.**
  - Touch targets are at least 44–48 px.
  - Every state has its own UI: loading, empty, and error with retry.
  - One yellow accent per screen.
- **Dialogs with text fields** must be StatefulWidgets that own and dispose their `TextEditingController`. Disposing a controller right after `showDialog` returns crashes the closing animation.

Full design tokens, per-screen descriptions, and the reader/viewer internals: **read `references/design-system.md`** for UI work and **`references/viewer.md`** for anything in the PDF viewer.

Before debugging something that "worked before" or looks strange: **read `references/lessons.md`**, a table of past bugs, their real causes and their fixes.
