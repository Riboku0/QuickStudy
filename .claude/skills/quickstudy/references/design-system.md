# QuickStudy design system

## Colors

The original light-mode colors must not change.

| Role | Value |
|---|---|
| Background | `#F3EFE6` cream |
| Cards | `#FFFFFF`, radius 22–28 (`AppTokens.radiusLarge` 28 / `radiusMedium` 22 / `radiusSmall` 16), shadow `0x12000000` blur 22, offset (0, 8) |
| Text | `ink #202020`, `muted` = 54% black |
| Accent | `yellow #FFD84D`, `yellowSoft #FFF1B8`, `yellowTint #FFF6CF`, `yellowDeep #8A6D00` |
| Soft yellow for big areas | `AppColors.accentSoft` (`#FAE8A9` light / `#4A4128` dark) + `onAccentSoft` (black / yellow). Used by `AppButtonKind.accent`, `Tint.accent`, the highlighted Study tile, and the settings selection. Strong yellow is for small marks only. |
| PDF | red `#C62828` / `#FDE4E1` |
| Images | blue `#1565C0` / `#DDEBFF` |
| Correct / info | green `#218838` / `#DDF3E2`, indigo `#3949AB` / `#DCE5FF` |

Dark mode is a warm variant: background `#141310`, cards `#1F1D19`, hero `#2E2B24`, and the same yellow.

Semantic colors:
- `AppColors.line`: borders and dividers.
- `AppColors.hero`: the dark featured card. Text on it is white or yellow.
- `AppColors.onYellow`: content on yellow, black in both modes.
- `AppColors.chip`: neutral chip background.

`main.dart` rebuilds the whole tree when the theme or language changes, and state is kept.

## Type

The font is **Almarai** (Arabic and Latin) since 19 Oct. It is the free font closest to DIN Next Arabic, which the user asked for; DIN itself is commercial. Almarai only has weights 300 / 400 / 700 / 800, so body and caption use w400. There is no default letter spacing; `tracked()` adds 0.9 only in LTR.

`AppText` styles: display 30/800, title 20/700, headline 16/700, body 14.5/500, caption 12/500, label 13/800.

Also available: `AppText.tabular` for numbers, and `AppText.tracked(context, style)`, which removes letter spacing in RTL.

## Shared widgets (`core_ui.dart`)

`AppIcon`, `PageHeader(title, overline, trailing)`, `SectionHeader` (a 4×16 yellow bar plus text), `TwoLineTitle`, `AppPill(text, background, foreground, dot)`, `SoftCard(onTap, color, padding, radius, border, shadow)`, `IconTile(icon, tint, size, glow)`, `FileThumbnail(lecture, width, height, radius, showBadge)`, `AppButton(label, onPressed, icon, kind: primary|accent|secondary, busy)`, `CircleAction(icon, tooltip, onPressed, dark, size, color, iconColor)`, `EmptyState(icon, title, message, actionLabel, onAction)`, `InfoNote`, `ProgressTrack`, `showAppMessage(context, text, tone: neutral|success|error)`, `confirmDeleteFile`, `ConstrainedContent` (max width 640, uses `Center`), `textDirectionFor`, `formatBytes`, `formatDay(date, s)`.

Never put `ConstrainedContent` in a `bottomNavigationBar`. Its `Center` expands to full height and hides the body. Use `Center(heightFactor: 1)` there instead.

## Paper style (`lib/ui/core/ui/paper.dart`), shared by Library, Study, Subject, Chapter and Settings

- **Background:** `PaperBackground` is the fixed decorated background. `PaperScaffold` is a transparent Scaffold over it, used for pushed screens.
- **Tones:** `PaperTone.gold` / `button` / `line` / `card`, plus `PaperTone.title(size:)` for Amiri titles.
- **Header and cards:**
  - `PaperHeader(overline, title, actions)`: gold overline, an Amiri 36 title, then a thin gold divider.
  - `PaperCard`: semi-transparent, with a gold border.
  - `PaperAddButton`: gold "+" in day mode, dark in night mode.
  - `AppButtonKind.gold`: the main button on paper screens.
- **Shelves:**
  - `ShelfLayout.of(width)` gives the side padding (≥ 28), the number of items per shelf and the cover size.
  - `ShelfRow<T>(items, layout, cover, label)` lays out the covers, the shelf board and the labels under the board.
- **Study:**
  - **Current Study page (replaces the course cards below):** a copy of the user's purple reference.
    - It does not use the paper background. Its colours come from `StudyTone` in `study_tone.dart`, and the purple applies to this page only.
    - From the top:
      - Greeting with the user's avatar from `assets/avatars/avatar.png`.
      - Purple goal card showing finished chapters out of the total.
      - "Subjects" heading with a "New subject" button.
      - Subject rows: a `SubjectIconTile`, the name, the chapter count, and the read percentage at the end.
    - Subject icons:
      - They are **Phosphor Duotone** icons from the `phosphoricons_flutter` package. Each icon has its own colour (`subjectIcons` in `subject_widgets.dart`).
      - A subject with no icon gets one chosen by its id (`subjectIconKey`) so subjects look different. A new subject starts with a random icon.
      - The user rejected Fluent 3D emoji images and the plain stroke hugeicons for subjects.
      - The rest of the app still uses hugeicons.
    - Cover images appear on the subject page only.
    - The subject and chapter pages use the same Study theme, not the paper one: `StudyScaffold`, `StudyCard`, `StudyButton` and purple accents, all in `study_tone.dart`. Paper now covers only Library and Settings.
    - Planned later: Google sign-in and a greeting with the user's name.
  - Previous version, kept for reference: course cards copied from the user's "Student Dashboard" reference:
    - A wide cover at a 2.4 ratio (`SubjectCover`). It is a user-picked image; without one, a quiet grey area shows the subject name.
    - Below the cover: a gold hugeicons icon (`AppIcons.subjects` keys, stored in the DB) and the name.
    - Then two pills: chapter count and "X% read".
  - The user rejected per-subject colours. Don't add them back.
  - `SubjectDialog` has name, icon and an optional cover image (`pickImage` comes from the ViewModel).
  - Cards scale to 0.98 on press. There is one card per row on phones and two from 700 px wide.
- **Home tab (file manager)** has not been converted yet. The user wants that as a separate step.

## Screens

- **المكتبة (HomeScreen)**: PDF reading only. Redesigned on 19 Oct from the user's purple reference, using the Study theme (`StudyTone`). There is no paper background, shelf or Amiri title.
  - **Header:** purple greeting with a sun or moon icon, "المكتبة" with a book icon, and a short subtitle. On the other side are search (shows a title search field) and the ⋮ account menu.
  - **"Recently read" carousel:** a `PageView` of up to 4 recent books with dots.
    - The cover is tilted over a soft purple blob.
    - Next to it: a pill, the title, the percent, a purple bar, the page, and a purple "Continue reading" button.
  - **"Your books" row:** the count and "Add PDF".
  - **Category tabs:** All, Novels, Studies, Philosophy, Works. The selected one is filled purple. Colours and icons come from `categoryStyle`.
  - **Grid:** 3 per row on phones.
    - Each card has the cover, a purple bookmark badge if the book has bookmarks, a progress strip, the title, a category pill and ⋯.
    - ⋯ or a long press opens `_BookSheet`: category chips, **that book's bookmarks** (tap to open the page, × to remove), and delete.
- **Bookmarks** are created from the viewer bar (a whole page) or from "علامة" in the selection menu (with the text). They are listed per book in the Library's ⋯ sheet. `AppNavigator.openDocument(page:)` opens a given page.
- **Account menu** (⋮ on every tab, `ui/shell/profile_menu.dart`): a sheet with the avatar, the editable user name, theme and language choices, and "All settings". The name appears in the Study greeting.
- **Study / Subject / Chapter**: see architecture.md, section 5.
- **Flashcards**: a card that flips (white to hero), the remaining cards stacked behind it, and an end screen.
- **Quiz**: options change color, an explanation, a yellow score ring, and an answer review.
- **Settings**: three theme squares with a mini preview, and the language rows.

## Bottom bar (do not change without a request)

- A floating glass bar with a yellow indicator that slides when dragged.
- Height 58, side padding 14.
- The glass is `surface` at 0.38 alpha (light) / 0.48 (dark), blur 24.
- The indicator is soft **purple** with no glow (user request, 18 Oct): `#7259DA` at 0.16 in light mode, `#9483EE` at 0.26 in dark mode.
- The selected item is deep purple `#5B43C6` in light mode and light purple `#C3B8FA` in dark mode.
- In Arabic the bar starts from the right.

## Taste rules (from the user's chosen skills)

The user chose these skills: flutter-architecting-apps, theming, layout, responsive, localization, performance; ui-taste, design-taste-frontend, minimalist-ui, copywriting, anti-slop.

In practice:
- Very soft shadows, thin borders, enough white space.
- One accent per screen (yellow); everything else calm.
- No emoji in the UI, and no marketing words ("Seamless", "Elevate"). Short sentences that say what happens.
- Every state has its own UI: loading, empty, and error with "try again".
- Touch targets ≥ 44–48 px. Semantics labels on icon buttons.
- Performance:
  - `const` where possible.
  - `RepaintBoundary` around thumbnails.
  - `cacheWidth` on images.
  - Animate only on interaction.
