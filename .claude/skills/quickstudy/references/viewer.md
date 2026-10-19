# The PDF viewer (`lib/ui/viewer/widgets/`)

`document_viewer_screen.dart` is about 3500 lines and is not MVVM yet. Read the area you need before editing, and keep changes local.

## Rendering and modes

- Pages are rendered as images with `Printing.raster`.
- **Vertical mode** uses custom scroll and zoom: `_zoom`, `_scrollX/Y`, `_extent`, `_pageRect(i)` and `_hitPage`.
- **Horizontal mode** uses a `PageView` with a normal swipe. The 3D flip was removed at the user's request.
  - The current page gets an `InteractiveViewer` (`_pagedZoom`).
  - Paging locks with two fingers, while zoomed, or while writing (`_pagerLocked`).
  - Zoom resets when the page changes.
  - `_pageRect` in horizontal mode is `MatrixUtils.transformRect(_pagedZoom.value, _pagedRect)`, so selection works while zoomed.
- `initialPage` / `onPageChanged` save the last page through `ReadingProgressRepository`.

## Reader settings (`ReaderSettingsSheet`, opened by `Icons.tune`)

- Brightness is a black overlay.
- Margins use `_hPad`.
- There are 6 paper colors (`ReaderBackground`): classic `#F8F1E4`, green `#E9F2E5`, blue `#E8F0F7`, light `#FBF7F4`, warm `#F9ECE2`, dark `#262B29`. Old saved names are mapped through `_oldBackgrounds`.
- Vertical/horizontal switch, night mode, and reset.
- The sheet and other reader UI use `ReaderChrome(dark:)`: light by day, navy at night (surface `#262B36`). The sheet has no barrier, so the page stays visible.
- **Page tint** (`_pageFilter`): a color matrix that maps white to the paper color and black to the ink color.
  - It is applied **to the page image only**, inside `_PageTile` (`pageFilter`/`paperColor`). Notes sit outside the filter.
  - On dark paper (`darkPaper`), dark note colors are shown as `#E6E0D4`.
- **Night mode** is unified: paper `#222733`, ink `#D5DAE2`. Paper colors are disabled at night, with the `colorsDayOnly` note.
- Font settings are postponed; they need a text mode.

## Pen (direct writing)

- Tapping the page creates an empty note there and opens the keyboard. `_NoteView` shows a borderless `TextField` with the same font and position. There is no dialog.
- Tapping outside the note or the check button ends editing. An empty note is deleted.
- To move a note while editing:
  - Drag it with a finger (`_DragToMove`: more than 10 px is a drag, less is a tap; `_noteDragging` stops page scrolling).
  - Or use the `Icons.open_with` handle.
- Handles are small: 14 px circles, a 14×36 pill, 30 px corner buttons, with 40–48 px touch areas.
- In vertical mode, if the note's text is smaller than 17 px, `_zoomToEditing` zooms to about 22 px and restores the old zoom when editing ends. Scrolling keeps the note above the keyboard.
- Frame sizes come from `_pageRect` and `_pw`/`_ph`, so the pen works in both modes.
- Notes are stored in `quickstudy_notes/{id}_notes.json`.

## Text selection (`text_marks.dart`)

- Long-press a word to get two handles and a menu.
  - The menu offers 4 styles (highlight, underline, strike, squiggle) × 5 colors, plus clear, copy, note and bookmark.
  - It also has **More** (`_showMoreSheet`): DeepL, ChatGPT, Google Translate and share, opened with `launchUrl`.
  - For More, the text is clipped to 1500 chars. RTL text goes to English, other text to Arabic.
- Tapping a saved mark selects it. Tapping a note dot (`_noteDotAt`, 24 px) edits that note.
- Words come from `PdfTextExtractor` (positions relative to the page). The extraction runs in `Isolate.run` through a **top-level** function, because a closure created inside a class captures fields and becomes unsendable.
- **OCR fallback**: when a page has fewer than 25 words (a scanned page, or only a watermark), `OcrService` runs.
  - Settings: ara+eng, psm 3, 220 dpi, one page at a time.
  - A "reading text" message appears after 0.6 s.
  - Results are cached per page.
  - `parseHocr` / `orderWords` are tested in `test/ocr_hocr_test.dart`.
- **Prefetch**: 0.7 s after scrolling stops (`_schedulePrefetch` from `_reportPage`), the current page and the next two are prepared (`PageTextCache.prefetch`).
- Marks are stored in `quickstudy_notes/{id}_marks.json`. They stay inside the app and are not included in "save copy". A selection stays within one page.
- Test books on the phone:
  - "الليالي البيضاء" is scanned and needs OCR.
  - "شرخ في الذاكرة" has a text layer.

## Other

- Bookmark button in the bar (`bookmark` / `bookmarkSaved`).
- The page number is a "go to page" button.
- Text-input dialogs use `_InputDialog`, which owns its controller.
- Save a copy and share it with `FilePicker.saveFile`, share_plus.
