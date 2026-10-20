# QuickStudy: the new PDF reader

Last update: 20 October 2026. Status: **built and installed, not yet tested by you on the phone** unless marked otherwise.

The reader was rebuilt on **pdfrx** (Google's PDFium engine) instead of turning each page into an image. Every PDF now opens in the new reader. The classic reader is still available from **⋮ → Classic viewer** until everything is moved over.

---

## 1. Reading

| Feature | How it works |
|---|---|
| Sharp zoom | Pinch with two fingers. Text stays sharp at any zoom (the old reader blurred). The + / − buttons were removed. |
| Big books | Pages load progressively; a 1,400-page book opens in about a second. |
| Fast scroll | Drag the page-number handle on the right edge. |
| Go to page | Tap "15 / 456" in the top bar, type the number, press Go. Whole numbers only. |
| Last page | Each book reopens where you stopped. |
| Bookmarks | Bookmark icon in the top bar (saves the current page). |
| Settings | Brightness, margins, 6 paper colors, night mode. Panels take the paper's own color. |
| Back button | Closes whatever is open first (selection, note, pen mode), then leaves the book. |

## 2. Selecting and highlighting text

- **Long-press a word**, then drag the two handles.
- The menu: 4 styles (highlight, underline, strikethrough, wavy) × 5 colors, then **Copy, Note, Bookmark, More** (DeepL, ChatGPT, Google Translate, Share). Icons are hugeicons; colors follow the paper and your app theme.
- Tap a saved highlight to change or delete it. Tap its note dot to edit the note.
- **Scanned books** (e.g. الجريمة والعقاب، الليالي البيضاء): the page is read with OCR the first time ("جارٍ قراءة النص", a few seconds), then selection works the same. The next pages are read in the background, and results are saved, so it is usually instant. OCR text can contain mistakes.
- Old highlights from the classic reader appear here too.

## 3. The pen

Tap the **pen icon** (hugeicons) in the top bar. A panel opens under the bar:

| Tool | What it does |
|---|---|
| قلم Pen | Solid lines. |
| رصاص Pencil | Thinner, slightly see-through lines. |
| ممحاة Eraser | Touch a stroke to delete it. |
| مذكرة Note | Tap the page: a card in your theme color. Write or draw inside it with the panel tools. It folds into a hugeicons note icon; tap the icon to open it, drag it to move. |
| نص Text | Tap the page and type, like the classic reader. |

- **Line style:** 4 thicknesses. **Color:** 5 soft colors (the first is your theme color).
- **One finger** draws or writes, **two fingers** move and zoom.
- **Text editing:** drag the text to move it, the side bar to change width, the round button to rotate. The bottom toolbar has font, size, color, background, B/I/U, alignment, opacity, rotation, delete and done.
- Old text notes from the classic reader appear here, and new ones appear there.

## 4. Removed by your request

- Text view with adjustable font size (scanned books needed OCR on every page; too slow).
- Highlighter marker, undo/redo and the "done" button in the pen panel (to match your reference design). Undo can come back if you want it.

## 5. Where things are saved

All per book, in the app's folder `quickstudy_notes/` (deleted with the book):

| File | Content |
|---|---|
| `{id}_marks.json` | Highlights (shared with the classic reader) |
| `{id}_notes.json` | Text notes (shared with the classic reader) |
| `{id}_ink.json` | Pen and pencil drawings |
| `{id}_cards.json` | Note cards (text + drawings) |
| `quickstudy_ocr/{id}/` | OCR results per page |

## 6. Still to do

- Horizontal (page-by-page) reading in the new reader.
- Save / share a copy of the PDF with notes and drawings.
- Then remove the classic reader.

## 7. Other changes this session

- Account menu (⋮) is now a side panel; its colors follow light/dark correctly. "Default" label under violet.
- Library shows 2 books per row with larger buttons.
- Replies are now in English.
- Unused packages removed: `docx_to_text`, `xml`, `image`. `archive` upgraded to 4.x.

## 8. Code map (for development)

| File | Role |
|---|---|
| `lib/ui/viewer/widgets/pdf_reader_screen.dart` | The new reader screen |
| `pdf_marks.dart` | Highlights store |
| `pdf_scanned_text.dart` | OCR words for scanned pages |
| `pdf_ink.dart` | Drawing model, painting, undo store |
| `pdf_notes.dart` | Text notes model and painting |
| `pdf_note_cards.dart` | Note cards store |
| `pdf_text_tools.dart` | Text formatting toolbar and font list |
| `reader_chrome.dart` | Reader colors (from paper + theme) |
| `routing/app_navigator.dart` | Opens the new reader; ⋮ → classic reader |
