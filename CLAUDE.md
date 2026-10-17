# CLAUDE.md — QuickStudy

تعليمات لـ Claude Code. اقرأ الملف كاملًا قبل أي تعديل، وحدّث القسمين 6 و9 بعد كل مرحلة.

---

## 0. عن المشروع

**QuickStudy** تطبيق مذاكرة بـ Flutter لأندرويد. المستخدم يرفع محاضراته (PDF أو صور)، فيقرأها ويكتب عليها ملاحظات، ثم يذاكرها ببطاقات واختبارات. الهدف النهائي أن يولّد الذكاء الاصطناعي الملخصات والبطاقات والاختبارات من ملفات المستخدم نفسه.

- **المسار على الجهاز:** `C:\study\FlutterProjects\project\project`
- **جهاز الاختبار:** moto g75 5G (أندرويد)
- **نظام التطوير:** Windows (الأوامر تُكتب لـ PowerShell)
- **لغة المستخدم:** العربية. **رُدّ عليه بالعربية دائمًا**، وأبقِ الكود وأسماء الملفات بالإنجليزية.

---

## 1. قواعد العمل (إلزامية)

1. **لا تستخدم git أبدًا.** لا `git status` ولا `git diff` ولا `commit` ولا أي أمر git، حتى للقراءة.
2. **تغيير رئيسي واحد في كل مرة.** لا تعِد بناء ما يعمل إلا إذا طلب المستخدم ذلك صراحة.
3. **حافظ على التصميم والميزات العاملة.** الألوان الأصلية والشريط السفلي العائم لا يتغيران إلا بطلب.
4. **بعد كل تعديل شغّل `flutter analyze`** وأصلح كل الأخطاء (errors) قبل أن تقول إنك انتهيت. التحذيرات (warnings) أصلحها إن كانت من تعديلك.
5. **لا تعتبر ميزة مكتملة قبل أن يختبرها المستخدم على الجهاز.** صنّف كل ميزة: مكتملة ومختبرة / مضافة وغير مختبرة / مخطط لها.
6. **عند خطأ وقت التشغيل** اطلب أول كتلة `EXCEPTION CAUGHT BY` من الطرفية، لا رسالة الشاشة الحمراء. الرسالة الظاهرة غالبًا خطأ تابع وليست السبب (مثل `_elements.contains(element)`).
7. **تحقق من واجهة أي حزمة في إصدارها المثبّت قبل استخدامها** (pub.dev أو الكود في `.pub-cache`). لا تعتمد على الذاكرة.
8. **لا تضع مفتاح API سريًا داخل التطبيق.** الذكاء الاصطناعي يمر عبر خادم وسيط (المرحلة 4).
9. **بعد تغيير شيء جذري** (provider جديد، ملف جديد في `main.dart`) ذكّر المستخدم أن يوقف التطبيق ويشغّل `flutter run` من جديد، لأن Hot reload لا يكفي.
10. **اشرح للمستخدم بالعربية** ما غيّرته وما يجب أن يختبره، باختصار وبدون مصطلحات زائدة.

---

## 2. الحزم

| الحزمة | الاستخدام | ملاحظات مهمة |
|---|---|---|
| `provider` | حقن التبعيات (`config/dependencies.dart`) | `context.read` فقط في `initState` أو الأحداث، **ليس داخل `build`** |
| `hugeicons ^1.2.0` | كل الأيقونات | النوع `List<List<dynamic>>` (typedef `AppIconData`)، ليس `IconData`. تُعرض بـ `AppIcon`. تحقّق من الاسم قبل إضافته: `https://pub.dev/documentation/hugeicons/latest/hugeicons/HugeIcons/<name>-constant.html` |
| `sqflite` + `path` + `path_provider` | قاعدة البيانات والملفات | قاعدة `quickstudy.db`، جدول `lectures(id, name, filePath, fileType, dateAdded)` |
| `file_picker ^13` | اختيار وحفظ الملفات | دوال static: `FilePicker.pickFiles()` و`FilePicker.saveFile()`. **لا يوجد `FilePicker.platform`** |
| `syncfusion_flutter_pdf` + `printing` | قراءة PDF ورسم صفحاته | `Printing.raster(bytes, pages: [i], dpi: ...)` |
| `flutter_tesseract_ocr` | OCR | `ara+eng` |
| `share_plus ^13` | المشاركة | `SharePlus.instance.share(ShareParams(...))` |
| `google_fonts` | Readex Pro + خطوط الملاحظات | يُحمَّل من الإنترنت أول مرة |
| `flutter_localizations` (SDK) | العربية واتجاه RTL | في pubspec: `flutter_localizations: sdk: flutter` |
| `url_launcher ^6.3.3` | فتح DeepL وChatGPT وترجمة Google بالنص المحدد | `launchUrl(uri, mode: LaunchMode.externalApplication)` بلا `canLaunchUrl` (فلا حاجة لـ `<queries>`) |

**حزم لا تعمل أو مهجورة (لا تستخدمها):** `phosphor_flutter` (تعطّلت لأن `IconData` صار `final class`)، و`lucide_icons`.

**حزم غير مستخدمة يمكن حذفها من pubspec:** `docx_to_text`، `archive`، `xml`، `google_mlkit_text_recognition`، `csv`، `image`، `file_selector`.

---

## 3. الهيكل (MVVM حسب دليل Flutter الرسمي)

```text
lib/
├── main.dart                     # MultiProvider + QuickStudyApp (يطبّق المظهر واللغة ويعيد بناء الشجرة)
├── config/dependencies.dart      # إنشاء كل الخدمات والمستودعات
├── routing/app_navigator.dart    # كل الانتقالات (push/pop): openDocument, openFlashcards, openQuiz, openSettings...
├── utils/
│   ├── result.dart               # Result<T> = Ok | Err
│   └── command.dart              # Command0 / Command1: running / completed / error / result / clearResult
├── domain/models/                # Lecture, ImportSummary, Flashcard, QuizQuestion, StudyDeck, ReadingProgress, ReaderSettings, Bookmark
├── data/
│   ├── services/                 # وصول مباشر للنظام، بلا منطق
│   │   ├── database_service.dart
│   │   ├── file_storage_service.dart   # نسخ/حذف الملفات والملاحظات
│   │   ├── file_picker_service.dart
│   │   ├── settings_service.dart       # quickstudy_settings.json
│   │   ├── reading_progress_service.dart # quickstudy_progress.json (آخر صفحة لكل PDF)
│   │   ├── reader_settings_service.dart  # quickstudy_reader.json (إعدادات العارض)
│   │   ├── bookmark_service.dart         # quickstudy_bookmarks.json (العلامات المرجعية)
│   │   ├── ocr_service.dart              # OCR للصفحات الممسوحة: Printing.raster ← extractHocr ← كلمات بمواضعها، مخزنة في quickstudy_ocr/{id}/{page}.json
│   │   ├── thumbnail_service.dart      # معاينة أول صفحة PDF (ThumbnailService.instance)
│   │   └── file_text_extractor.dart    # استخراج النص + OCR
│   └── repositories/
│       ├── bookmarks/            # BookmarkRepository: togglePage / addText / remove / removeForLecture
│       ├── lecture/              # LectureRepository (ChangeNotifier) + LocalLectureRepository
│       ├── progress/             # ReadingProgressRepository: record / progressFor / recent (حفظ مؤجل 800ms)
│       ├── reader/               # ReaderSettingsRepository: update / reset (لكل الكتب)
│       ├── settings/             # SettingsRepository: AppThemeChoice + AppLanguageChoice
│       └── study/                # StudyRepository + SampleStudyRepository (بيانات تجريبية)
└── ui/
    ├── core/
    │   ├── themes/app_theme.dart # AppPalette, AppColors, AppText, AppTokens, Tint, AppTheme
    │   ├── themes/app_icons.dart # AppIcons (كل الأيقونات)
    │   ├── l10n/app_strings.dart # كل النصوص: AppStrings.of(context) → _En / _Ar
    │   └── ui/                   # المكونات المشتركة، كلها تُصدَّر من core_ui.dart
    ├── shell/                    # app_shell.dart (IndexedStack + 3 تبويبات) + floating_nav_bar.dart
    ├── home/                     # view_models + widgets
    ├── study/                    # study / flashcards / quiz
    ├── library/
    ├── settings/
    ├── viewer/widgets/document_viewer_screen.dart   # العارض (كبير، ليس MVVM بعد)
    ├── viewer/widgets/reader_settings_sheet.dart    # لوحة إعدادات القراءة (ألوان ثابتة فاتحة)
    ├── viewer/widgets/text_marks.dart               # تحديد النص: استخراج الكلمات (Isolate) + TextMark + الرسم + القائمة
    ├── viewer/widgets/reader_chrome.dart            # ألوان واجهة القراءة (لوحة الإعدادات، قائمة التحديد، شريط القلم، الزوم): فاتحة نهارًا وكحلية ليلًا
    └── editor/widgets/document_editor_screen.dart   # غير مربوط بأي زر
```

**تدفق البيانات (اتجاه واحد):** Service ← Repository ← ViewModel ← View (عبر `ListenableBuilder`). الأحداث بالعكس: View → أمر (Command) في ViewModel → Repository.

**قواعد الهيكل:**
- كل شاشة = View + ViewModel. لا منطق في الويدجت، ولا ويدجت في الـ ViewModel.
- الـ ViewModel لا يُرجع نصوصًا للعرض. يُرجع enum أو بيانات، والواجهة تترجمها (مثال: `DayPart`، `DateBucket`).
- `LectureRepository` هو المصدر الوحيد للملفات؛ Home وLibrary يستمعان له.
- ViewModels الصفحات الثلاث تُنشأ في `AppShell.initState`. Flashcards وQuiz وSettings تُنشئ ViewModel خاصًا بها.
- لإضافة مصدر بيانات جديد: اكتب Repository جديدًا وغيّر سطرًا واحدًا في `dependencies.dart`.

---

## 4. اللغة والمظهر الداكن (قواعد يجب احترامها في كل كود جديد)

### النصوص
- **لا تكتب نصًا ظاهرًا مباشرة في الواجهة.** أضِفه في `AppStrings` (abstract)، ثم في `_En` و`_Ar`. المحلل يعطي خطأ إذا نسيت لغة.
- الاستخدام: `final s = AppStrings.of(context);` ثم `Text(s.home)`.
- الجمع: `s.files(n)`، `s.cards(n)`، `s.questions(n)`. صيغ الجمع العربية جاهزة في `_Ar._n` (1، 2، 3–10، 11+).
- **لا `letterSpacing` مع نص قد يكون عربيًا.** استخدم `AppText.tracked(context, style)`، فهو يلغي التباعد في RTL (التباعد يفصل الحروف العربية).
- محتوى المستخدم (أسماء الملفات، الأسئلة) قد يكون بلغة مختلفة عن الواجهة: استخدم `textDirectionFor(text)`.
- الأسهم (`chevron`، `next`، `previous`) تنعكس تلقائيًا في العربية عبر `AppIcons.directional`. أي سهم جديد أضِفه لهذه المجموعة.
- استخدم `AlignmentDirectional` و`EdgeInsetsDirectional` و`PositionedDirectional` بدل left/right عندما يهم الاتجاه.

### الألوان
- `AppColors.x` **getters وليست `const`**، لأنها تتبدل بين `AppPalette.light` و`AppPalette.dark`.
  - أي `const` يحتوي `AppColors.x` (عدا `AppColors.yellow` و`AppColors.onYellow`) أو `Tint.x` أو `s.x` أو `context` = خطأ ترجمة.
  - لا تستخدم `Tint.x` أو `AppColors.x` كقيمة افتراضية لمعامل (default parameter). اجعل المعامل nullable واستخدم `?? Tint.yellow`.
- ألوان دلالية:
  - `AppColors.line`: الحدود والفواصل.
  - `AppColors.hero`: خلفية البطاقات الداكنة المميزة (نصها `Colors.white` أو `AppColors.yellow`).
  - `AppColors.onYellow`: النص والأيقونات فوق الأصفر (أسود في الوضعين).
  - `Tint.accent`: أصفر + onYellow.
- لا `Colors.white` ولا `Color(0x14000000)` للخلفيات والحدود العادية؛ استخدم `AppColors.surface` و`AppColors.line`.
- `main.dart` يعيد بناء كل الشجرة (`_rebuildAll`) عند تغيير المظهر أو اللغة، ولا تضيع الحالة.
- **العارض يبقى فاتحًا دائمًا:** `Theme(data: AppTheme.lightOnly())` في `AppNavigator.openDocument`، وألوانه ثابتة داخله.

---

## 5. نظام التصميم

**الألوان الأصلية (الوضع الفاتح، لا تتغير):**

| الدور | القيمة |
|---|---|
| الخلفية | `#F3EFE6` كريمي |
| البطاقات | `#FFFFFF`، زوايا 22–28، ظل `0x12000000` blur 22 offset (0, 8) |
| النص | `ink #202020`، `muted` = 54% أسود |
| المميز | `yellow #FFD84D`، `yellowSoft #FFF1B8`، `yellowTint #FFF6CF`، `yellowDeep #8A6D00` |
| الأصفر الخفيف للمساحات الكبيرة | `AppColors.accentSoft` (`#FAE8A9` نهارًا / `#4A4128` ليلًا) و`onAccentSoft` (أسود / أصفر). بطلب المستخدم ليطابق مؤشر الشريط: أزرار `AppButtonKind.accent`، و`Tint.accent`، وبطاقة Flashcards في Study، والاختيار في الإعدادات. الأصفر القوي للعلامات الصغيرة فقط (شريط العناوين، التقدم، النص على hero) |
| PDF | أحمر `#C62828` / `#FDE4E1` |
| الصور | أزرق `#1565C0` / `#DDEBFF` |
| صحيح / معلومات | أخضر `#218838` / `#DDF3E2`، نيلي `#3949AB` / `#DCE5FF` |

**الوضع الداكن:** نسخة دافئة (خلفية `#141310`، بطاقات `#1F1D19`، hero `#2E2B24`)، والأصفر نفسه.

**الخط:** Readex Pro (عربي + إنجليزي). أنماط `AppText`: display 30/800، title 20/700، headline 16/700، body 14.5/500، caption 12/500، label 13/800.

**المكونات المشتركة** (`ui/core/ui/core_ui.dart`): `AppIcon`، `PageHeader`، `SectionHeader` (شريط أصفر 4×16 + نص كبير)، `TwoLineTitle`، `AppPill`، `SoftCard`، `IconTile`، `FileThumbnail`، `AppButton` (primary / accent / secondary + busy)، `CircleAction` (فاتح / داكن)، `EmptyState`، `InfoNote`، `ProgressTrack`، `showAppMessage`، `confirmDeleteFile`، `ConstrainedContent`، `textDirectionFor`، `formatBytes`، `formatDay(date, s)`.

**كل تبويب له واجهة مختلفة:**
- **ترتيب التبويبات:** 0 = الرئيسية (`LibraryScreen`: كل الملفات والرفع)، 1 = Study، 2 = المكتبة (`HomeScreen`: قراءة PDF). أسماء الملفات بقيت كما هي.
- **المكتبة / HomeScreen (قراءة PDF فقط):** **خلفية ثابتة** بإطار مزخرف (`assets/backgrounds/library_light.webp` نهارًا و`library_dark.webp` ليلًا، `BoxFit.fill` حتى لا تُقص الزخارف الجانبية) خلف `CustomScrollView`، وألوان `_Tone` منها: ذهبي `#B08D57` ليلًا / `#AE9672` نهارًا للخطوط ولوح الرف وكلمة "المكتبة"، وزر "+" نهارًا ذهبي `#9C7F52` بأيقونة بيضاء (`CircleAction` صار يقبل `color` و`iconColor`)، والبطاقات شبه شفافة (`_Tone.card`). الهامش الجانبي 28. رأس: الترحيب صغير ذهبي + "المكتبة" كبيرة بخط **Amiri** (`GoogleFonts.getFont`، 36/700) + الإعدادات + "إضافة PDF" الداكن، ثم خط رفيع ← "تابع القراءة" ← **رفوف**: أغلفة حقيقية (أول صفحة) بنسبة 1.45، كعب رفيع، شريط تقدم أصفر أسفل الغلاف، لوح رف تحت كل صف، والعناوين تحت اللوح. عدد الكتب في الرف من العرض المتاح (`_minCoverWidth` 92) ← **العلامات المرجعية**: صفوف بفواصل رفيعة (غلاف صغير + الكتاب + الصفحة + النص المحفوظ بخط بلون التحديد)، لمسة تفتح الصفحة، سحب للحذف. ضغطة مطولة على الغلاف للحذف.
- **العلامات المرجعية:** زر في شريط العارض (`bookmark` / `bookmarkSaved`) لصفحة كاملة، وزر "علامة" في قائمة تحديد النص يحفظ النص. `AppNavigator.openDocument(page:)` يفتح الصفحة. حذف الكتاب يحذف علاماته. رقم الصفحة في شريط العارض صار زر "اذهب إلى صفحة".
- **Study:** دوّار مجموعات (بطاقات hero بأرقام صفراء) + نقاط الصفحة ← مربعا الوضعين (Flashcards أصفر، Quiz أبيض) ← معاينة أول 3 أسئلة.
- **Library:** رأس فيه الإعدادات والترتيب وزر الرفع الداكن (الرفع كله من هنا) ← بطاقة تخزين بشريط نسبة PDF/صور ← بحث وتبويبات (`_TypeTabs` بمؤشر منزلق) مثبتان ← قائمة مجمّعة بالتاريخ بمعاينات حقيقية، حذف بالسحب.
- **Flashcards:** بطاقة تنقلب (أبيض → hero)، البطاقات المتبقية خلفها، شاشة نهاية.
- **Quiz:** خيارات تتلون، توضيح، حلقة نتيجة صفراء، مراجعة الإجابات.
- **Settings:** مربعات المظهر الثلاثة بمعاينة مصغّرة، وصفوف اللغة.
- **العارض:** زر `Icons.tune` يفتح `ReaderSettingsSheet`: السطوع (طبقة سوداء)، الهوامش (`_hPad` getter)، 6 ألوان ورق مقتبسة من مرجع المستخدم (`ReaderBackground`: درجات هادئة من صفحات المرجع: classic `#F5E9D4`، green `#E9F2E5`، blue `#E8F0F7`، light `#FBF7F4`، warm `#F3DFC9`، dark `#262B29`؛ والأسماء القديمة المحفوظة تُحوَّل بـ `_oldBackgrounds`)، قراءة عامودية/أفقية (`PageView` بسحب عادي، **التقليب ثلاثي الأبعاد حُذف بطلب المستخدم**)، **ألوان الصفحة** (`_pageFilter`: مصفوفة لونية تحوّل الأبيض إلى لون الورق والأسود إلى لون الحبر، تُطبَّق على **صورة الصفحة فقط** داخل `_PageTile` (`pageFilter`/`paperColor`)، والملاحظات خارجها بألوانها، وعلى الورق الداكن (`darkPaper`) تظهر الملاحظات الداكنة فاتحة `#E6E0D4`، فالصفحة نفسها تأخذ اللون وما حولها بنفس اللون)، **الليلي** موحّد وهادئ بلون الثيم الليلي: ورق كحلي `#222733` وحبر `#D5DAE2` (لا أسود/أبيض حاد)، وألوان الخلفية معطّلة فيه وتعمل نهارًا فقط، إعادة الضبط. **الزوم في الوضعين**: في الأفقي `InteractiveViewer` للصفحة الحالية فقط (`_pagedZoom`)، والتقليب يتوقف عند إصبعين أو صفحة مكبرة أو الكتابة (`_pagerLocked`)، ويرجع الزوم عند تغيير الصفحة، والتحديد معطل والصفحة مكبرة أفقيًا. والقلم في الوضعين (في الأفقي يتوقف سحب الصفحات أثناء الكتابة). إعدادات الخط مؤجلة (تحتاج وضع نص).
- **القلم (كتابة مباشرة):** لمسة على الصفحة تنشئ نصًا فارغًا في مكانها وتفتح لوحة المفاتيح، و`_NoteView` يعرض `TextField` بلا إطار بنفس الخط والمكان (لا نافذة `_TextDialog`، حُذفت). لمسة خارج النص أو زر الصح تنهي الكتابة: الفارغ يُحذف والباقي يُحفظ. التحريك أثناء الكتابة **بسحب النص بالإصبع** (`_DragToMove`: Listener، أكثر من 10 بكسل = سحب وأقل = لمسة للمؤشر، و`_noteDragging` يوقف تمرير الصفحة) أو من مقبض `Icons.open_with`. المقابض صغيرة: دوائر 14، الحبة 14×36، أزرار الزوايا 30 (منطقة اللمس 40–48). عند بدء الكتابة في العامودي يكبّر حول النص إن كان خطه أصغر من 17 بكسل (`_zoomToEditing` إلى ~22 بكسل)، ويرجع التكبير السابق عند الإنهاء. مقاسات الإطار من `_pageRect` و`_pw`/`_ph` لتعمل في الوضعين. في العامودي يتحرك التمرير ليبقى النص فوق لوحة المفاتيح.
- **تحديد النص في العارض:** ضغطة مطولة على كلمة ← مقبضان لتوسيع التحديد + قائمة: 4 أنواع (تظليل، خط تحت، شطب، متموج) × 5 ألوان، مسح، نسخ، ملاحظة، علامة، و**المزيد** (`_showMoreSheet`: ترجمة DeepL، اسأل ChatGPT، ترجمة Google، مشاركة؛ تفتح التطبيق أو الموقع بالنص، والعربي يُترجم للإنجليزية وغيره للعربية، والنص مقصوص إلى 1500 حرف). لمسة على **نقطة الملاحظة** (`_noteDotAt`، 24 بكسل) تفتح تعديل الملاحظة مباشرة. **التحديد يعمل والصفحة مكبرة** في الوضعين (الأفقي: `_pageRect` = `MatrixUtils.transformRect(_pagedZoom.value, _pagedRect)`). لمسة على تحديد محفوظ تختاره. يعتمد على `PdfTextExtractor` (مواضع الكلمات نسبة من الصفحة)، وإن كان في الصفحة أقل من 25 كلمة (صفحة ممسوحة أو علامة مائية فقط) يعمل `OcrService` (ara+eng، psm 3، 220dpi، صفحة واحدة في كل مرة، رسالة "جارٍ قراءة النص" بعد 0.6 ثانية) والنتيجة تُحفظ لكل صفحة فلا تتكرر. **تجهيز مسبق:** بعد توقف التمرير 0.7 ثانية (`_schedulePrefetch` من `_reportPage`) يُجهَّز نص الصفحة الحالية والتاليتين في الخلفية (`PageTextCache.prefetch`)، فيكون التحديد في الصفحات الممسوحة فوريًا غالبًا. التحديدات في `quickstudy_notes/{id}_marks.json` (منفصلة عن الملاحظات)، داخل التطبيق فقط وليست في "حفظ نسخة". التحديد داخل صفحة واحدة.

**الشريط السفلي:** زجاجي عائم بمؤشر أصفر ينزلق بالسحب. عُدّل بطلب المستخدم (مقتبس من مرجعه): ارتفاع 58 وهامش جانبي 14 (أقصر وأعرض)، زجاج أشف (`surface` بشفافية 0.38 نهارًا / 0.48 ليلًا، blur 24)، مؤشر أصفر خفيف بلا توهج (0.42 / 0.22)، والمحدد أسود نهارًا وأصفر ليلًا. **لا تغيّر شكله بعد ذلك إلا بطلب.** في العربية يبدأ من اليمين.

**أسلوب الكتابة في الواجهة:** جمل قصيرة ومحددة، بلا عبارات تسويقية ولا إيموجي.

**الأداء:** `const` حيث يمكن، `RepaintBoundary` للمعاينات، `cacheWidth` للصور، والحركة عند التفاعل فقط.

---

## 6. الحالة الحالية

### مكتمل ومختبر على الجهاز
- [x] التشغيل على أندرويد، والتنقل بين الصفحات الثلاث بالشريط العائم.
- [x] رفع PDF وصور، وحفظها في SQLite، وفتحها وحذفها.
- [x] العارض: تكبير، تنقل، ملاحظات منسقة تُحفظ في `quickstudy_notes/{id}_notes.json`.
- [x] الهيكل الجديد MVVM يعمل (Home وLibrary ظهرتا على الجهاز).
- [x] معاينات الصور الحقيقية في Home.
- [x] Library تعمل بعد إصلاح الشاشة الحمراء.
- [x] زر "المزيد" في قائمة التحديد: DeepL وChatGPT وترجمة Google والمشاركة (اختبره المستخدم 18 أكتوبر).
- [x] لمسة على نقطة الملاحظة تفتح تعديلها (اختبره المستخدم 18 أكتوبر).

### مضاف وغير مختبر (اختبره أولًا)
- [ ] معاينة الصفحة الأولى من PDF (في Library وHome).
- [ ] تبويبات Library بنص في المنتصف، وشريط التخزين الملون.
- [ ] صفحة الإعدادات وزرها أعلى الصفحات الثلاث.
- [ ] الوضع الداكن على كل الشاشات.
- [ ] العربية مع RTL، بما فيها العارض والشريط السفلي.
- [ ] Study الجديدة: الدوّار، Flashcards، Quiz.
- [ ] حفظ نسخة ومشاركتها من العارض.
- [ ] استخراج النص وOCR.
- [ ] Home الجديدة (PDF فقط): بطاقة المتابعة، الشبكة، الحذف المطوّل، حالة "لا توجد ملفات PDF".
- [ ] تقدم القراءة: العارض يفتح على آخر صفحة، والنسبة تتحدث في Home بعد الرجوع، وتبقى بعد إغلاق التطبيق.
- [ ] زر الرفع في Library (الرأس + حالة المكتبة الفارغة) ورسائل الرفع.
- [ ] تبديل التبويبات: الرئيسية = إدارة الملفات والرفع، المكتبة = قراءة PDF.
- [ ] زر "إضافة PDF" في المكتبة (يقبل PDF فقط).
- [ ] إعدادات القراءة في العارض: كل خيار يتغير فورًا ويبقى بعد إغلاق التطبيق، التبديل بين العامودي والأفقي يحافظ على الصفحة، التقليب ثلاثي الأبعاد، الوضع الليلي، العربية (التقليب من اليمين).
- [ ] أغلفة PDF بعد إصلاح `whenComplete`: تظهر وتبقى بعد إعادة التشغيل.
- [ ] تحديد النص: الضغط المطول، المقبضان، الأنواع والألوان، الحفظ بعد الإغلاق، المسح، النسخ، الملاحظة، المشاركة، في العامودي والأفقي، وعلى كتاب عربي.
- [ ] المكتبة الجديدة: الرأس والخط، الرفوف بالأغلفة والعناوين الطويلة، شريط التقدم، الحذف المطوّل، حالة لا كتب.
- [ ] العلامات المرجعية: زر الصفحة في العارض (يتبدل شكله)، زر "علامة" في قائمة التحديد، الظهور في المكتبة، الانتقال للصفحة، السحب للحذف، البقاء بعد إعادة التشغيل.
- [ ] القلم: لمسة ← مؤشر مباشر بلا نافذة، الكتابة في المنتصف، مقبض التحريك أثناء الكتابة، الحفظ بلمسة خارج النص، حذف النص الفارغ، تعديل نص موجود بلمسة ثانية، في العامودي والأفقي، وفوق لوحة المفاتيح.
- [ ] OCR: ضغطة مطولة على صفحة من "الليالي البيضاء" (ممسوح) ← رسالة القراءة ← تحديد يعمل، وفوري في المرة الثانية وبعد إعادة التشغيل. جودة النص العربي المنسوخ.
- [ ] خلفية المكتبة: النهاري والليلي، ثابتة عند التمرير، الزخارف غير مقصوصة، والعناصر مقروءة فوقها.
- [ ] ألوان الصفحة: كل لون خلفية نهاري يلوّن الصفحة نفسها، الليلي هادئ وموحّد، الألوان معطلة ليلًا مع الشرح.
- [ ] الزوم في القراءة الأفقية: بإصبعين وبالأزرار، التنقل داخل الصفحة المكبرة، رجوع التقليب عند المقاس الطبيعي.
- [ ] الأصفر الخفيف في الأزرار وبطاقة Flashcards والإعدادات، وتصميم بطاقة "تابع القراءة" الجديد (بلا خط علوي، زر صغير).
- [ ] القلم: سحب النص بالإصبع أثناء الكتابة، المقابض الأصغر، التكبير التلقائي حول النص ورجوعه.
- [ ] تحديد النص في الأفقي ومع الزوم: السجل أكّد أن الضغطة تجد الكلمة والصفحة مكبرة (`zoomed=true index=61`). أسطر `[LP]` حُذفت.
- [ ] التجهيز المسبق للنص: الضغطة المطولة في صفحة ممسوحة بعد ثوانٍ من فتحها تحدد فورًا بلا رسالة.
- [ ] واجهة القراءة في الليلي: لوحة الإعدادات وقائمة التحديد وشريط القلم وأزرار الزوم كحلية.

---

## 7. خطة العمل (بالترتيب)

### المرحلة 1: اختبار ما بُني (الأولوية الآن)
- [ ] `flutter pub get` ثم `flutter analyze` (صفر أخطاء) ثم `flutter run`.
- [ ] الإعدادات: تلقائي/فاتح/داكن يغيّر كل الشاشات فورًا، ويبقى بعد إغلاق التطبيق.
- [ ] العربية: الاتجاه ينقلب، الأسهم تنعكس، الشريط السفلي يبدأ من اليمين، السحب عليه صحيح، صيغ الجمع صحيحة.
- [ ] الداكن: كل الشاشات مقروءة (Home، Study، البطاقات، الاختبار، Library، الإعدادات، الحوارات، الرسائل).
- [ ] العارض يفتح فاتحًا في الداكن، ونصوصه بالعربية.
- [ ] معاينات PDF: تظهر بعد لحظة أول مرة، وفورًا بعدها. ملف تالف يعرض أيقونة.
- [ ] الرفع، والرسائل، والمزامنة بين Home وLibrary، والحذف بالسحب، والبحث، والترتيب.
- [ ] Study: الدوّار، البطاقات، الاختبار، المجموعة العربية.

### خطة "تحسين المكتبة وتجربة القراءة" (طلب المستخدم)
- [x] م1: المكتبة كرفوف + قسم العلامات المرجعية مربوط ببيانات حقيقية (مضاف وغير مختبر).
- [x] م2: حذف التقليب ثلاثي الأبعاد (طلب المستخدم بدل تحسينه). الأفقي يبقى سحبًا عاديًا.
- [x] م3: القلم بالكتابة المباشرة وفي الوضعين (مضاف وغير مختبر). نُفّذ قبل م2 بطلب المستخدم.
- [x] م4: OCR للصفحات الممسوحة مع طبقة تحديد بإحداثيات الكلمات (مضاف وغير مختبر). صور JPG/PNG لم تُدعم بعد في التحديد.

### إعادة تصميم الواجهة (طلب المستخدم، 17 أكتوبر)
- [x] أ: Home لقراءة PDF فقط مع تقدم القراءة (مضاف وغير مختبر).
- [ ] ب: Study = مواد مثل المجلدات، يضيف المستخدم الشباتر (ملفات PDF) داخل مادتها. جداول `subjects` و`chapters` في SQLite (نسخة 2 مع ترحيل). صفحة الشابتر: قراءة، محادثة، بطاقات، اختبار (البطاقات والاختبار تجريبية حتى المرحلة 4).
- [ ] ج: محادثة لكل شابتر، واجهة فقط: فقاعات + حقل كتابة، الرسائل محفوظة لكل شابتر، والرد الذكي لاحقًا عبر الخادم الوسيط.

### المرحلة 2: تنظيف
- [ ] حذف الحزم غير المستخدمة من pubspec.
- [ ] تضمين خط Readex Pro في assets حتى يعمل أول تشغيل بدون إنترنت.
- [ ] (اختياري) تحويل العارض إلى MVVM: `DocumentViewerViewModel` + `NotesRepository`. الملف 2400 سطر، قسّمه على مراحل.
- [ ] (اختياري) حذف `editor/` إن لم يُستخدم.
- [ ] حذف ملف المعاينة المؤقت عند حذف الملف (`ThumbnailService.evict`).

### المرحلة 3: استخراج النص
- [ ] `ExtractionRepository`: يحفظ النص المستخرج مرتبطًا بـ `lecture.id` (جدول أو ملف)، ولا يعيد الاستخراج إن كان محفوظًا.
- [ ] حالات تحميل وخطأ واضحة في الواجهة، وعدم إرسال نص فارغ للذكاء الاصطناعي.
- [ ] قرار: هل يعود دعم DOCX وPPTX؟ (اسأل المستخدم)

### المرحلة 4: الذكاء الاصطناعي
- [ ] **اسأل المستخدم** عن المزود والميزانية قبل البدء.
- [ ] خادم وسيط صغير يحمل المفتاح (لا مفتاح داخل التطبيق).
- [ ] `data/services/ai_service.dart`: يرسل النص ويستقبل JSON.
- [ ] الصيغة المطلوبة تطابق `Flashcard.fromMap` و`QuizQuestion.fromMap` الموجودين.
- [ ] Command في ViewModel للتوليد، مع تحميل وفشل وإعادة محاولة، ونصوص في `AppStrings`.
- [ ] زر "اصنع بطاقات واختبارًا" على بطاقة الملف (Library) وفي العارض.
- [ ] تقسيم المحاضرات الطويلة على أجزاء.

### المرحلة 5: حفظ المواد المولدة
- [ ] جداول SQLite: `decks`، `flashcards`، `quiz_questions` مرتبطة بـ `lectures.id` (مع ترحيل نسخة قاعدة البيانات).
- [ ] `SqliteStudyRepository`، وتبديله في `dependencies.dart`، ثم حذف البيانات التجريبية.
- [ ] حذف الملف يحذف مجموعاته.

### المرحلة 6: الإصدار
- [ ] اختبار الملفات الكبيرة والتالفة، والعمل بدون إنترنت.
- [ ] أيقونة التطبيق واسمه (عربي/إنجليزي).
- [ ] `flutter build apk --release`، مراجعة الأذونات والخصوصية، README.

### مؤجل
التكرار المتباعد (SRS)، توقع نسبة الحفظ، الإحصائيات، سلاسل الأيام، الصوت، المزامنة السحابية، الحسابات، تصدير Anki وQuizlet.

---

## 8. أخطاء سابقة ودروسها

| المشكلة | السبب | الحل |
|---|---|---|
| `The getter 'platform' isn't defined for FilePicker` | file_picker الحديث | دوال static: `FilePicker.saveFile(...)` |
| `IconData can't be extended outside of its library` | phosphor_flutter قديمة | استخدام hugeicons |
| `Undefined name 'LucideIcons'` / `BrutalTheme` / `onOpenTab` | ملفات قديمة بقيت بعد فك الضغط | احذف `lib` القديم كاملًا قبل وضع الجديد |
| `Could not find the correct Provider<ThumbnailService>` | خدمة جديدة + Hot reload | `ThumbnailService.instance` بدل provider، وإعادة تشغيل كاملة |
| شاشة Library حمراء `_elements.contains(element)` | خطأ تابع لخطأ سابق | استبدال الملفات + `flutter clean`. اطلب أول `EXCEPTION CAUGHT BY` دائمًا |
| شريط التخزين غير ظاهر | `ColoredBox` بلا ابن ارتفاعه صفر | `Container(height: 10, decoration: ...)` |
| نص `SegmentedButton` ينزل في ارتفاع 40 | قيود الارتفاع | تبويبات مخصصة `_TypeTabs` بـ `Center` |
| `context.read` داخل حقل `late` | يُستدعى أثناء `build` | إنشاء الـ ViewModels في `initState` |
| غلاف PDF يظهر لحظة ثم يختفي، ولا يظهر بعد إعادة التشغيل | `whenComplete(() => _inFlight.remove(k))` يُرجع الطلب نفسه، و`whenComplete` تنتظر ما يُرجع فيبقى معلّقًا للأبد | دالة بأقواس `{ _inFlight.remove(k); }` لا تُرجع شيئًا |
| `LateInitializationError` بعد إضافة حقل في ViewModel | Hot reload لا يعيد إنشاء الـ ViewModels الموجودة | Hot restart (`R`) أو `flutter run` من جديد |
| تحديد يعمل في كتاب ولا يعمل في آخر | الكتاب الثاني ممسوح: طبقة نصه فيها "Tele: @Arab_Books" فقط (تأكدنا بـ PdfTextExtractor على نسخة من الجهاز) | OCR عند قلة الكلمات |
| `object is unsendable ... _Future` في Isolate.run | الدالة أُنشئت داخل كلاس فحملت حقوله | إنشاء الدالة في دالة عليا لا تلتقط إلا البايتات ورقم الصفحة |
| التطبيق يتجمد عند إضافة ملاحظة على التحديد، والخطأ الظاهر `_dependents.isEmpty` | الخطأ الأول: `A TextEditingController was used after being disposed`. التخلص منه بعد `showDialog` مباشرة، والنافذة ما زالت تُرسم في حركة الإغلاق | `_InputDialog` (StatefulWidget) يملك الـ controller ويتخلص منه في `dispose`. لا تنشئ controller خارج النافذة أبدًا |
| نص الملاحظة الأبيض يختفي في الليلي | فلتر لون الورق كان على الصفحة كلها فحوّل الأبيض إلى لون الورق الداكن | الفلتر على صورة الصفحة فقط، والملاحظات خارجه |

---

## 9. أوامر مفيدة (بدون git)

```powershell
flutter pub get
flutter analyze
flutter run
flutter clean
flutter build apk --release
flutter run > log.txt 2>&1   # لحفظ السجل كاملًا عند خطأ
flutter run --print-dtd       # يطبع عنوان DTD لربط Claude (Dart MCP) بالتطبيق
```

---

## 11. المهارات المرجعية (Skills) التي اعتمدها المستخدم

طبّق مبادئها في كل عمل على الواجهة والهيكل. إن كانت مثبتة عندك استخدمها، وإلا ارجع للروابط.

**Flutter (الرسمية):**
- https://www.skills.sh/flutter/agent-plugins/flutter-architecting-apps (الهيكل MVVM، الأهم)
- https://www.skills.sh/flutter/agent-plugins/flutter-theming
- https://www.skills.sh/flutter/agent-plugins/flutter-routing-and-navigation
- https://www.skills.sh/flutter/agent-plugins/flutter-performance
- https://www.skills.sh/flutter/agent-plugins/flutter-layout
- https://www.skills.sh/flutter/agent-plugins/flutter-build-responsive-layout
- https://www.skills.sh/flutter/agent-plugins/flutter-localization (مفيدة للعربية)

**التصميم والكتابة:**
- https://www.skills.sh/site/uizze.sh/ui-taste
- https://www.skills.sh/leonxlnx/taste-skill/design-taste-frontend
- minimalist-ui (من مستودع leonxlnx/taste-skill)
- https://www.skills.sh/coreyhaines31/marketingskills/copywriting
- hallmark، anti-prose-slop، no-ai-slop، anti-slop
- web-design-guidelines، building-components، ui-ux-pro-max، frontend-ui-engineering
- building-native-ui (من Expo)، lark-apps

**الخلاصة العملية من هذه المهارات:**
- ظلال ناعمة جدًا وحدود رفيعة، ومساحات بيضاء كافية.
- لا إيموجي، ولا عبارات تسويقية مثل "Seamless" أو "Elevate". نصوص قصيرة ومحددة تقول ما يحدث.
- عنصر مميز واحد في كل شاشة (الأصفر)، والباقي هادئ.
- كل حالة لها شكل: تحميل، فارغ، خطأ مع "حاول مرة أخرى".
- أهداف لمس لا تقل عن 44–48 بكسل، ونصوص بديلة (Semantics) للأزرار.

---

## 10. سجل التحديثات

- **15 أكتوبر 2026:** استخراج النص وOCR العربي.
- **16 أكتوبر 2026:** العارض والملاحظات، حفظ نسخة ومشاركتها، إصلاح `FilePicker.platform`، صفحتا Study وLibrary.
- **17 أكتوبر 2026:**
  - إعادة بناء الهيكل كاملًا بنمط MVVM، والعودة للألوان الأصلية، وhugeicons.
  - معاينات حقيقية للملفات، تبويبات Library، إصلاح شريط التخزين، تخطيط Home الجديد.
  - صفحة الإعدادات، الترجمة العربية الكاملة مع RTL، الوضع الداكن.
  - إضافة `flutter_localizations` إلى pubspec، وملف `.mcp.json` لخادم Dart MCP.
  - إعادة تصميم أ: Home لقراءة PDF فقط + حفظ آخر صفحة في العارض (`initialPage` / `onPageChanged`) + نقل الرفع إلى Library.
  - تبديل التبويبين: الرئيسية للملفات والرفع، والمكتبة لقراءة PDF.
  - زر "إضافة PDF" في المكتبة، ولوحة إعدادات القراءة في العارض (`ReaderSettingsRepository`).
  - إصلاح أغلفة PDF (طلب ينتظر نفسه في `ThumbnailService`)، وتحديد النص وتلوينه في العارض.
  - المرحلة 1 من خطة المكتبة: رفوف الكتب والعلامات المرجعية (`BookmarkRepository`).
  - Skills المطبّقة (من github.com/flutter/agent-plugins و Leonxlnx/taste-skill): flutter-apply-architecture-best-practices، flutter-build-responsive-layout، minimalist-skill.
  - تشغيل التطبيق بـ `flutter run --print-dtd` ثم ربط خادم Dart MCP بالعنوان المطبوع، فيصير hot reload/restart وقراءة الأخطاء ممكنًا من Claude.
  - القلم: كتابة مباشرة على الصفحة بدون نافذة، مقبض تحريك، ويعمل في القراءة الأفقية. الترتيب المتفق عليه: القلم ← تحديد "شرخ في الذاكرة" (فحص سبب فشل التحديد ثم OCR) ← تحسين التقليب.
  - تشخيص التحديد: "الليالي البيضاء" ممسوح (3 كلمات لكل صفحة)، و"شرخ في الذاكرة" نصي. إضافة OCR (`OcrService` + `orderWords`) واختبار `test/ocr_hocr_test.dart`.
  - إصلاح تجمد التطبيق عند "ملاحظة" التحديد و"اذهب إلى صفحة" (`_InputDialog`)، وحذف التقليب ثلاثي الأبعاد.
  - خلفيتا المكتبة (نهاري/ليلي) من المستخدم، وتنسيق ألوان المكتبة معهما.
  - خلفيتان جديدتان للمكتبة، زر "+" ذهبي نهارًا، ألوان الصفحة نفسها وليلي هادئ، الزوم في الأفقي.
  - الشريط السفلي أقصر وأشف بمؤشر أخف، و"المكتبة" كبيرة بخط Amiri والترحيب صغير.
  - خلفية ليلية جديدة، الأصفر الخفيف الموحد (`accentSoft`)، بطاقة "تابع القراءة" أبسط، القلم: سحب بالإصبع ومقابض أصغر وتكبير تلقائي.
  - امتلاء القرص: `flutter clean` وحذف كاش Gradle (بموافقة المستخدم)، ثم بناء ناجح.
  - ألوان أهدأ للكلاسيكي والدافئ، ليلي كحلي، `ReaderChrome` لواجهة القراءة، والتجهيز المسبق لنص الصفحات (OCR في الخلفية).
  - التحديد مع الزوم، زر "المزيد" للترجمة (`url_launcher`)، تعديل الملاحظة من نقطتها.
  - **التالي:** يختبر المستخدم المكتبة والعارض على الجهاز، ثم إعادة التصميم ب (Study: مواد وشباتر). لاحقًا: وضع نص بإعدادات الخط.
