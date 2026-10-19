# QuickStudy architecture

## Contents
1. Folder layout
2. Data flow and rules
3. Database schema
4. Repositories and their APIs
5. Tabs and screens
6. Packages
7. Adding things (recipes)

## 1. Folder layout

```text
lib/
├── main.dart                     # MultiProvider + QuickStudyApp (theme + locale, rebuilds the tree on change)
├── config/dependencies.dart      # every service and repository, created once
├── routing/app_navigator.dart    # all push/pop: openDocument(page:), openSubject, openChapter,
│                                 #   openFlashcards, openQuiz, switchToQuiz/Flashcards, openSettings
├── utils/result.dart             # Result<T> = Ok | Err, asException()
├── utils/command.dart            # Command0 / Command1
├── domain/models/                # Lecture (+LectureOrigin), ImportSummary, Subject, Chapter, Flashcard,
│                                 #   QuizQuestion, StudyDeck, ReadingProgress, ReaderSettings, Bookmark
├── data/services/                # direct system access, no logic
│   ├── database_service.dart     # SQLite quickstudy.db
│   ├── file_storage_service.dart # copy/delete files + per-lecture notes/marks
│   ├── file_picker_service.dart  # pickLectureFiles(extensions:), pdfOnly
│   ├── settings_service.dart     # quickstudy_settings.json
│   ├── reading_progress_service.dart  # quickstudy_progress.json
│   ├── reader_settings_service.dart   # quickstudy_reader.json
│   ├── bookmark_service.dart          # quickstudy_bookmarks.json
│   ├── ocr_service.dart          # OcrService.instance.pageWords(...) cached in quickstudy_ocr/{id}/{page}.json
│   ├── thumbnail_service.dart    # ThumbnailService.instance (first-page covers)
│   └── file_text_extractor.dart
├── data/repositories/
│   ├── lecture/       # LectureRepository (abstract) + LocalLectureRepository  — single source of files
│   ├── subjects/      # SubjectRepository — subjects + chapters, listens to LectureRepository
│   ├── progress/      # ReadingProgressRepository: record / progressFor / recent (800 ms debounce)
│   ├── reader/        # ReaderSettingsRepository: update / reset
│   ├── bookmarks/     # BookmarkRepository: togglePage / addText / remove / removeForLecture
│   ├── settings/      # SettingsRepository: AppThemeChoice + AppLanguageChoice
│   └── study/         # StudyRepository + SampleStudyRepository (sample decks until AI)
└── ui/
    ├── core/themes/app_theme.dart   # AppPalette, AppColors, AppText, AppTokens, Tint, AppTheme
    ├── core/themes/app_icons.dart   # AppIcons
    ├── core/l10n/app_strings.dart   # AppStrings → _En / _Ar
    ├── core/ui/core_ui.dart         # exports all shared widgets (import this one file)
    ├── shell/                       # app_shell.dart (IndexedStack, 3 tabs) + floating_nav_bar.dart
    ├── dashboard/                   # tab 0 "الرئيسية": numbers dashboard (DashboardScreen + DashboardViewModel)
    ├── study/                       # tab 1 "المذاكرة": study_screen, subject_screen, chapter_screen,
    │                                #   subject_widgets (SubjectColors, SubjectCover, SubjectDialog,
    │                                #   TextInputDialog, showActionSheet, confirmDeleteSubject),
    │                                #   flashcards_screen, quiz_screen + view_models
    ├── home/                        # tab 2 "المكتبة": PDF reading shelves (HomeScreen)
    ├── settings/
    ├── viewer/widgets/              # document_viewer_screen.dart (~3500 lines, not MVVM yet),
    │                                #   reader_settings_sheet, text_marks, reader_chrome
    └── editor/                      # unused
```

The file names under `home/` and `library/` don't match the tab names. The tabs were swapped later and the files were not renamed.

Old leftover folders such as `lib/theme`, `lib/home`, `lib/*_page.dart` and root-level `main.dart`/`widgets/` are dead code with errors. Don't import them, and don't run analyze over them.

## 2. Data flow and rules

- Service ← Repository ← ViewModel ← View (`ListenableBuilder(listenable: Listenable.merge([vm, vm.someCommand]))`).
- Each screen is a View plus a ViewModel. No logic lives in widgets, and no widgets live in ViewModels.
- ViewModels return data or enums, never display strings. The view translates them, for example `DayPart`, `DateBucket` and the chapter status.
- The three tab ViewModels are created in `AppShell.initState`. Pushed screens (Subject, Chapter, Flashcards, Quiz, Settings) create their own ViewModel in `initState` with `context.read()` and dispose it.
- Command result handling:
  - Add a listener in `initState`.
  - In the listener, read `cmd.result`, return if null, call `cmd.clearResult()`, then switch on `Ok` / `Err` and call `showAppMessage(...)`.
- To swap a data source, write a new Repository and change one line in `dependencies.dart`.

## 3. Database schema (sqflite, `quickstudy.db`, version 5; v5 adds `lectures.category TEXT NULL`)

```sql
lectures(id INTEGER PK AUTOINCREMENT, name TEXT, filePath TEXT, fileType TEXT,
         dateAdded TEXT, origin TEXT NOT NULL DEFAULT 'library')   -- 'library' | 'study'
subjects(id INTEGER PK AUTOINCREMENT, name TEXT, color INTEGER /*unused, 0*/,
         icon TEXT NULL /*AppIcons.subjects key*/, coverPath TEXT NULL, createdAt TEXT)
chapters(id INTEGER PK AUTOINCREMENT, subjectId INTEGER, lectureId INTEGER UNIQUE,
         title TEXT NULL, sortOrder INTEGER, createdAt TEXT)
```

Migrations live in `DatabaseService._open`:
- `oldVersion < 2` creates the study tables.
- `oldVersion < 3` adds `origin` and marks lectures that are already in chapters as `study`.

To add a migration:
1. Bump `version`.
2. Add an `if (oldVersion < N)` block.
3. Also update `onCreate`.

Deletes cascade by hand:
- `deleteLecture` deletes its chapter row in a transaction.
- `deleteSubject` deletes its chapters.

## 4. Repositories

**LectureRepository** (ChangeNotifier) is the only source of files.
- `lectures`: all files, newest first, both origins.
- `importFiles(files, {origin = library, ids})`:
  - Duplicates (same name and size) are checked only inside the same origin.
  - `ids` is filled with the new row ids.
- `delete(lecture)`: removes the row, the file copy, its notes and its marks.
- `Lecture.isStudy` and `isPdf` are the usual filters.
  - Library screens show `!isStudy` only.
  - Study shows only its own chapters.

**SubjectRepository**
- Lookups: `subjects`, `subject(id)`, `chapter(id)`, `chaptersOf(subjectId)` (ordered), `chapterCount`, `assignedLectureIds`.
- Subjects: `createSubject` (returns the id), `updateSubject`, `deleteSubject`. Deleting a subject also deletes its chapter files through LectureRepository.
- Chapters: `addChapters`, `renameChapter`, `removeChapter` (deletes the file), `reorder` (optimistic, then persisted).
- When the lecture count drops, it reloads.

**ReadingProgressRepository**: `progressFor(lectureId)` returns `ReadingProgress(page, pageCount, fraction, percent)`.

## 5. Tabs and screens

Tab order: 0 الرئيسية (`DashboardScreen`), 1 المذاكرة (`StudyScreen`), 2 المكتبة (`HomeScreen`).

- **الرئيسية**: a view-only numbers dashboard (19 Oct).
  - Greeting with the name, then ⋮.
  - Purple card: reading time today, this week, day streak, and 7-day bars.
  - Library stats: books, finished, reading now, bookmarks.
  - Study stats: subjects, chapters done X / Y, completion %.
  - All-time stats: reading time, pages reached, sessions, streak.
  - Reading time comes from `ReadingStatsRepository` (`quickstudy_stats.json`). `AppNavigator.openDocument` records it with a Stopwatch; sessions under 5 s are ignored.
  - The old file manager, image upload and the `ui/library` folder were removed. The app is PDF-only now.
- **المذاكرة**:
  - A grid of subjects: a colored block with the big first letter, the name, and the chapter count.
  - "+" opens `SubjectDialog` (name plus 8 `SubjectColors`). Long-press opens edit/delete.
  - Each subject is independent. One PDF is one chapter, uploaded from inside the subject with origin study, and it never appears in the library.
- **SubjectScreen**:
  - Cover and name.
  - A `ReorderableListView` with the header, `onReorderItem` and drag handles.
  - Chapter rows all have the same height: a one-line title and a status line ("not started" / "page X of Y" / green ✓ "finished").
  - ⋮ opens rename/delete (with confirmation; delete removes the file).
  - "إضافة شابتر" is a soft-yellow button in `bottomNavigationBar` wrapped in `Center(heightFactor: 1)`.
- **ChapterScreen**: a hero card to read, with progress; chat (soon); flashcards and quiz from the first sample deck, labeled "sample", until phase 4.
- **المكتبة (HomeScreen)** (redesigned 19 Oct in the purple Study theme):
  - Header: greeting, title, search and the ⋮ account menu.
  - "Recently read" carousel (up to 4 books).
  - Category tabs: novel / study / philosophy / works, stored in `lectures.category`.
  - Book grid with a ⋯ sheet per book: category, that book's bookmarks, delete.
  - The paper background, shelves and Amiri title are gone from this tab.
- **Account menu** (`ui/shell/profile_menu.dart`): ⋮ on every tab. Avatar, user name (`SettingsRepository.userName`), theme, language, and all settings.
- **Shared purple theme:** `StudyTone` (`ui/core/themes/study_tone.dart`) plus `StudyScaffold` / `StudyCard` / `StudyButton` (`ui/core/ui/study_surfaces.dart`).
- **Flashcards / Quiz / Settings**: see design-system.md.

## 6. Packages

| Package | Notes |
|---|---|
| provider | DI; `context.read` outside build |
| hugeicons ^1.2.0 | `AppIconData = List<List<dynamic>>`, shown with `AppIcon` |
| sqflite, path, path_provider | DB + files |
| file_picker ^13 | static `FilePicker.pickFiles()` / `saveFile()` |
| syncfusion_flutter_pdf + printing | text extraction; `Printing.raster(bytes, pages: [i], dpi:)` |
| flutter_tesseract_ocr | `ara+eng` |
| share_plus ^13 | `SharePlus.instance.share(ShareParams(...))` |
| google_fonts | Almarai (UI, since 19 Oct), note fonts |
| http ^1.6.0 | online book search and download (`OnlineBooksService`). The INTERNET permission is in `AndroidManifest.xml` |
| flutter_localizations | Arabic + RTL |
| url_launcher ^6.3.3 | `launchUrl(uri, mode: LaunchMode.externalApplication)`, no `canLaunchUrl` |

Also installed: `phosphoricons_flutter ^1.1.1`, used for the Duotone subject icons only through `PhosphorIcon(PhosphorIconsDuotone.x, ...)`. It is a different package from the broken `phosphor_flutter`.

Don't use: phosphor_flutter (broken), lucide_icons.
Unused and removable: docx_to_text, archive, xml, google_mlkit_text_recognition, csv, image, file_selector.

## 7. Recipes

**New screen**
1. Write `ui/<area>/view_models/x_view_model.dart` with Commands.
2. Write `ui/<area>/widgets/x_screen.dart`, a StatefulWidget that creates the VM in `initState`.
3. Add a route in `AppNavigator`.
4. Add the strings in all three places.

**New persisted data**
1. Write the service, then a repository extending ChangeNotifier.
2. Add the provider in `dependencies.dart`.
3. Remind the user to do a full restart.

**New table or column**: follow the migration steps in section 3, and update the model's `fromMap`.

## Roadmap (from CLAUDE.md)

- Stage C: per-chapter chat UI. Bubbles and an input field, messages saved per chapter. The AI reply comes later.
- Phase 2: cleanup.
  - Remove unused packages.
  - Bundle Readex Pro.
  - Optionally split the viewer into MVVM.
  - `ThumbnailService.evict` on delete.
- Phase 3: `ExtractionRepository`, which caches extracted text per lecture.
- Phase 4: AI through a proxy server. Ask the user about the provider and budget first.
  - `ai_service.dart` returns JSON matching `Flashcard.fromMap` / `QuizQuestion.fromMap`.
  - Long lectures are split into chunks.
- Phase 5: `decks`/`flashcards`/`quiz_questions` tables and `SqliteStudyRepository`, then remove the sample data.
- Phase 6: release.
  - Large and corrupt file tests.
  - Icon and name.
  - `flutter build apk --release`.
  - README.

## Online books (Library search, 19 Oct)

`OnlineBooksService` (`data/services/online_books_service.dart`) searches two sources:
- **Internet Archive:** `advancedsearch.php` with `mediatype:texts`, `format:PDF` and `NOT access-restricted-item:true`.
- **Open Library:** `search.json`, keeping only `ebook_access == public` and using its `ia` identifier.

Downloads:
- They fetch `archive.org/metadata/{id}/files`, prefer the "Text PDF" file, and stream it to a temp file with progress.
- The file is checked for the `%PDF-` header, then `importFiles` adds it to the library.
- "Download from a link" accepts any direct PDF URL.

Not integrated:
- Hindawi (now safahat.org) and Noor-Book are behind Cloudflare bot protection.
- Noor-Book also hosts mostly unlicensed copies.

Do not try to scrape or bypass either of them.

Added on 19 Oct:
- **Suggestions while typing:** `suggest()` combines Wikipedia opensearch (ar or en, picked from the text) with Open Library titles. It runs after a 350 ms debounce in `HomeViewModel`.
- **"Did you mean":** `didYouMean()` uses Wikipedia `srinfo=suggestion`.
- **Kind tabs:** `OnlineKind.books` / `comics`. Comics searches the archive by manga/manhwa/comics subjects.
- **Wikimedia Commons:** a source for books only, using `directUrl`. `OnlineBook.id` is the archive id, or `commons:<file>` for Commons.
- **Clean-content filter (always on):**
  - Archive queries exclude adult subjects with `NOT subject:(...)`.
  - The `_blocked` regex checks the title, author and subject. English matches whole words; Arabic matches whole words only, using lookarounds.
- **Search page:** search is a full page, `SearchScreen` (`ui/home/widgets/search_screen.dart`), pushed from the Library header. The Android back button closes it like any route; `PopScope` inside the tab did not work on the device. It has three tabs: online books, manga & manhwa, and my books. Results show as a grid of large covers with a floating download button. On dispose it clears the query with `Future.microtask`, because notifying listeners during dispose is not allowed.
- **Not added:** MangaDex and other scanlation sites, Google Books (needs a key, so it waits for the proxy), Library of Congress and Gutendex (blocked or down).
