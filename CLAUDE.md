# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**QuickStudy** — تعليمات لـ Claude Code. اقرأ الملف كاملًا قبل أي تعديل، وحدّث القسمين 6 و10 بعد كل مرحلة.

## أوامر سريعة

```powershell
flutter pub get
# التحليل على المجلدات الفعلية فقط (في lib/ ملفات قديمة غير مستخدمة فيها أخطاء: lib/theme، lib/home، lib/*_page.dart...)
flutter analyze lib/main.dart lib/config lib/data lib/domain lib/routing lib/ui lib/utils
flutter test                          # كل الاختبارات (test/)
flutter test test/ocr_hocr_test.dart  # اختبار واحد
flutter run -d ZY22LZZNQN --print-dtd # التشغيل على الهاتف + عنوان DTD لربط Dart MCP (hot reload/restart وقراءة الأخطاء)
```

- بعد إضافة حزمة أصلية (native) أو تعديل `AndroidManifest.xml`: `flutter run` كامل، hot restart لا يكفي.
- `adb` ليس في PATH: `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`. قبل لقطة شاشة (`exec-out screencap -p`) تحقق أن الهاتف غير مقفل (`isKeyguardShowing`) ولا تتحكم به والمستخدم يستعمله.
- `README.md` قالب Flutter الافتراضي، لا معلومات فيه.

---

## 0. عن المشروع

**QuickStudy** تطبيق مذاكرة بـ Flutter لأندرويد. المستخدم يضيف كتبه ومحاضراته (PDF أو EPUB) إلى المكتبة أو إلى مواد المذاكرة، فيقرأها ويكتب عليها ملاحظات، ثم يذاكرها ببطاقات واختبارات. الهدف النهائي أن يولّد الذكاء الاصطناعي الملخصات والبطاقات والاختبارات من ملفات المستخدم نفسه.

- **المسار على الجهاز:** `C:\study\FlutterProjects\project\project`
- **جهاز الاختبار:** moto g75 5G (أندرويد)
- **نظام التطوير:** Windows (الأوامر تُكتب لـ PowerShell)
- **لغة المستخدم:** يكتب بالعربية، لكن **رُدّ عليه بالإنجليزية** (طلبه 19 أكتوبر). نصوص الواجهة تبقى بالعربية والإنجليزية في `AppStrings` كما هي.

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
| `sqflite` + `path` + `path_provider` | قاعدة البيانات والملفات | قاعدة `quickstudy.db` نسخة 5: `lectures(id, name, filePath, fileType, dateAdded, origin, category)` (`origin` = library / study)، `subjects(id, name, color, icon, coverPath, createdAt)`، `chapters(id, subjectId, lectureId UNIQUE, title, sortOrder, createdAt)`. حذف ملف يحذف شابتره، وحذف مادة أو شابتر يحذف ملفاته |
| `file_picker ^13` | اختيار وحفظ الملفات | دوال static: `FilePicker.pickFiles()` و`FilePicker.saveFile()`. **لا يوجد `FilePicker.platform`** |
| `syncfusion_flutter_pdf` + `printing` | قراءة PDF ورسم صفحاته | `Printing.raster(bytes, pages: [i], dpi: ...)` |
| `flutter_tesseract_ocr` | OCR | `ara+eng`. **العارض لا يستدعي `extractHocr` من الإضافة**: قناة `quickstudy/ocr` في `MainActivity.kt` (`TessBaseAPI` من مكتبة الإضافة نفسها، خيط بأولوية عادية)، و`OMP_THREAD_LIMIT=1` في `onCreate`. لا تحذف الإضافة من pubspec (مكتبة Tesseract تأتي معها) |
| `pdfrx ^2.6.6` (**نسخة محلية** `third_party/pdfrx` عبر `dependency_overrides`) | عارض PDF الجديد (PDFium). التعديل الوحيد: `pdfrxPageColorFilter` (مرشح لوني يُطبَّق أثناء رسم صور الصفحات = ألوان الورق بلا تكلفة). عند تحديث pdfrx أعد التعديل في `lib/src/widgets/pdf_viewer.dart` | `PdfViewer.file(path, controller:, initialPageNumber:, params: PdfViewerParams(backgroundColor, margin, pagePaintCallbacks, onViewerReady, onPageChanged, viewerOverlayBuilder, pageOverlaysBuilder, textSelectionParams))`، `PdfViewerController`: `goToPage(pageNumber:)`، `zoomUp/zoomDown`، `invalidate()`، `isReady`. `PdfViewerScrollThumb` للسحب السريع |
| `share_plus ^13` | المشاركة | `SharePlus.instance.share(ShareParams(...))` |
| `google_fonts` | **Almarai** (خط التطبيق منذ 19 أكتوبر، أقرب خط مجاني لـ DIN Next Arabic الذي طلبه المستخدم؛ DIN الأصلي تجاري) + خطوط الملاحظات | يُحمَّل من الإنترنت أول مرة. Almarai أوزانه 300/400/700/800 فقط |
| `flutter_epub_viewer ^2.1.0` | قارئ EPUB (`EpubReaderScreen`) | يعتمد على `flutter_inappwebview` (WebView). يحتاج `android:usesCleartextTraffic="true"` في `<application>` (مضاف). الواجهة: `EpubViewer(epubController, epubSource: EpubSource.fromFile, initialCfi, displaySettings: EpubDisplaySettings(fontSize int, flow, defaultDirection, theme: EpubTheme.custom))`، `onRelocated(EpubLocation{startCfi, progress 0..1})`، `controller.display(cfi:)` يقبل href الفصل، `setFontSize(fontSize: double)`، `addHighlight`، `search` |
| `flutter_localizations` (SDK) | العربية واتجاه RTL | في pubspec: `flutter_localizations: sdk: flutter` |
| `phosphoricons_flutter ^1.1.1` | أيقونات المواد فقط (Duotone) | `PhosphorIcon(PhosphorIconsDuotone.x, color:, duotoneSecondaryOpacity:)`. ليست `phosphor_flutter` القديمة المعطلة. باقي التطبيق على hugeicons |
| `url_launcher ^6.3.3` | فتح DeepL وChatGPT وترجمة Google بالنص المحدد | `launchUrl(uri, mode: LaunchMode.externalApplication)` بلا `canLaunchUrl` (فلا حاجة لـ `<queries>`) |

**حزم لا تعمل أو مهجورة (لا تستخدمها):** `phosphor_flutter` (تعطّلت لأن `IconData` صار `final class`)، و`lucide_icons`.

**حزم غير مستخدمة يمكن حذفها من pubspec:** `docx_to_text`، `xml`، `google_mlkit_text_recognition`، `csv`، `image`، `file_selector` (`archive` قد يُستخدم لاستخراج غلاف EPUB). حزمة `http` حُذفت مع البحث والتنزيل من الإنترنت (ألغاه المستخدم 19 أكتوبر)، وإذن `INTERNET` باقٍ لـ google_fonts.

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
│   │   ├── reading_stats_service.dart  # quickstudy_stats.json (ثوانٍ القراءة لكل يوم + الجلسات)
│   │   ├── epub_position_service.dart  # quickstudy_epub.json: CFI لكل كتاب EPUB + حجم الخط (EpubPositionService.instance)
│   │   └── file_text_extractor.dart    # استخراج النص + OCR
│   └── repositories/
│       ├── bookmarks/            # BookmarkRepository: togglePage / addText / remove / removeForLecture
│       ├── lecture/              # LectureRepository (ChangeNotifier) + LocalLectureRepository
│       ├── progress/             # ReadingProgressRepository: record / progressFor / recent (حفظ مؤجل 800ms)
│       ├── reader/               # ReaderSettingsRepository: update / reset (لكل الكتب)
│       ├── settings/             # SettingsRepository: المظهر، اللغة، userName، AppAccent (الثيم)، bookCategories (تصنيفات أضافها المستخدم)
│       ├── stats/                # ReadingStatsRepository: وقت القراءة (لوحة الرئيسية)
│       ├── subjects/             # SubjectRepository: المواد والشباتر، يستمع لـ LectureRepository
│       └── study/                # StudyRepository + SampleStudyRepository (بيانات تجريبية)
└── ui/
    ├── core/
    │   ├── themes/app_theme.dart # AppPalette, AppColors, AppText, AppTokens, Tint, AppTheme
    │   ├── themes/app_icons.dart # AppIcons (كل الأيقونات)
    │   ├── themes/study_tone.dart # AppTone (6 ثيمات) + StudyTone (اللون الرئيسي الحالي، `purple` = لون الثيم)
    │   ├── l10n/app_strings.dart # كل النصوص: AppStrings.of(context) → _En / _Ar
    │   └── ui/                   # المكونات المشتركة، كلها تُصدَّر من core_ui.dart (ومنها study_surfaces.dart: StudyScaffold/StudyCard/StudyButton)
    ├── shell/                    # app_shell.dart (IndexedStack + 3 تبويبات) + floating_nav_bar.dart + profile_menu.dart (قائمة ⋮)
    ├── dashboard/                # تبويب الرئيسية: لوحة أرقام (عرض فقط)
    ├── home/                     # تبويب المكتبة: home_screen.dart + add_book_screen.dart (نموذج إضافة كتاب)
    ├── study/                    # study (المواد) / subject (الشباتر) / chapter / flashcards / quiz + subject_widgets (الأيقونات، الغلاف، النوافذ)
    ├── settings/                 # لم تعد تُفتح من أي زر
    ├── viewer/widgets/pdf_reader_screen.dart        # عارض PDF الوحيد (pdfrx، عامودي فقط). العارض القديم document_viewer_screen حُذف 23 أكتوبر
    ├── viewer/widgets/pdf_export.dart               # حفظ نسخة / مشاركة نسخة: التظليل والقلم ونص الصفحة فوق الصفحات
    ├── viewer/widgets/epub_reader_screen.dart       # قارئ EPUB: صفحات بالسحب، الفهرس، حجم الخط، يحفظ CFI والتقدم
    ├── viewer/widgets/reader_settings_sheet.dart    # لوحة إعدادات القراءة (ألوان ثابتة فاتحة)
    ├── viewer/widgets/text_marks.dart               # تحديد النص: استخراج الكلمات (Isolate) + TextMark + الرسم + القائمة
    ├── viewer/widgets/reader_chrome.dart            # ألوان واجهة القراءة (لوحة الإعدادات، قائمة التحديد، شريط القلم، الزوم): فاتحة نهارًا وكحلية ليلًا
    └── editor/widgets/document_editor_screen.dart   # غير مربوط بأي زر
```

**تدفق البيانات (اتجاه واحد):** Service ← Repository ← ViewModel ← View (عبر `ListenableBuilder`). الأحداث بالعكس: View → أمر (Command) في ViewModel → Repository.

**قواعد الهيكل:**
- كل شاشة = View + ViewModel. لا منطق في الويدجت، ولا ويدجت في الـ ViewModel.
- الـ ViewModel لا يُرجع نصوصًا للعرض. يُرجع enum أو بيانات، والواجهة تترجمها (مثال: `DayPart`، `DateBucket`).
- `LectureRepository` هو المصدر الوحيد للملفات (PDF وEPUB وصور)؛ المكتبة والرئيسية والمواد تستمع له. `Lecture.isBook` = PDF أو EPUB.
- ViewModels الصفحات الثلاث تُنشأ في `AppShell.initState`. الشاشات المفتوحة بـ push (إضافة كتاب، Flashcards، Quiz...) تُنشئ ViewModel خاصًا بها في `AppNavigator`، والشاشة تتخلص منه في `dispose`.
- كل فتح كتاب يمر بـ `AppNavigator.openDocument`: يتفرع لـ `EpubReaderScreen` (التقدم = `1 + progress*99` من 100) أو `PdfReaderScreen` (غير PDF وEPUB لا يُفتح: رفع الصور أُلغي)، ويسجّل وقت القراءة.
- لإضافة مصدر بيانات جديد: اكتب Repository جديدًا وغيّر سطرًا واحدًا في `dependencies.dart`.

---

## 4. اللغة والمظهر الداكن (قواعد يجب احترامها في كل كود جديد)

### النصوص
- **لا تكتب نصًا ظاهرًا مباشرة في الواجهة.** أضِفه في `AppStrings` (abstract)، ثم في `_En` و`_Ar`. المحلل يعطي خطأ إذا نسيت لغة.
- الاستخدام: `final s = AppStrings.of(context);` ثم `Text(s.home)`.
- الجمع: `s.files(n)`، `s.cards(n)`، `s.questions(n)`. صيغ الجمع العربية جاهزة في `_Ar._n` (1، 2، 3–10، 11+).
- **لا `letterSpacing` مع نص قد يكون عربيًا.** استخدم `AppText.tracked(context, style)`، فهو يلغي التباعد في RTL (التباعد يفصل الحروف العربية).
- محتوى المستخدم (أسماء الملفات، الأسئلة) قد يكون بلغة مختلفة عن الواجهة: استخدم `textDirectionFor(text)`. **القاعدة (22 أكتوبر، طلب المستخدم: "يلتزم قواعد اللغة حتى لو دعمت كل اللغات"):** أول حرف قوي يحدد الاتجاه (مثل `dir=auto`): العبرية والعربية (والفارسية والأردية) والسريانية والثانا والنكو من اليمين، وغيرها من اليسار، والأرقام والرموز لا تحدده. `strongDirection(text)` ترجع null قبل أول حرف، فحقول الكتابة تأخذ وقتها لغة التطبيق (`?? Directionality.of(context)`). اختبار: `test/text_direction_test.dart`. التلقائي في محاذاة الملاحظات `TextAlign.start`.
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

**الخط:** Almarai (عربي + إنجليزي، `AppTheme.fontName`). أنماط `AppText`: display 30/800، title 20/700، headline 16/700، body 14.5/400، caption 12/400، label 13/800، كلها بلا تباعد حروف (`tracked` يضيف 0.9 في الإنجليزية فقط).

**المكونات المشتركة** (`ui/core/ui/core_ui.dart`): `AppIcon`، `PageHeader`، `SectionHeader` (شريط أصفر 4×16 + نص كبير)، `TwoLineTitle`، `AppPill`، `SoftCard`، `IconTile`، `FileThumbnail`، `AppButton` (primary / accent / secondary + busy)، `CircleAction` (فاتح / داكن)، `EmptyState`، `InfoNote`، `ProgressTrack`، `showAppMessage`، `confirmDeleteFile`، `ConstrainedContent`، `textDirectionFor`، `formatBytes`، `formatDay(date, s)`.

**كل تبويب له واجهة مختلفة:**
- **ترتيب التبويبات:** 0 = الرئيسية (`DashboardScreen`: لوحة أرقام)، 1 = Study، 2 = المكتبة (`HomeScreen`: قراءة PDF). أسماء الملفات بقيت كما هي.
- **المكتبة / HomeScreen (كتب PDF وEPUB):** أُعيد تصميمها (19 أكتوبر) من مرجع المستخدم بنفس ثيم المذاكرة البنفسجي (`StudyTone`)، **بلا خلفية الورق ولا الرفوف ولا خط أميري**. من الأعلى: تحية بالبنفسجي مع شمس/قمر، "المكتبة" بأيقونة، "كتبك كلها في مكان واحد"، وقائمة الحساب ⋮ ← **بطاقة آخر ما قرأت**: `PageView` حتى 4 كتب من `ReadingProgressRepository.recent` بنقاط، الغلاف مائل فوق بقعة بنفسجية، شارة، العنوان، النسبة، شريط بنفسجي، الصفحة، زر "تابع القراءة" ← "كتبك" + عددها + "إضافة كتاب" ← **تبويبات التصنيف** (الكل، روايات، دراسات، فلسفة، مؤلفات، ثم ما أضافه المستخدم؛ `HomeViewModel.categories` = novel/study/philosophy/works، ألوانها وأيقوناتها في `categoryStyle`) ← **شبكة** 3 كتب في السطر (أكثر في الشاشات العريضة): غلاف + رمز علامة بنفسجي إن كان للكتاب علامات + شريط تقدم + العنوان + شارة التصنيف + ⋯. ⋯ أو الضغطة المطولة تفتح `_BookSheet`: اختيار التصنيف، **علامات هذا الكتاب فقط** (لمسة تفتح الصفحة، × تحذف)، حذف الكتاب. قسم العلامات العام حُذف بطلب المستخدم. التصنيف في `lectures.category` (قاعدة البيانات v5) عبر `LectureRepository.setCategory`.
- **إضافة كتاب (19 أكتوبر):** زر "إضافة كتاب" (المكتبة والحالة الفارغة) يفتح `AddBookScreen` + `AddBookViewModel` عبر `AppNavigator.openAddBook(category:)` (التصنيف المفتوح يُختار مسبقًا): خانة الملف (زر واحد يقبل PDF وEPUB، `FilePickerService.books`)، اسم الكتاب (يبدأ باسم الملف، الأحرف الممنوعة في أسماء الملفات تُستبدل)، التصنيف (بلا تصنيف + الأربعة الثابتة + ما أضافه المستخدم) وزر "+ تصنيف جديد" (`TextInputDialog`). الحفظ: `importFiles` بالاسم الجديد ثم `setCategory`. التصنيفات المضافة في `SettingsRepository.bookCategories` (تُحفظ في `quickstudy_settings.json`)، ومفتاحها هو اسمها، و`categoryName`/`categoryPlural` تُرجع المفتاح نفسه لأي تصنيف غير ثابت، و`categoryStyle` يعطيه لون الثيم. `HomeViewModel.allCategories` = الثابتة + المضافة.
- **البحث عن الكتب والتنزيل من الإنترنت ألغاهما المستخدم (19 أكتوبر)** وحُذف كودهما. لا تقترح مواقع غير رسمية أو مقرصنة (نور بوك، مواقع المانغا والمانهوا المترجمة)، وهنداوي/نور بوك خلف Cloudflare فلا تتجاوزه.
- **مخطط (طلب المستخدم):** في نموذج الإضافة، حقل الاسم يصير بحثًا في قاعدة بيانات كتب، واختيار نتيجة يملأ الاسم والتصنيفات، مع حفظ بيانات الكتاب استعدادًا لخطة **تقييم الكتب ومراجعتها** لاحقًا. ما جُرّب: Open Library (`search.json`، بلا مفتاح، ممتاز للأجنبي وضعيف للعربي، فيه subjects وأغلفة)، Wikidata (`wbsearchentities` بالعربية، وجد "الليالي البيضاء" ولم يجد "شرخ في الذاكرة")، Google Books (يحتاج مفتاحًا، الحصة بدونه صفر). قرار عدد التصنيفات لكل كتاب وما يُحفظ من البيانات لم يُحسم بعد.
- **EPUB (19 أكتوبر):** `Lecture.isEpub` و`isBook`. يُرفع من "إضافة كتاب" ومن "إضافة شابتر"، ويظهر في المكتبة بأيقونة كتاب خضراء (`Tint.green`، لا غلاف حقيقي بعد) ويدخل في أرقام الرئيسية. `EpubReaderScreen`: صفحات بالسحب (`EpubFlow.paginated`، الاتجاه RTL إن كان العنوان عربيًا)، أسهم تالي/سابق، شريط نسبة، الفهرس (الفصول الفرعية بإزاحة)، حجم الخط 12–34، ويفتح على آخر CFI. حذف الكتاب يحذف مكانه المحفوظ. **لم يُبنَ بعد:** التظليل والملاحظات والعلامات والبحث داخل الكتاب، وإعدادات تباعد الأسطر ونوع الخط والألوان والليلي، وغلاف EPUB الحقيقي (من OPF عبر `archive`).
- **الثيمات (19 أكتوبر):** `AppAccent` (violet, ocean, emerald, rose, sunset, graphite) في قائمة الحساب، تُحفظ في الإعدادات. `main.dart` يستدعي `StudyTone.use(accent)` ويعيد بناء الشجرة عند تغيير الثيم. كل الألوان البنفسجية في الوصف أدناه تعني لون الثيم الحالي (`StudyTone.purple`).
- **شريط حالة أندرويد مخفي** داخل التطبيق (`hideStatusBar()` في `main.dart`: `SystemUiMode.manual` مع أزرار التنقل فقط)، يعود بالسحب ثم يختفي بعد 3 ثوانٍ، ويُخفى عند الرجوع للتطبيق (`didChangeAppLifecycleState`).
- **العلامات المرجعية:** زر في شريط العارض (`bookmark` / `bookmarkSaved`) لصفحة كاملة، وزر "علامة" في قائمة تحديد النص يحفظ النص. تظهر من قائمة ⋯ لكل كتاب في المكتبة. `AppNavigator.openDocument(page:)` يفتح الصفحة. حذف الكتاب يحذف علاماته. رقم الصفحة في شريط العارض صار زر "اذهب إلى صفحة".
- **قائمة الحساب ⋮ (كل التبويبات):** `ProfileMenuButton` و`ProfileAvatar` و`showProfileMenu` في `ui/shell/profile_menu.dart`: صورة الحساب + الاسم (`SettingsRepository.userName`، يُحفظ في `quickstudy_settings.json`، لمسة لتغييره بنافذة تملك الـ controller) + المظهر واللغة كاختيارات. **"كل الإعدادات" حُذفت بطلب المستخدم** (صفحة الإعدادات لم تعد تُفتح من مكان). في الرئيسية والمذاكرة والمكتبة في الرأس. اسم المستخدم يظهر في تحية الرئيسية. الثيم البنفسجي صار مشتركًا: `StudyTone` في `ui/core/themes/study_tone.dart`، و`StudyScaffold`/`StudyCard`/`StudyButton` في `ui/core/ui/study_surfaces.dart`.
- **طابع الورق المشترك** (`ui/core/ui/paper.dart`، طلب المستخدم 18 أكتوبر: "انسخ المكتبة وطبقه على البقية"): `PaperBackground`، `PaperScaffold`، `PaperTone` (gold/button/line/card + `title()` بأميري)، `PaperHeader`، `PaperCard`، `PaperAddButton`، `ShelfLayout.of(width)`، `ShelfRow<T>`، `ShelfBoard`، و`AppButtonKind.gold`. تستخدمه المكتبة والإعدادات فقط (المذاكرة وصفحتا المادة والشابتر انتقلت لثيم المذاكرة البنفسجي بطلب المستخدم). الرئيسية (إدارة الملفات) لم تُحوَّل بعد (خطوة لاحقة بطلب المستخدم).
- **Study (المواد):** مقتبسة من مرجع المستخدم الثاني (18 أكتوبر، تطبيق بنفسجي فيه Daily Goal وToday's Schedule). **بلا خلفية الورق وألوانها** في هذه الصفحة؛ ألوانها في `StudyTone` (`ui/study/widgets/study_tone.dart`): خلفية `#F8F6FB` / `#15131B`، بطاقات بيضاء، بنفسجي `#7259DA` / `#9483EE` للصفحة فقط. من الأعلى: "المواد" بأيقونة + "جاهز تنجز شيئًا اليوم؟" + ⋮ (صورة الحساب والتحية حُذفتا بطلب المستخدم 19 أكتوبر؛ الصورة `assets/avatars/avatar.png` في قائمة الحساب فقط) ← بطاقة الهدف البنفسجية (الشباتر المنتهية من كل المواد X / Y، شريط أبيض، اقتباس) ← "المواد" + زر "مادة جديدة" ← صفوف المواد: `SubjectIconTile` (أيقونة **Phosphor Duotone** من حزمة `phosphoricons_flutter`، خط + تعبئة خفيفة، كل أيقونة بلونها في `subjectIcons` داخل `subject_widgets.dart`، 24 مفتاحًا؛ المادة بلا أيقونة تأخذ واحدة حسب رقمها `subjectIconKey` حتى تتنوع، والمادة الجديدة تبدأ بأيقونة عشوائية) + الاسم + عدد الشباتر + نسبة القراءة في الطرف. صور Fluent 3D جُرّبت ورفضها المستخدم. صورة الغلاف تظهر في صفحة المادة فقط. الاسم في التحية يأتي لاحقًا مع تسجيل الدخول بقوقل (مؤجل بطلب المستخدم بعد الأساسيات، ومعه جعل التطبيق ديناميكيًا).
  - **ثيم المذاكرة يشمل صفحتي المادة والشابتر** (طلب المستخدم 18 أكتوبر): `StudyScaffold` (خلفية `StudyTone.background`)، `StudyCard` (بطاقة بيضاء بظل بنفسجي)، `StudyButton` (زر بنفسجي)، والعناوين بخط التطبيق العادي، والتمييز بنفسجي بدل الذهبي. كلها في `study_tone.dart`.
  - **صفحة المادة** (`SubjectScreen`): غلاف + الاسم، قائمة الشباتر بنفس الارتفاع (عنوان سطر واحد + سطر حالة بأيقونة hugeicons دائمًا: "لم تبدأ بعد" / "صفحة X من Y" / ✓ "انتهيت منه" بالأخضر)، سحب من المقبض لإعادة الترتيب، قائمة ⋮ للتسمية والحذف (بتأكيد، يحذف الملف)، زر "إضافة شابتر" أصفر خفيف يرفع PDF مباشرة.
  - **الفصل بين المكتبة والمذاكرة** (طلب المستخدم 18 أكتوبر): `Lecture.origin` (`LectureOrigin.library` / `study`). الرئيسية والمكتبة تعرضان `!isStudy` فقط، والرفع من المادة `importFiles(origin: study, ids:)`. التكرار يُفحص داخل نفس المكان. ترحيل v3: ما كان في مادة صار study. حذف المادة يحذف ملفات شباترها.
  - **صفحة الشابتر** (`ChapterScreen`): بطاقة قراءة hero بالتقدم، محادثة (قريبًا)، بطاقات واختبار من المجموعة التجريبية الأولى بشارة "تجريبي" حتى المرحلة 4.
- **الرئيسية = مشهد البومة** (`ui/dashboard/`، 20 أكتوبر من مرجع المستخدم، الرأس بقي كما هو بطلبه): تحية + "الرئيسية" + ⋮ ← `HomeScene` (`home_scene.dart`): **رسمة غرفة من المستخدم** في الخلفية بحافة علوية موجية (21 أكتوبر)، والبومة المرسومة بالكود جالسة على مكتبها. **الخلفية:** `assets/scene/scene_night.jpg` و`scene_day.jpg` و**خريطة مناطق** `scene_mask.png` (21 أكتوبر، تُصنع بسكربت من صورة الليل: R داخل النافذة، G الجدار والستائر بما فيها جدار ضوء المصباح، و0 للمكتب والمصباح وغطائه المضيء والكتب والأصص واللوحة بمستطيلات ضيقة وللأوراق الخضراء ولما هو داكن، مع تنعيم Gaussian 6) فيُلوَّن كل جزء عمدًا بدل التخمين: النافذة بالوزن اللوني مع حماية الدافئ، والجدار صبغة 0.32 تتلاشى حول المصباح (`lampGlow`)، (1586×493، مقصوصتان من صورة المستخدم، صورة النهار أعلى من الليل 9 بكسل فتُزاح في الشيدر) يمزجهما `shaders/scene_tint.frag` حسب الساعة (`nightness`: ليل حتى 5:18، نهار من 6:06 حتى 18:30، ليل من 19:18، التبديل قصير حتى لا تظهر الشمس والقمر معًا) ويلوّن الكحلي والبنفسجي والوردي البارد بلون الثيم مباشرة (`uHue`، تشبع 0.8، والرمادي 0.15، والبنفسجي الأصلي بلا تلوين `uStrength`=0)، بوزن متوسط 5×5، داخل النافذة فقط تلوين كامل والغرفة (الجدار والستائر) صبغة خفيفة متساوية 0.3 حتى لا يتبقع الجدار حول ضوء المصباح (لاحظ المستخدم البقع في الزمردي)، وتتلاشى الصبغة بنعومة حول المصباح وفوقه (`lampGlow`: مسافة 110–310 بكسل من (378، 212)) فيبقى الجدار دافئًا بلا خط، وحماية الألوان الدافئة والخضراء المشبعة في البكسل نفسه (نوافذ القرية، المصباح، الخشب، الأوراق). الغروب والفجر = دفء وردي برتقالي على النافذة (`warm`). فوق الرسمة (`_FxPainter` بإحداثيات الصورة): نجوم الرسمة تومض في أماكنها، شهاب وطائران مرة كل 3 دقائق، سحابتان ناعمتان (blur) تعبران في 3 دقائق نهارًا، وسحب ليلية خفيفة يضيئها القمر (`_nightClouds`)، والكوب بلا هلال (طلب المستخدم)، ضوء المصباح يتنفس. الصورة تُقص من الجانبين (`_ArtFrame`، مركز 0.48)، والمشهد بنسبة `HomeScene.aspect` = 2.2 وتداخل البطاقة 14. البومة: `_LifePainter._seat` (780، 428) و`_size` 2.2. **حركات الليل (21 أكتوبر، طلب المستخدم: كل العشر، واللحظات النادرة كل 5–10 ثوانٍ):** وهج القمر يتنفس وسحابة رقيقة تعبره كل 30 ث (`_moonGlow`، القمر (1108، 112))، نوافذ القرية (16 نافذة مقيسة `_villageWindows`) تُطفأ وتُضاء كل 9 ث بلون داكن من الثيم، يراعات (`_fireflyDots`)، كل 6 ث بالتناوب شهاب أو خفاش يعبر أمام القمر (`_rareNight`)، فراشة حول المصباح (`_moth`، دورة 12 ث)، ظل البومة على الجدار خلفها وعلى المكتب نحو اليمين، دفء المصباح يسارها وبرودة القمر يمينها (طبقة saveLayer + srcATop)، تغفو كل 20 ث ثم تصحو فجأة بعينين واسعتين ثم تنظر إلى القمر (`doze`/`wake`/`look`)، بخار أبطأ وأطول. نهارًا: طائران كل 7.5 ث. **القهوة مساءً وليلًا فقط**: لا كوب أغلب الوقت، كل 10 ث تخرجه من تحت جناحها (الجيب (30، −24)) ثم ترتشف ثم تعيده (`mugVis`)، ونهارًا لا كوب والجناح يتدلى على جانبها. **الجناحان متصلان بالجسم** (21 أكتوبر، `_blendWing`: الجزء الخارج عن الجسم حاد، والجزء فوقه يذوب بنعومة blur 2.4، والجناح الأيمن نفس البيضاوي يمتد من الكتف (34، −46) إلى جانب الكوب فيمسكه ويبقى حادًا أمام الكوب `_mugArea`)، وحُذف احمرار الخدود، وخصلتا الأذنين بتدرج لون الرأس نفسه فتخرجان منه بلا خط. البومة نفسها لا تتغير إلا بطلب صريح (تجربة إعادة رسمها في Figma رُفضت؛ في ملف Figma `pGTmN8qoVmdTUsG8NToqnw` إطار "Owl / app rig" غير مستخدم). الشيدر في pubspec تحت `flutter: shaders:`، وإن فشل تحميله تُرسم الصورتان بلا تلوين. `debugHour` للمعاينة في الاختبارات (اختبار مؤقت يرسم HomeScene إلى PNG بـ `RenderRepaintBoundary.toImage`، ويحتاج `runAsync` لتحميل الصور وإطارًا إضافيًا لأن الظهور تدريجي). البومة بألوان ثابتة: تنفس، رمش، رشفة قهوة كل 10 ثوانٍ، بخار يصعد، نعسانة ليلًا. **نهارًا نشيطة** (`energy`: صباحًا 1، ظهرًا 0.6): عينان أوسع لامعتان، قفزات خفيفة وتمايل، تلويح بالجناح الأيسر، وبريق أصفر حول رأسها صباحًا فقط. طبقتان: خلفية ثابتة وطبقة حية بـ AnimationController واحد (تتوقف خارج التبويب وتحت الشاشات المفتوحة، وثابتة مع تقليل الحركة) ← بطاقة **متابعة القراءة** (آخر كتاب أو شابتر من `ReadingProgressRepository.recent`، الشابتر يعرض اسم مادته، وإن لم يُفتح شيء تفتح المكتبة) ← اختصارا **المذاكرة** (عدد المواد) و**المكتبة** (عدد الكتب) يبدلان التبويب (`onOpenTab`) ← **إحصائيات اليوم**: صفحات مقروءة (صفحات مختلفة مرّ بها في جلسات العارض اليوم، PDF فقط)، وقت الدراسة (وقت القراءة اليوم)، بطاقات مراجعة (`FlashcardsViewModel.next`، كل بطاقة مرة في الجولة)، أسئلة محلولة (`QuizViewModel.select`). كلها في `ReadingStatsRepository` (`quickstudy_stats.json`: `days`/`pages`/`cards`/`questions` لكل يوم + `sessions`). أعمدة الأسبوع وشبكات الأرقام القديمة حُذفت بطلب المستخدم. الـ ViewModel يفحص الوقت كل دقيقة ليتبدل المشهد والتحية.

- **Flashcards:** بطاقة تنقلب (أبيض → hero)، البطاقات المتبقية خلفها، شاشة نهاية.
- **Quiz:** خيارات تتلون، توضيح، حلقة نتيجة صفراء، مراجعة الإجابات.
- **Settings:** مربعات المظهر الثلاثة بمعاينة مصغّرة، وصفوف اللغة.
- **العارض:** زر `Icons.tune` يفتح `ReaderSettingsSheet`: السطوع (طبقة سوداء)، الهوامش (`_hPad` getter)، 6 ألوان ورق مقتبسة من مرجع المستخدم (`ReaderBackground`: درجات هادئة من صفحات المرجع: classic `#F5E9D4`، green `#E9F2E5`، blue `#E8F0F7`، light `#FBF7F4`، warm `#F3DFC9`، dark `#262B29`؛ والأسماء القديمة المحفوظة تُحوَّل بـ `_oldBackgrounds`)، قراءة عامودية/أفقية (`PageView` بسحب عادي، **التقليب ثلاثي الأبعاد حُذف بطلب المستخدم**)، **ألوان الصفحة** (`_pageFilter`: مصفوفة لونية تحوّل الأبيض إلى لون الورق والأسود إلى لون الحبر، تُطبَّق على **صورة الصفحة فقط** داخل `_PageTile` (`pageFilter`/`paperColor`)، والملاحظات خارجها بألوانها، وعلى الورق الداكن (`darkPaper`) تظهر الملاحظات الداكنة فاتحة `#E6E0D4`، فالصفحة نفسها تأخذ اللون وما حولها بنفس اللون)، **الليلي** موحّد وهادئ بلون الثيم الليلي: ورق كحلي `#222733` وحبر `#D5DAE2` (لا أسود/أبيض حاد)، وألوان الخلفية معطّلة فيه وتعمل نهارًا فقط، إعادة الضبط. **الزوم في الوضعين**: في الأفقي `InteractiveViewer` للصفحة الحالية فقط (`_pagedZoom`)، والتقليب يتوقف عند إصبعين أو صفحة مكبرة أو الكتابة (`_pagerLocked`)، ويرجع الزوم عند تغيير الصفحة، والتحديد معطل والصفحة مكبرة أفقيًا. والقلم في الوضعين (في الأفقي يتوقف سحب الصفحات أثناء الكتابة). إعدادات الخط مؤجلة (تحتاج وضع نص).
- **القلم (كتابة مباشرة):** لمسة على الصفحة تنشئ نصًا فارغًا في مكانها وتفتح لوحة المفاتيح، و`_NoteView` يعرض `TextField` بلا إطار بنفس الخط والمكان (لا نافذة `_TextDialog`، حُذفت). لمسة خارج النص أو زر الصح تنهي الكتابة: الفارغ يُحذف والباقي يُحفظ. التحريك أثناء الكتابة **بسحب النص بالإصبع** (`_DragToMove`: Listener، أكثر من 10 بكسل = سحب وأقل = لمسة للمؤشر، و`_noteDragging` يوقف تمرير الصفحة) أو من مقبض `Icons.open_with`. المقابض صغيرة: دوائر 14، الحبة 14×36، أزرار الزوايا 30 (منطقة اللمس 40–48). عند بدء الكتابة في العامودي يكبّر حول النص إن كان خطه أصغر من 17 بكسل (`_zoomToEditing` إلى ~22 بكسل)، ويرجع التكبير السابق عند الإنهاء. مقاسات الإطار من `_pageRect` و`_pw`/`_ph` لتعمل في الوضعين. في العامودي يتحرك التمرير ليبقى النص فوق لوحة المفاتيح.
- **تحديد النص في العارض:** ضغطة مطولة على كلمة ← مقبضان لتوسيع التحديد + قائمة: 4 أنواع (تظليل، خط تحت، شطب، متموج) × 5 ألوان، مسح، نسخ، ملاحظة، علامة، و**المزيد** (`_showMoreSheet`: ترجمة DeepL، اسأل ChatGPT، ترجمة Google، مشاركة؛ تفتح التطبيق أو الموقع بالنص، والعربي يُترجم للإنجليزية وغيره للعربية، والنص مقصوص إلى 1500 حرف). لمسة على **نقطة الملاحظة** (`_noteDotAt`، 24 بكسل) تفتح تعديل الملاحظة مباشرة. **التحديد يعمل والصفحة مكبرة** في الوضعين (الأفقي: `_pageRect` = `MatrixUtils.transformRect(_pagedZoom.value, _pagedRect)`). لمسة على تحديد محفوظ تختاره. يعتمد على `PdfTextExtractor` (مواضع الكلمات نسبة من الصفحة)، وإن كان في الصفحة أقل من 25 كلمة (صفحة ممسوحة أو علامة مائية فقط) يعمل `OcrService` (ara+eng، psm 3، 220dpi، صفحة واحدة في كل مرة، رسالة "جارٍ قراءة النص" بعد 0.6 ثانية) والنتيجة تُحفظ لكل صفحة فلا تتكرر. **تجهيز مسبق:** بعد توقف التمرير 0.7 ثانية (`_schedulePrefetch` من `_reportPage`) يُجهَّز نص الصفحة الحالية والتاليتين في الخلفية (`PageTextCache.prefetch`)، فيكون التحديد في الصفحات الممسوحة فوريًا غالبًا. التحديدات في `quickstudy_notes/{id}_marks.json` (منفصلة عن الملاحظات)، داخل التطبيق فقط وليست في "حفظ نسخة". التحديد داخل صفحة واحدة.

**الشريط السفلي:** زجاجي عائم بمؤشر ينزلق بالسحب، بلون الثيم الحالي (`StudyTone.purple`: المؤشر بشفافية 0.16 نهارًا / 0.26 ليلًا، والمحدد أغمق نهارًا وأفتح ليلًا بـ `Color.lerp`). عُدّل بطلب المستخدم (مقتبس من مرجعه): ارتفاع 58 وهامش جانبي 14 (أقصر وأعرض)، زجاج أشف (`surface` بشفافية 0.38 نهارًا / 0.48 ليلًا، blur 24)، مؤشر **بنفسجي** خفيف بلا توهج (`#7259DA` بشفافية 0.16 نهارًا / `#9483EE` بشفافية 0.26 ليلًا)، والمحدد بنفسجي غامق `#5B43C6` نهارًا وفاتح `#C3B8FA` ليلًا (طلب المستخدم 18 أكتوبر: من أصفر لبنفسجي). **لا تغيّر شكله بعد ذلك إلا بطلب.** في العربية يبدأ من اليمين.

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
- [x] تمرير العارض سلس بعد تحويل ألوان الورق إلى طبقة مصفوفة واحدة (اختبره المستخدم 23 أكتوبر في `--profile`).
- [x] "مشاركة نسخة" من العارض الجديد: التظليل في مكانه في ملف النسخة (اختبره المستخدم 23 أكتوبر).

### مضاف وغير مختبر (اختبره أولًا)
- [ ] **قارئ EPUB الكامل (24 أكتوبر):** غلاف مستخرج من ملف EPUB، تحديد ونسخ مع إلغاء بلمسة خارج التحديد، تظليل/تسطير/شطب/متموج متعدد الألوان، ملاحظات وعلامات محفوظة بـ CFI، بحث بمقتطفات، قائمة موحدة للانتقال/التعديل/الحذف، Google/DeepL/ChatGPT/مشاركة، ألوان الورق ومنها Obsidian `#0B0F14`، حواشٍ، واتجاه تلقائي من OPF أو يدوي مستقل. حزمة `flutter_epub_viewer` صارت نسخة محلية في `third_party/` لإضافة الشطب والمتموج والاتجاه الفوري. حُذفت واجهات القراءة النصية وحجمها والوضع الليلي القديم من PDF، وتُتجاهل مفاتيحها القديمة عند التحميل. التحقق المحلي: 29 اختبارًا ناجحًا وAPK debug ناجح. **يلزم اختبار الوظائف التفاعلية على الهاتف وكتب عربية/إنجليزية/مختلطة قبل عدها مكتملة على الجهاز.**
- [ ] **إصلاحات العارض الشاملة، المرحلة الأولى (22 أكتوبر، مواصفات المستخدم P0):** (1) **مكان النص:** أُعيد إنتاجه على الهاتف بـ adb: الصندوق يظهر عند اللمسة تمامًا ثم **يختفي تحت شريط التنسيق ولوحة المفاتيح**. السبب: `_keepEditingVisible` كان يعمل بعد 400ms ثابتة قبل اكتمال فتح اللوحة، وبارتفاع شريط مخمّن 132. الحل: يُستدعى عند تغيّر `viewInsets` فعلًا (`_lastInset` في build) وبعد كل تغيير في النص، ويقيس شريط التنسيق (`_toolbarKey`)، ويحرك العرض فقط ويرجعه عند الإنهاء إن لم يحركه المستخدم (`_editRestore`/`_editShifted`). (2) **لون المذكرة:** السبب `card.color = _inkColor` (لون واحد للنص كله). نموذج مقاطع جديد `styled_text.dart` (`RunStyle` لون/عريض/مائل/تحته خط/حجم، `StyledRun`، `Runs`، `StyledTextController` يتتبع الإدخال والحذف بالفرق بين النصين، ونمط الكتابة المؤقت `_typing` يُلغى بتحريك المؤشر). `NoteLinesEditor` بمقاطع لكل سطر (الحرف الخفي يحمل نمط السطر الفارغ، Enter يرث النمط) و`NoteLinesController.applyStyle`، و`NoteCard.runs` في `{id}_cards.json` (القديمة بلا runs تُقرأ بلونها `color`). صف تنسيق داخل المذكرة `_noteFormatRow` (B، I، U، أصغر/أكبر، على المحدد أو الكتابة التالية). التحديد داخل سطر واحد (اختيار المستخدم: اتجاه لكل سطر). (3) قوائم المرفقات (`_menuSheet`) كانت تختفي تحت أزرار أندرويد (شريط الحالة مخفي فالمساحة الآمنة صفر) ← `viewPaddingOf`، وعلى `Material` لا `DecoratedBox` (خطأ debug: أثر اللمس مخفي). اختبارات: `styled_text_test.dart` (6) و`note_lines_editor_test.dart` (5). **تحقق Claude على الهاتف بـ adb (22 أكتوبر، بإذن المستخدم):** النص يظهر فوق الشريط أثناء الكتابة، يُحفظ في مكانه، يُعاد فتحه بنفس مكانه، والعرض يرجع بعد الإنهاء؛ المذكرة: سطر أسود ثم برتقالي (الأول بقي أسود)، عريض على كلمة محددة فقط، والتنسيق باقٍ بعد الطي وإعادة الفتح؛ قائمة الصورة فوق أزرار أندرويد؛ لا أخطاء وقت التشغيل. وإصلاح رابع وُجد أثناء التحقق: `_createCard` كان يحصر x في 0.4 (بقايا فتح المذكرة على الصفحة بعرض 0.6) فتظهر الأيقونة بعيدًا عن اللمسة ← 0.97. بيانات الاختبار حُذفت. **ملاحظة:** أيقونة مذكرة على صفحة 26 من كتاب 51 اختفت أثناء استخدام المستخدم للهاتف (قبل اختبارات Claude، لقطة v1)؛ سُئل المستخدم إن حذفها. **نص الصفحة بمقاطع (22 أكتوبر، تحقق Claude على الهاتف):** `PageNote.runs` (في `{id}_notes.json`، `null` = قديمة)، والقياس والرسم معًا عبر `noteSpan` (على الورق الداكن تُعرض ألوان المقاطع الداكنة فاتحة). `_noteText` صار `StyledTextController`، و`_startEditing` يحوّل عريض/مائل/خط الصندوق القديم إلى مقطع واحد فيمكن تغيير جزء. لون اللوحة يلوّن المحدد أو الكتابة التالية (كان `note.color` للصندوق كله). تبويب النمط في `NoteToolbar`: B/I/U وA−/A+ على المحدد (`text: _noteText`). على الهاتف: "hello world" ثم "world" برتقالي عريض أكبر وحده، وبقي بعد إعادة تشغيل التطبيق. **تنبيه:** هذا كان تغيير نوع حقل، فيحتاج hot restart لا reload. العارض القديم يقرأ نفس الملف ولا يعرف `runs` (تبقى في `_raw`؛ تعديل النص فيه قد يزيح المقاطع، و`Runs.fit` يمنع الخطأ). اختبار: `page_note_runs_test.dart` (3). **P1–P3 (22 أكتوبر، تحقق Claude على الهاتف):** (أ) مرفق داخل مذكرة لم تعد موجودة كان يختفي للأبد ← `_inExistingNote` يُظهره على الصفحة، والطبقة تستمع لـ `_cards`؛ (ب) الرسم داخل مذكرة مفتوحة كان يُبقي لوحة المفاتيح ← `pick` يغلقها عند أدوات الرسم (النص والرسم باقيان، وصف التنسيق يختفي ثم يعود)؛ (ج) لمستان سريعتان على علامة المذكرة كانتا تفتحان نافذتين ← `_bookmarkBusy`؛ (د) ازدحام كتابة نص الصفحة ← لوحة القلم بالألوان فقط أثناء الكتابة (`compact = _editing != null`)؛ (هـ) **وُجد أثناء التحقق:** لوحة القلم تطول مع أداة القلم فتغطي رأس المذكرة ← السبب `bottomPad` (ارتفاع أزرار أندرويد) يُضاف لارتفاع المذكرة ولم يُطرح من حدها الأقصى (قيس بـ debugPrint: panel 257، max 490)، والمقاس يُعاد بعد كل إطار إن تغير. `flutter test`: 21 ناجحًا، و`widget_test.dart` (قالب Flutter الأصلي، يبحث عن `MyApp` غير الموجود) فاشل من قبل ولم يُلمس. **لم يُختبر على الهاتف:** الكتابة العربية (adb لا يكتب غير ASCII)، القرص بإصبعين، سحب المرفق إلى مذكرة، الشاشات الصغيرة.
- [ ] **الخطوة 3: مرفقات الصفحات (22 أكتوبر):** أداتان جديدتان في لوحة القلم (`InkTool.audio` بأيقونة `AppIcons.mic`، `InkTool.image`)، الأدوات صارت 8 (عرض الخيار 40 والاسم 10.5)، وبلا خيارات الخط والألوان. لمسة بأداة الصورة ← `FilePickerService.pickImage` (المعرض فقط) ← صورة عرضها 0.4 متمركزة على اللمسة. لمسة بأداة الصوت ← لوحة: "سجّل الآن" (`showRecordSheet` في `attachment_widgets.dart`: حزمة `record` ^7.1.2، `AudioRecorder`، aacLc أحادي، حد 10 دقائق `maxRecording`، مؤشر صوت من `onAmplitudeChanged`، الإلغاء يحذف الملف، الإذن يُطلب أول مرة و`RECORD_AUDIO` من manifest الحزمة) أو "اختر ملفًا صوتيًا" (`pickAudio`). البيانات `PdfAttachments` في `pdf_attachments.dart`: `{id}_attachments.json` والملفات منسوخة إلى `quickstudy_notes/attachments/{id}/`، وحذف الكتاب يحذفها (`FileStorageService`). العرض `_attachmentLayer`: الصوت دائرة 40 بالمايك، والصورة بحجمها مع الزوم؛ لمسة: الصورة بملء الشاشة (`showImageFullScreen`، InteractiveViewer) أو شريط التشغيل `AttachmentPlayerBar` (حزمة `just_audio` ^0.10.6: تشغيل/إيقاف، شريط يُسحب، المدة، ×، يُغلق عند النهاية)؛ ضغطة مطولة: حذف (واستبدال للصورة)، والممحاة لا تمسها؛ في وضع القلم تُسحب لتحريكها ولها مقبض حجم في الزاوية. اختبار: `test/page_attachment_test.dart`. **بعد ملاحظات المستخدم (22 أكتوبر):** الصورة تُقرص بإصبعين في أي وقت (`onScaleUpdate` بإصبعين = الحجم، وبإصبع: في وضع القلم يحرك وخارجه يمرر الصفحة `_scrollBy`). ضغطة مطولة ثم سحب (`_startAttachDrag`/`_moveAttachDrag`/`_endAttachDrag`): فوق أيقونة مذكرة مطوية (`_cardIconAt`، تكبر بحلقة) ← داخلها (`PageAttachment.noteId`)، أو إلى مكان آخر على الصفحة، وبلا سحب ← القائمة. داخل المذكرة `_noteAttachmentStrip` تحت الرأس (صور مصغرة ومقاطع بمددها، لمسة تفتح/تشغل وشريط التشغيل داخل المذكرة، ضغطة مطولة: "إرجاع إلى الصفحة"/حذف). طي المذكرة يوقف مقطعها، وحذفها يرجع مرفقاتها للصفحة. وإصلاح: `BookmarkRepository._newId` كان يتكرر في نفس الميكروثانية فيحذف إزالة علامة علامةً أخرى (كشفه الاختبار). **التالي:** الخطوة 4 (القلم الإلكتروني).
- [ ] **ألوان القراءة الستة الجديدة (22 أكتوبر، مواصفات المستخدم):** نفس الترتيب والأسماء الداخلية، والقيم: classic Warm Ivory `#F3E8D5`/`#393025`، green Sage Mist `#DFEBDD`/`#2D3B32`، blue Powder Blue `#DFEAF2`/`#2C3946`، light Soft Paper `#F2F0E9`/`#33322F`، warm Peach Cream `#F2E2D8`/`#43332E`، dark Midnight Slate `#292E32`/`#E5E8E7`. مكان واحد: `ReaderBackgroundColor.color/.ink` و`ReaderPaper` (`paperColor`/`inkColor`/`darkPaper`، والليلي `readerNightPaper`/`readerNightInk`) في `reader_settings_sheet.dart`، والعارضان يقرآن منه. العارض الجديد `_paintPaper` صار تحويلًا خطيًا دقيقًا (فاتح: screen بـ نص÷ورق ثم multiply بالورق؛ داكن: عكس ثم screen بـ ورق÷نص ثم multiply بالنص)، فأسود الصفحة = لون النص بالضبط (كان يبقى أسود نهارًا). القديم بمصفوفته كما هو. الصفحات الممسوحة بنفس التحويل.
- [ ] **علامات المذكرات (22 أكتوبر، مواصفات المستخدم):** `BookmarkKind.note` في نفس `BookmarkRepository` (`noteId` = `NoteCard.id`، `title` اختياري، `text` = بداية نص المذكرة). `saveNote` (بلا تكرار، الاسم الفارغ = بلا اسم)، `syncNote` عند طي المذكرة (النص والصفحة يتبعانها والاسم لا)، `removeNote` (العلامة فقط). حذف المذكرة يحذف علامتها. في رأس المذكرة `_noteBookmarkButton`: مفرغة / ممتلئة بلون الثيم مع تكبير خفيف (`AnimatedSwitcher`)، ولمستها `showNoteBookmarkDialog` (`note_bookmark_dialog.dart`: اسم مقترح من الاسم الحالي أو أول سطر، حفظ، إزالة إن كانت محفوظة) ثم رسالة. تلميح "احفظ هذه المذكرة..." مرة واحدة عند أول فتح لمذكرة (`ReaderSettings.noteBookmarkHintSeen`، Tooltip يدوي). في قائمة ⋯ بالمكتبة `_BookmarkTabs`: تبويبا "الصفحات" و"المذكرات" بعدديهما إن وُجد النوعان. لمسة علامة مذكرة ← `openDocument(noteId:)` ← `PdfReaderScreen.openNoteId` يفتح المذكرة بعد جاهزية العارض والمذكرات (`_revealNote`)، ورسالة إن حُذفت. اختبار: `test/note_bookmarks_test.dart`.
- [ ] **لوحة القلم الخطوة 2 (22 أكتوبر):** أداة سادسة "أشكال" (`InkTool.shape`، `AppIcons.shapes`) بأربعة أشكال (`InkShape`: خط، سهم، مستطيل، دائرة؛ النقطتان = البداية والنهاية، السحب يحرك الثانية، والممحاة على حدودها `outline`). نوع الخط `InkLine` (متصل، متقطع، منقط، سهم في النهاية) بـ `PathMetrics` في `paintStrokes`. السماكة شريط 0..1 بمنحنى تربيعي (`_inkThickness` من 0.0012 إلى 0.02 من عرض الصفحة) مع معاينة حية. الألوان: الخمسة + دائرة قوس قزح تفتح `showInkColorWheel` (`ink_color_wheel.dart`: درجة بالزاوية، تشبع بالبعد، شريط سطوع)، واللون يُحفظ في `ReaderSettings.customInkColor` (إعادة الضبط لا تمسحه). العينات بـ `_SamplePainter` بنفس رسم الصفحة. الممحاة بلا خيارات، والنص والمذكرة بالألوان فقط. خطوط أداة النص +20 (`noteFonts`، و`pdf_notes._googleFonts` صار مشتقًا منها). الحقول الجديدة في `{id}_ink.json`: `line` و`shape` (اختيارية، القديم يُقرأ متصلًا).
- [ ] **نص الصفحة يتبع ألوان اللوحة (22 أكتوبر):** اختيار لون في لوحة القلم (`_selectInkColor`) يلوّن النص الذي يُكتب الآن (`_editing.color`)، وحُذف تبويب لون النص من `NoteToolbar` (الخلفية باقية بعجلتها). مقبض حجم في الزاوية السفلية لصندوق النص: سحبه للخارج يكبّر الخط والعرض معًا (`note.size` 0.015–0.12).
- [ ] **المذكرة سطرًا سطرًا (22 أكتوبر، `note_lines_editor.dart`):** `NoteLinesEditor` = حقل لكل سطر في `CustomScrollView`، اتجاه كل سطر من أول حرف فيه والفارغ من السطر قبله ثم لغة التطبيق. Enter (أو لصق بعدة أسطر) يقسم، والحذف في أول السطر يدمج مع السابق عبر حرف خفي `​` في أول كل حقل (لوحات أندرويد لا ترسل الحذف في حقل فارغ). `SliverFillRemaining` تحت الأسطر: لمسة فيه تضيف أسطرًا حتى مكانها ومسافات حتى موضعها الأفقي. النص المحفوظ بلا الحرف الخفي. اختبار: `test/note_lines_editor_test.dart`. حلّ محل `_writeAt` و`_cardFocus`. **عجلة الألوان في شريط النص:** تبويبا اللون والخلفية في `NoteToolbar` يبدآن بدائرة قوس قزح (`showInkColorWheel`)، واللون المختار خارج القائمة يظهر بجانبها. المستخدم رفض حذف أي زوم.
- [ ] **مساحة أكبر للكتابة في المذكرة:** رأس واحد 40 (المقبض في منتصفه وسحبه كله يغيّر الارتفاع)، الارتفاع الافتراضي 70% من المساحة فوق لوحة المفاتيح. **إصلاحات بعد ملاحظات المستخدم (22 أكتوبر):** لوحة القلم لا تختفي أثناء الكتابة (إخفاؤها منع تغيير اللون) والمذكرة تقف تحت أسفلها (`_panelKey`، مقاسها من آخر إطار)؛ الرسم في المذكرة بلا حد سفلي (`_inCard` كان يقص y عند 1 = خط ثابت، والرسام يملأ المذكرة بوحدة `canvas`)؛ لون نص المذكرة `NoteCard.color` يتبع اللون المختار في اللوحة بأداة المذكرة أو النص (`_selectInkColor`).
- [ ] **الأداء (22 أكتوبر، بقياس timeline في وضع profile):** الشاشة كانت على 45 هرتز ← `MainActivity.kt` يطلب أعلى معدل بنفس الدقة (`preferredDisplayModeId`، تحققنا: 120 هرتز). الرسم كان 11.4ms متوسطًا (p90 17ms) في المكتبة، وأثقله blur الشريط السفلي ← blur من 24 إلى 12 + `RepaintBoundary` حول الشريط. **قِس في `--profile` لا debug.**
- [ ] **رسالة "نجهّز النص للنسخ" (22 أكتوبر):** `showReadingWait`/`hideReadingWait` في `viewer/widgets/reading_wait.dart` للعارض الجديد: بطاقة سفلية بألوان `ReaderChrome` + صورة البومة الحزينة `assets/owl/owl_waiting.webp` (خلفيتها بيضاء فهي داخل دائرة بيضاء) + سطران (`recognizingPage`/`recognizingHint`) + شريط تقدم بلون الثيم، بلغة التطبيق فقط (لا لغتين معًا، طلب المستخدم)، تبقى حتى يجهز النص.
- [ ] **المذكرة فوق لوحة المفاتيح (21 أكتوبر، الخطوة 1 من 4):** المذكرة المفتوحة صارت لوحة بعرض الشاشة ملتصقة بأسفل جسم العارض (فوق لوحة المفاتيح مباشرة، وفوق شريط أندرويد بدونها)، بمقبض علوي يغيّر ارتفاعها بالسحب (`_cardHeight`، 150 حتى ارتفاع العارض). الخط 16 ثابت. الرسم داخلها في مساحة بنسبة ثابتة من العرض (`_cardCanvas` = عرض × h/w) فتغيير الارتفاع لا يمط الرسم. أيقونتها المطوية على الصفحة كما هي. **الخطوات التالية المتفق عليها:** 2) عجلة ألوان (الخمسة + دائرة قوس قزح تحفظ لونًا سادسًا)، سماكة بشريط، أنواع خط (متقطع، منقط، سهم)، أشكال (خط، سهم، مستطيل، دائرة: تختار ثم تسحب)، خطوط أكثر لأداة النص. 3) أداتان في لوحة القلم: مايك (تسجيل أو ملف صوتي، أيقونة على الصفحة تُشغَّل باللمس) وصورة (من المعرض فقط، تُحرَّك ويُغيَّر حجمها). 4) القلم الإلكتروني: القلم يرسم والإصبع يمرر ويكبّر تلقائيًا، والضغط يغيّر السماكة (المستخدم بلا قلم فلا يُختبر).
- [ ] **خلفية الرئيسية برسمة المستخدم (21 أكتوبر):** الرسمة واضحة على الهاتف، الثيمات الستة (معاينة الحاسوب: بنفسجي، زمردي، وردي، أزرق، برتقالي، رمادي سليمة)، التبديل بين النهار والليل والغروب، البومة على المكتب ولا تختفي خلف البطاقة، الحركة فوق الرسمة، الداكن، الأداء.
- [ ] **الرئيسية الجديدة (20 أكتوبر):** المشهد والبومة وحركتها، المشهد حسب الوقت (صباح/ظهر/ليل)، الثيمات الستة والداكن، بطاقة متابعة القراءة (كتاب وشابتر وبلا قراءة)، الاختصاران، إحصائيات اليوم تزيد بعد قراءة وبطاقات واختبار، الأداء على الهاتف.
- [ ] **القلم بعد ملاحظات المستخدم (20 أكتوبر):** (1) خيارات "نمط الخط" كان ارتفاعها صفرًا فلا تُلمس: `crossAxisAlignment: stretch` + `HitTestBehavior.opaque`، والسماكات [0.012, 0.0075, 0.0045, 0.0025]. (2) **النص مثل القديم:** سحب النص بالإصبع يحركه (أكثر من 10 بكسل)، مقبض جانبي للعرض، دائرة دوران فوقه، والصندوق يدور (`Transform.rotate`). `NoteToolbar` في `pdf_text_tools.dart` أسفل الشاشة فوق لوحة المفاتيح: تبويبات الخط (`noteFonts` نفس قائمة القديم) / الحجم / اللون / الخلفية / B I U / المحاذاة / الشفافية / الدوران + حذف + تم. (3) **المذكرة = بطاقة** (`PdfNoteCards` في `pdf_note_cards.dart`، `{id}_cards.json`): لمسة بأداة المذكرة تنشئ بطاقة بلون الثيم (`_cardColor`) مرتبطة بالصفحة، فيها كتابة (TextField) ورسم بأدوات اللوحة (القلم/الرصاص/الممحاة، نقاط نسبة من البطاقة)، وتُطوى إلى أيقونة hugeicons (`stickyNote`) تُسحب لتحريكها ولمستها تفتحها. لمسة خارجها أو الرجوع أو زر الإغلاق تطويها.
- [ ] **عارض pdfrx: القلم (المرحلة 3، 20 أكتوبر):** زر `AppIcons.draw` (`penTool01`) في الشريط يفتح وضع القلم ولوحة تحت الشريط مقتبسة من مرجع المستخدم (`_drawPanel`): الأدوات بأسمائها (قلم `penNib` / رصاص `pencil` / ممحاة / مذكرة `stickyNote` / نص `textTool`؛ "المزيد" استُبدل بالنص بطلبه، وقلم التظليل والتراجع/الإعادة وزر تم حُذفت من اللوحة لتطابق المرجع)، ثم "نمط الخط" 4 سماكات بموجات (`_WavePainter`) و"اللون" 5 ألوان هادئة (الأول لون الثيم، والرمادي يفتح على الورق الداكن). طبقة `Listener` معتمة: إصبع يرسم، إصبعان يحركان ويكبّران (`controller.value`). الرسم في `PdfInk` (`{id}_ink.json`، الرصاص شفاف 0.7). المذكرة والنص: لمسة قصيرة تنشئ ملاحظة في مكانها (المذكرة بخلفية فاتحة من اللون) أو تفتح ملاحظة موجودة، و`_noteEditor` يعرض TextField في مكانها بنفس الخط بعد الزوم مع مقبض تحريك، لمسة خارجها أو تغيير الأداة أو الرجوع تنهيها (الفارغة تُحذف). `PdfNotes` في `pdf_notes.dart` يقرأ ويكتب نفس `{id}_notes.json` للعارض القديم (الحقول غير المعروفة تبقى)، والرسم بـ `paintNotes` (الخطوط من Google Fonts كالقديم، والنص الداكن فاتح على الورق الداكن).
- [ ] **عارض pdfrx: تحديد الكتب الممسوحة بالـ OCR (20 أكتوبر):** الضغطة المطولة نعالجها في `onGeneralTap` (نرجع true): صفحة نصية ← `textSelectionDelegate.selectWord`، وممسوحة (أقل من 25 كلمة في نص pdfrx، `ScannedPageText.isScanned`) ← كلمات `OcrService` (`ScannedPageText.words` في `pdf_scanned_text.dart`) وتحديد خاص بنا: `_ocrPage/_ocrWords/_ocrA/_ocrB`، مقبضان `_ocrHandles` (`SelectionHandle`، السحب يحول المكان بمعكوس `controller.value`)، الرسم في `_paintMarks`، نفس القائمة. التظليل يُحفظ بأرقام كلمات كالعارض القديم (`PdfMarks.add`). رسالة "جارٍ قراءة النص" بعد 0.6 ثانية، وقراءة مسبقة للصفحة الحالية والتاليتين بعد توقف التمرير 0.7 ثانية (`_schedulePrefetch`).
- [ ] **عارض pdfrx المرحلة 2 (19 أكتوبر):** تحديد النص بمقابض pdfrx (ضغطة مطولة) وقائمتنا `SelectionMenu` بدل قائمة النظام (`buildContextMenu`)، التظليل بالأنواع والألوان يُحفظ في نفس `{id}_marks.json` (`PdfMarks` في `pdf_marks.dart`: الصفحة من 0، start/end مواضع أحرف pdfrx، الرسم من `rects` النسبية في `pagePaintCallbacks`)، لمسة على تحديد محفوظ تختاره وتظهر قائمته (`onGeneralTap`)، لمسة على نقطة الملاحظة تفتح تعديلها، نسخ، ملاحظة، علامة بالنص، المزيد (ترجمة/مشاركة)، زر الرجوع يلغي التحديد. التحديد على صفحات متعددة يُحفظ تحديدًا لكل صفحة. الصفحات الممسوحة تنتظر المرحلة 4.
- [ ] **عارض PDF الجديد على pdfrx (المرحلة 1، 19 أكتوبر):** `PdfReaderScreen` في `ui/viewer/widgets/pdf_reader_screen.dart`. كل PDF يفتح فيه: تمرير عامودي سريع، زوم بالإصبعين والأزرار، شريط سحب برقم الصفحة، آخر صفحة والتقدم، اذهب إلى صفحة، العلامات، السطوع والهوامش، ألوان الورق والليلي (`pagePaintCallbacks` بـ multiply / difference+screen+multiply). قائمة ⋮ ← "العارض القديم" يغلقه بنتيجة `OpenClassicViewer(page)` و`AppNavigator.openDocument` يفتح `DocumentViewerPage` على نفس الصفحة (القلم والتحديد والـ OCR هناك حتى تُبنى).
- [ ] **المكتبة بكتابين في السطر**، ولوحات العارض بلون الورق والثيم، وزر الرجوع يغلق شريط القلم/التحديد أولًا.
- [ ] **قائمة الحساب ⋮ صارت لوحة جانبية** (`showGeneralDialog` تنزلق من جهة الزر، عرضها 88% حتى 380). لونها يُقرأ داخل البناء فيتبع تغيير المظهر والثيم (كان لون الخلفية يُثبَّت عند الفتح فتظهر بطاقات داكنة على خلفية فاتحة).
- [ ] **EPUB:** الإضافة من "إضافة كتاب" ومن "إضافة شابتر"، الفتح، السحب والأسهم، الفهرس، حجم الخط، الفتح على آخر مكان، النسبة في المكتبة، كتاب عربي (RTL). البناء نجح ولا أخطاء عند التشغيل.
- [ ] **نموذج إضافة كتاب:** اختيار الملف، تعديل الاسم، اختيار تصنيف، "+ تصنيف جديد" وظهوره في تبويبات المكتبة وفي ⋯، بقاؤه بعد إعادة التشغيل، رسالة الكتاب المكرر.
- [ ] **شريط الحالة المخفي** داخل التطبيق ورجوع الإخفاء بعد السحب.
- [ ] **الثيمات الستة:** اختبر المستخدم الزمردي (الواجهة والشريط تبعته)، الباقي والليلي غير مختبر.
- [ ] **لوحة الرئيسية (19 أكتوبر):** الأرقام صحيحة، وقت القراءة يزيد بعد فتح كتاب والرجوع (أكثر من 5 ثوانٍ)، أعمدة الأسبوع، الأيام المتتالية، الوضع الليلي. المذاكرة: "المواد" بدل التحية وبلا صورة. قائمة ⋮ بلا "كل الإعدادات".
- [ ] **المكتبة الجديدة (بنفسجي، 19 أكتوبر):** البطاقة العلوية وتقليبها، التصنيفات واختيارها من ⋯، الشبكة، البحث، علامات كل كتاب من ⋯، الحذف، الوضع الليلي، ترقية v5 بلا فقد الكتب. **قائمة الحساب ⋮:** في التبويبات الثلاثة، تغيير الاسم وظهوره في تحية المذاكرة، المظهر واللغة منها.
- [ ] **المذاكرة الجديدة (بنفسجي):** صفحتا المادة والشابتر بنفس الثيم نهارًا وليلًا (بلا خلفية الورق)، التحية وصورة الحساب، بطاقة الهدف بالأرقام الحقيقية، صفوف المواد بالأيقونات الملونة والنسبة، "مادة جديدة"، الوضع الليلي.
- [ ] **بطاقات المواد:** إنشاء مادة بأيقونة وصورة غلاف، تغيير الصورة وإزالتها، المادة بلا صورة (الاسم على مساحة رمادية)، الشارات، الغلاف في رأس صفحة المادة، ترقية v4 بدون فقد المواد (تحققتُ: المادتان ظهرتا).
- [ ] **طابع الورق:** المذاكرة (نهار/ليل)، المكتبة كما كانت تمامًا بعد نقل الكود، صفحتا المادة والشابتر والإعدادات بالخلفية والذهبي وأميري، الضغطة المطولة على الدفتر، حالة لا مواد.
- [ ] **Study الجديدة (ب):** إنشاء مادة بلون، تعديلها وحذفها (مع ملفاتها)، إضافة شابتر برفع PDF، التسمية والحذف وإعادة الترتيب، صفوف موحدة بحالة القراءة، صفحة الشابتر وفتح القراءة. **الفصل:** كتب "تعلم الالة" الستة اختفت من المكتبة والرئيسية، ورفع ملف في المذاكرة لا يظهر في المكتبة والعكس. صفحة المادة تعرض الشباتر (مختبر بعد إصلاح الزر).
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
- [x] ب: Study = مواد مثل المجلدات، يضيف المستخدم الشباتر (ملفات PDF) داخل مادتها. جداول `subjects` و`chapters` في SQLite (نسخة 2 مع ترحيل). صفحة الشابتر: قراءة، محادثة، بطاقات، اختبار (البطاقات والاختبار تجريبية حتى المرحلة 4). (مضاف وغير مختبر)
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
| صفحة المادة فارغة إلا زر "إضافة شابتر" في المنتصف، والشباتر محفوظة | `ConstrainedContent` (فيه `Center`) داخل `bottomNavigationBar` تمدد ليملأ الشاشة فغطّى القائمة | `Center(heightFactor: 1)` في الأشرطة السفلية. لا تضع `ConstrainedContent` في `bottomNavigationBar` |
| شاشة حمراء في الرئيسية بعد hot restart، والخطأ الظاهر `Null check operator` في الـ ListView | الأول: `BoxConstraints has a negative minimum width` لأن عرض الشاشة صفر في أول إطار فصار عرض بطاقة الرقم سالبًا | `.clamp(0.0, double.infinity)` لكل عرض محسوب من `maxWidth` |
| قائمة الحساب: بطاقات داكنة فوق خلفية فاتحة بعد اختيار "داكن" | `backgroundColor: StudyTone.background` مُرِّر لـ `showModalBottomSheet` فثُبّت عند الفتح، والمحتوى أعاد البناء بالألوان الجديدة | اقرأ ألوان أي نافذة/لوحة داخل `build` لا في معاملات `show...` |
| `pdfrx 2.4.5`: `blockSize cannot be accessed on PdfFileCache?` عند البناء | الإصدار لا يتوافق مع Dart الأحدث | pdfrx ^2.6.6، ويحتاج archive 4.x فحُذفت docx_to_text وxml وimage (غير مستخدمة) |
| عارض pdfrx: التحديد لا يُظهر أي قائمة، والسجل: `A Stack requires bounded constraints` ثم `RenderBox was not laid out` | `buildContextMenu` في pdfrx يضع القائمة بلا قيود حجم، وقائمتنا كانت Stack داخل LayoutBuilder | `buildContextMenu: (_, _) => null` وقائمتنا في طبقة العارض (`Positioned.fill` + `_overlayMenu`) بمواضع `getSelectedTextRanges` |
| `There is not enough space on the disk` في Gradle، والهاتف يبقى على النسخة القديمة فيبدو التعديل "لم يعمل" | القرص C ممتلئ (البناء يحتاج 2–3GB) | افحص نهاية سجل `flutter run` قبل الحكم على أي تعديل. المحاكيات نُقلت إلى D |
| التطبيق بطيء في التمرير | الشاشة على 45 هرتز (أندرويد يخفضها) + blur الشريط 24 | `MainActivity` يطلب أعلى معدل، blur 12. القياس في `--profile` بـ `getVMTimeline` (stream Embedder، حدث `GPURasterizer::Draw`) |
| صندوق النص الجديد لا يظهر حيث لمس المستخدم | `clamp(0.01, 0.99 - w)` كان يزيح الصندوق كله (عرضه 0.55) قرب الحافة فيبتعد أوله عن اللمسة، واتجاه أول حرف قد يخالف لغة التطبيق | `_boxFrom`: أول الصندوق عند اللمسة دائمًا ويضيق بدل أن يُزاح، و`_followDirection` يقلبه حول اللمسة (`_editAnchor`) مع أول حرف حتى يحركه المستخدم |
| النص الذي يُكتب على الصفحة يختفي تحت شريط التنسيق ولوحة المفاتيح | `_keepEditingVisible` بعد 400ms ثابتة يسبق اكتمال فتح اللوحة، وارتفاع الشريط مخمّن | يُستدعى عند تغيّر `viewInsets` فعلًا وبعد كل تغيير نص، ويقيس الشريط (`_toolbarKey`) |
| تغيير لون المذكرة أو نص الصفحة يلوّن ما كُتب قبل | لون واحد للنص كله (`card.color`/`note.color`) | مقاطع `styled_text.dart` (`RunStyle`/`Runs`/`StyledTextController`) |
| قائمة تختفي تحت أزرار أندرويد | شريط الحالة مخفي فالمساحة الآمنة صفر | `MediaQuery.viewPaddingOf(context).bottom` |
| مقابض صندوق النص (الحجم، العرض، الدوران) ومقبض حجم الصورة "تشتغل ولا تشتغل" | فلاتر لا يقبل اللمس خارج حدود الويدجت، والمقابض كانت خارج الحدود (-16، -9، -38) فيستجيب جزؤها الداخلي فقط | هامش شفاف 44 حول الصندوق (`m`) والمقابض داخله، ومقبض الصورة داخل زاويتها. الهامش بلا محتوى فلا يحجب اللمس |
| أيقونة المذكرة (والمرفق في وضع القلم) لا تنتقل لصفحة أخرى بالسحب | x/y محصوران 0..0.97 في صفحتها ورقم الصفحة ثابت | `_dragDoc`/`_followDrag`: المكان في المستند كله، والصفحة التي تحتويه أو الأقرب في الفراغ؛ `NoteCard.page` صار متغيرًا وعلامتها تتبع الصفحة |
| لوحة القلم تغطي رأس المذكرة | `bottomPad` يُضاف للارتفاع ولا يُطرح من الحد | `max = area - panelBottom - bottomPad` |
| تمرير العارض يتقطع حتى في `--profile` (الرسم 16.9ms، الواجهة 2.4ms فقط) | ألوان الورق بطبقات screen/multiply/difference فوق كل صفحة، وImpeller ينسخ الإطار كله لكل طبقة (2–3 لكل صفحة ظاهرة) | طبقة واحدة `saveLayer` بمصفوفة لونية: تُفتح في `pageBackgroundPaintCallbacks` (`_beginPaper`) قبل صورة الصفحة وتُغلق في `_paintPaper`. صار 6.8ms. لا تستخدم أوضاع blend المتقدمة في الرسم المتكرر |
| تحديد النص في صفحة ممسوحة بعيدة ينتظر 15–40 ثانية، وفي الخلفية 3 ثوانٍ فقط | Tesseract في الإضافة مبني بـ OpenMP وخيوطه تنتظر بالدوران، فينهار حين يرسم التطبيق (رسالة الانتظار المتحركة، التمرير). أولوية الخيط وحدها لم تكفِ (40 ثانية) | `OMP_THREAD_LIMIT=1` قبل تحميل libtesseract + قناة خاصة. صار ~3 ثوانٍ في كل الحالات. وأيضًا: PGM رمادي بدل PNG (0.6← 0.03 ث)، `tessedit_do_invert=0`، الضغطة المطولة تتقدم الطابور وتُلغى القراءة المسبقة لصفحات تركها القارئ (`keepOnly`) |
| قائمة التحديد مقطوعة تحت أزرار أندرويد عند تحديد صفحة كاملة، ومقبض فوقها | الحد السفلي `maxHeight - h - 8` بلا ارتفاع أزرار أندرويد، وارتفاع القائمة ثابت 206 وهي ~220، وطبقة `_ocrHandles` فوق `_overlayMenu` | `bottomLimit` يطرح `viewPaddingOf(context).bottom`، والارتفاع يُقاس بعد الرسم (`_MeasureHeight` ← `_menuHeight`)، والقائمة فوق المقابض في الـ Stack |
| تمرير العارض 15.6ms للإطار رغم إصلاح الطبقات (كتاب HD، ورق داكن) | طبقة saveLayer بالمصفوفة لكل صفحة ظاهرة ما زالت تضاعف عمل GPU (قياس بمفاتيح مؤقتة: بلا الطبقة 2ms) | المرشح داخل رسم الصورة نفسها (`pdfrxPageColorFilter` في نسخة pdfrx المحلية). صار 2.2ms عامودي، 2.8ms أفقي |
| الأفقي: الصفحة تقف بين صفحتين، ثم "تعلق" بعد إصلاح بالانتظار | InteractiveViewer يستدعي onInteractionEnd **قبل** أن يبدأ انزلاق الإفلات، فالانزلاق يلغي goTo | الحركة في `scheduleMicrotask` بعد بدء الانزلاق، وgoTo يوقفه. لا تنتظر ولا تُلغِ الانزلاق بالاحتكاك |
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

**التخطيط والأسئلة:**
- https://www.skills.sh/mattpocock/skills/grill-me (أُضيفت 19 أكتوبر): قبل أي عمل كبير اسأل المستخدم أسئلة محددة واحدًا تلو الآخر عن كل فرع في الخطة حتى يتضح القرار، مع توصيتك لكل سؤال، ولا تبدأ قبل الاتفاق. ما يمكن معرفته من الكود ابحث عنه بنفسك ولا تسأل عنه.

**الخلاصة العملية من هذه المهارات:**
- ظلال ناعمة جدًا وحدود رفيعة، ومساحات بيضاء كافية.
- لا إيموجي، ولا عبارات تسويقية مثل "Seamless" أو "Elevate". نصوص قصيرة ومحددة تقول ما يحدث.
- عنصر مميز واحد في كل شاشة (الأصفر)، والباقي هادئ.
- كل حالة لها شكل: تحميل، فارغ، خطأ مع "حاول مرة أخرى".
- أهداف لمس لا تقل عن 44–48 بكسل، ونصوص بديلة (Semantics) للأزرار.

---

## 10. سجل التحديثات

- **24 أكتوبر 2026:** تنفيذ متطلبات EPUB المذكورة أعلاه، تخزين التعليقات بـ CFI، استخراج الأغلفة محليًا، إزالة خيارات القراءة القديمة، واعتماد Obsidian. `flutter test`: 29 ناجحًا؛ `flutter build apk --debug --no-pub`: ناجح.

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
- **18 أكتوبر 2026:**
  - زر "المزيد" في قائمة التحديد (DeepL / ChatGPT / ترجمة Google / مشاركة) وتعديل الملاحظة بلمس نقطتها: مختبران.
  - إعادة التصميم ب: Study بالمواد والشباتر (`SubjectRepository`، قاعدة البيانات نسخة 2، `SubjectScreen`، `ChapterScreen`)، وحذف المجموعات التجريبية من صفحة Study.
  - فصل ملفات المكتبة عن المذاكرة (قاعدة البيانات v3، `origin`)، حذف الشابتر يحذف ملفه، صفوف شباتر موحدة.
  - ملاحظة: في `lib/` ملفات قديمة غير مستخدمة (`lib/theme`، `lib/home`، `lib/*_page.dart`...) فيها أخطاء. شغّل التحليل على المجلدات الفعلية: `flutter analyze lib/main.dart lib/config lib/data lib/domain lib/routing lib/ui lib/utils`.
  - طابع الورق المشترك (`paper.dart`) للمذاكرة (دفاتر على رفوف) والمادة والشابتر والإعدادات.
  - المذاكرة كبطاقات مقتبسة من مرجع "Student Dashboard": غلاف صورة اختياري + أيقونة + شارات، قاعدة البيانات v4.
  - إعادة بناء المذاكرة من مرجع بنفسجي (تحية، صورة حساب، بطاقة هدف، صفوف بأيقونات ملونة). التالي بعد الأساسيات: تسجيل الدخول بقوقل والترحيب بالاسم وجعل التطبيق ديناميكيًا.
- **19 أكتوبر 2026:**
  - المكتبة بتصميم بنفسجي جديد من مرجع المستخدم (بطاقة آخر ما قرأت، تصنيفات، شبكة، بحث، علامات كل كتاب)، قاعدة البيانات v5 (`lectures.category`).
  - قائمة الحساب ⋮ في كل التبويبات (صورة + اسم + مظهر + لغة + كل الإعدادات)، واسم المستخدم في تحية المذاكرة.
  - البحث عن كتب مجانية وتنزيلها من الإنترنت (Internet Archive وOpen Library) والتنزيل من رابط، وخط Almarai للتطبيق.
  - الرئيسية صارت لوحة أرقام (حذف إدارة الملفات ورفع الصور)، تسجيل وقت القراءة (`ReadingStatsRepository`)، المذاكرة بعنوان "المواد" بلا صورة، وحذف "كل الإعدادات".
  - إلغاء البحث والتنزيل من الإنترنت (حذف `http` وكوده)، ستة ثيمات (`AppAccent`)، إخفاء شريط حالة أندرويد، نموذج إضافة كتاب بتصنيفات يضيفها المستخدم، ودعم EPUB (`flutter_epub_viewer`، `EpubReaderScreen`).
  - المكتبة: كتابان في السطر (`columns` من عرض/200، `childAspectRatio` 0.56) وخط وزر ⋯ أكبر.
  - العارض: `ReaderChrome(paper:)` فلوحة الإعدادات وشريط القلم بدرجة فاتحة من لون الورق، والشرائح والمفاتيح والاختيار بلون الثيم (`StudyTone.tone`) بدل الأصفر والأزرق. زر الرجوع في الهاتف (`PopScope`) يُنهي الكتابة أو يلغي التحديد قبل الخروج.
  - أزرار قائمة التحديد بأيقونات hugeicons (`AppIcons.copy` / `stickyNote` / `bookmarkAdd` / `trash` / `moreHorizontal`)، ولون الورق المختار في الإعدادات بإطار من درجة أعمق من لونه نفسه (`_Swatch._deep`) لا لون الثيم.
  - كل ألوان واجهة القراءة مشتقة من لون الورق (`ReaderChrome._base`: اللوحة = الورق أفتح 15% نهارًا و7% ليلًا لتطابق الصفحة، طلب المستخدم؛ والليلي كحلي)، والتحديد ومقابضه بلون الثيم (`ReaderChrome.selection`، `Theme.textSelectionTheme` حول `PdfViewer`، `MarksPainter.selectionColor`، `SelectionHandle(color:)`).
  - قائمة التحديد بتصميم جديد (الملفين): لون اللوحة من الورق والاختيار بلون الثيم (`SelectionMenu(surface:, accent:)`)، دوائر ألوان، أزرار بأيقونة واسم صغير. حذف أزرار + و − من العارض الجديد (الزوم بالإصبعين). لوحة إعدادات القراءة `useSafeArea` و`viewPaddingOf` فلا ينقطع أسفلها خلف شريط أندرويد.
  - **عارض pdfrx: الرسم الحر** (قلم، قلم تظليل، ممحاة، تراجع/إعادة، `pdf_ink.dart`).
  - رقم الصفحة في شريط العارض الجديد صار خانة رقم مباشرة (`_PageJump`: لمسة ← TextField بلوحة أرقام، أرقام صحيحة فقط `digitsOnly`، "اذهب" تنقل، لمسة خارجها تلغي) بدل نافذة. وخانة الصفحة في العارض القديم ترفض الفاصلة العشرية.
  - **عارض pdfrx: التحديد والنسخ والتظليل في الكتب الممسوحة بالـ OCR** (`pdf_scanned_text.dart`).
  - **عرض النص بحجم خط (المرحلة 5) أُلغي بطلب المستخدم 20 أكتوبر:** بُني (عرض فقرات الصفحة + OCR للممسوح) ثم حُذف لأن الكتب الممسوحة تحتاج OCR لكل صفحة وهو بطيء. تكبير النص = زوم الصفحة. لا تقترحه مرة أخرى إلا بطلب. بقي إصلاح خطأ قائمة التحديد أثناء فتح الكتاب (`controller.layout` قبل جاهزيته).
  - **عارض pdfrx المرحلة 2:** التحديد والتظليل والقائمة وزر المزيد (`pdf_marks.dart`).
  - **عارض pdfrx (المرحلة 1 من 6):** pdfrx ^2.6.6 (2.4.5 لا يُترجم مع Dart 3.13). لتثبيته: حذف الحزم غير المستخدمة `docx_to_text` و`xml` و`image`، و`archive` صار ^4.5.2. المراحل المتفق عليها: 1) القراءة (تم) 2) التحديد والتظليل وزر المزيد 3) القلم 4) OCR 5) (أُلغي: عرض النص بحجم خط) 6) الأفقي وحفظ نسخة، ثم حذف العارض القديم. الزوم مطلوب في كل الأوضاع بما فيها الكتابة.
  - كلمة "الافتراضي" تحت البنفسجي في صف لون التطبيق (`s.defaultLabel`؛ البنفسجي هو الافتراضي أصلًا في `SettingsRepository`).
  - قائمة الحساب ⋮ لوحة جانبية بدل السفلية مع إصلاح ألوانها عند تغيير المظهر، وإضافة مهارة grill-me للقسم 11.
- **20 أكتوبر 2026:** الرئيسية الجديدة من مرجع المستخدم: مشهد بومة حي مرسوم بالكود بألوان الثيم ويتبدل بالوقت، متابعة القراءة، اختصارا المذاكرة والمكتبة، إحصائيات اليوم (عدادات يومية جديدة للصفحات والبطاقات والأسئلة).
- **21 أكتوبر 2026:** إلغاء دمج صور بومة Figma بطلب المستخدم (أعجبته حركات البومة المرسومة أكثر)، ثم جُرّبت بومة مرسومة بتفاصيل Figma ورفضها المستخدم (مبالغة في التفاصيل) فرجعت البومة البسيطة كما كانت. ثم حياة الخلفية: ألوان تتبع الساعة وسماء حية هادئة ونباتات ومصباح. ثم استُبدلت الخلفية المرسومة بالكود برسمة غرفة من المستخدم (نهار/ليل) تُلوَّن بالثيم بشيدر، وإصلاح اتجاه المصباح قبلها. Rive نوقش ورُفض: تصدير .riv يحتاج اشتراكًا مدفوعًا.
  - المذكرة المفتوحة فوق لوحة المفاتيح بمقبض تمديد (الخطوة 1 من خطة المذكرة والقلم، تفاصيلها في القسم 6). نوقشت القراءة بالصوت والكتابة بالصوت ولم يُختر أي منهما؛ المستخدم فضّل إرفاق مقاطع صوتية.
- **22 أكتوبر 2026:** امتلاء القرص C أفشل البناء مرتين: `flutter clean`، ثم نقل المحاكيات (`Sdk\system-images` و`.android\avd`، 17.8GB) إلى `D:\Android` بـ junction في مكانها القديم (بموافقة المستخدم؛ D قرص HDD، وكاش Gradle بقي على C لأنه يبطئ البناء على HDD). إصلاح الأداء (120 هرتز + blur أخف) ورسالة انتظار النص بالبومة.
  - المذكرة فوق الكيبورد اختبرها المستخدم (ظهرت فوق لوحة المفاتيح) وطلب مساحة كتابة أكبر. ثم الخطوة 2: الأشكال وأنواع الخط وشريط السماكة وعجلة الألوان وخطوط أكثر.
  - المذكرة سطرًا سطرًا باتجاه كل سطر، قاعدة "أول حرف قوي" للتطبيق كله، نص الصفحة يتبع ألوان اللوحة مع مقبض حجم، وموضع صندوق النص عند اللمسة. ثم علامات المذكرات (أيقونة في المذكرة + تبويبا الصفحات والمذكرات في قائمة الكتاب).
  - **أداء تمرير العارض (23 أكتوبر، قياس profile على الهاتف):** الرسم 16.9ms ← 6.8ms لكل إطار (84% من الإطارات تحت 8.3ms على 120 هرتز) بتحويل ألوان الورق إلى طبقة مصفوفة لونية واحدة (القسم 8). الألوان كما هي. ما بقي: ظل الصفحات (blur 10) قد يكون التالي إن لزم.
  - **سرعة OCR (23 أكتوبر، قياس على الهاتف):** الصفحة الكاملة الممسوحة ~3 ثوانٍ مع رسالة الانتظار وأثناء التمرير (كانت 15–40)، والنص المستخرج مطابق للقديم (صفحة 51 من الليالي البيضاء، 183 كلمة). التفاصيل في القسم 8. مضاف وغير مختبر من المستخدم.
  - **تصميم التحديد الجديد (23 أكتوبر، من صور المستخدم، العارض الجديد):** `SelectionMenu` بطاقة 30 بذيل يشير إلى النص (`tailX`/`tailUp` من `_placeMenu`، يختفي إن أُزيحت القائمة لحافة الشاشة)، الأنواع في شريط مستدير والمختار رقاقة بلون التحديد، دوائر ألوان بحلقة بيضاء ولمعة والمختار بحلقة من لونه، الإجراءات في دوائر خفيفة بفواصل. نافذة ملاحظة التحديد `_InputDialog(chrome:)`: أيقونة | "أضف ملاحظة"، خانة بإطار بلون الثيم، "إلغاء" و"حفظ الملاحظة" (الشكل من المرجع، الألوان من `ReaderChrome`). التظليل حبوب مستديرة لكل سطر (`MarksPainter._pill`)، وشارة الملاحظة دائرة بدرجة أعمق من لون التحديد فيها ورقة بأسطر (`_noteBadge`، نفس مكان النقطة القديمة)، والتظليل المحفوظ المختار بإطار (`focus`) لا بطبقة فوقه. تحقق Claude على الهاتف؛ لم يختبره المستخدم.
  - **رسالة العلامة بالبومة (23 أكتوبر، طلب المستخدم):** "تمت الإضافة إلى العلامات بنجاح" / "Added to bookmarks successfully" (`bookmarkAdded`) بصورة البومة التي تؤدي التحية `assets/owl/owl_salute.webp` بدل أيقونة المعلومة: `showAppMessage(leadingImage: owlSaluteImage)` يعرض `_OwlMessage` (بطاقة بتدرج من لون الثيم: درجة فاتحة منه ← درجة أفتح من لون مجاور له بإزاحة 35 درجة (البنفسجي ← وردي)، الحد والظل والنص من لون الثيم، زوايا 28، ظل بنفسجي ناعم، البومة في دائرة بحلقة بيضاء، نص داكن عريض). في علامة الصفحة وعلامة النص في العارض الجديد. "حُفظت المذكرة في العلامات" لم تتغير. تحقق Claude على الهاتف.
  - **العارض القديم حُذف (23 أكتوبر، طلب المستخدم: "استكمل العارض وتحذف النسخة السابقة"):** حُذف `document_viewer_screen.dart` (~3800 سطر) و`OpenClassicViewer` وزر "العارض القديم" ونص `classicViewer`. قرارات المستخدم: **عامودي فقط** (حُذف مفتاح القراءة الأفقية `verticalReading` وحقل `ReaderSettings.vertical` و`showLayout`)، **حفظ نسخة ومشاركة نسخة** في قائمة ⋮ (`pdf_export.dart`: `exportAnnotatedPdf` يرسم لكل صفحة فيها شيء طبقة PNG بنفس رسامي الشاشة `MarksPainter`/`paintStrokes`/`paintNotes` ويضعها على الصفحة كلها بـ syncfusion؛ المذكرات والمرفقات لا تدخل؛ رسالة "نجهّز النسخة...")، والصور لا تحتاج عارضًا (لا يمكن رفعها). تحقق Claude على الهاتف: القائمة، "مشاركة نسخة" تفتح نافذة المشاركة بملف PDF (5.77MB، الليالي البيضاء، ~10 ثوانٍ)، والملف فيه 6 طبقات = الصفحات الست التي عليها تحديد أو نص، ويفتح في Acrobat. **المستخدم تحقق (23 أكتوبر):** التظليل في مكانه الصحيح في النسخة. `flutter test`: 21 ناجحًا (و`widget_test.dart` فاشل من قبل).
  - **القراءة الأفقية صفحة بصفحة في العارض الجديد (23 أكتوبر، طلب المستخدم بعد حذف القديم):** مفتاح "قراءة أفقية (صفحة بصفحة)" في إعدادات القراءة لكل الكتب (`ReaderSettings.vertical` رجع). `layoutPages` = `_layoutLtr`/`_layoutRtl` (الصفحات بارتفاع واحد جنبًا إلى جنب، والكتاب العربي = في اسمه حرف عربي/عبري `_rtlBook` يبدأ من اليمين)، `sizeDelegateProvider: _horizontalSizing` (يفتح على صفحة كاملة `_fitPageZoom`)، `calculateCurrentPageNumber: _pageAtCenter` (تخمين pdfrx يعكس رقم الصفحة في العربي: 117 ظهرت 340)، `interactionEndFrictionCoefficient: _noGlide` (1e-40، الانزلاق بعد الإفلات كان يغلب الاستقرار فتقف بين صفحتين) و`_onInteractionStart/End`: إفلات أسرع من 300 أو سحب أكثر من خُمس الصفحة يقلب، والمكبرة لا تقلب إلا بتجاوز حافتها بخُمس الشاشة، والاستقرار `_fitPage` بعد 120ms. التبديل والكتاب مفتوح يرجع لنفس الصفحة (`_onReaderChanged`). شريط رقم الصفحة في الأسفل فوق أزرار أندرويد. تحقق Claude على الهاتف (الجريمة والعقاب): يفتح على 117 كاملة، السحب لليمين ← 118، لليسار ← 117، سحب قصير يرجع. **لم يُختبر:** الزوم والقلم والتحديد والمذكرات في الأفقي، وكتاب إنجليزي.
  - **أداء العارض والزوم (23 أكتوبر، طلب المستخدم "صلح الأداء تمامًا وجرّب كل الخاصيات وصلح التكبير والتصغير"، قياس profile على الهاتف):** ألوان الورق صارت مرشحًا داخل رسم صور الصفحات (`pdfrxPageColorFilter`، نسخة pdfrx المحلية): العامودي 15.6 ← 2.2ms، والأفقي 2.8ms (الإطارات البطيئة الباقية = رفع الصورة الحادة أول مرة لكل صفحة). الاستقرار في الأفقي بـ microtask بلا انتظار، والانزلاق الطبيعي رجع، والمكبرة تقف عند حافة الصفحة بتوقع نهاية الانزلاق (`_glideDistance`)، والقرص قرب حجم الصفحة يرجعها كاملة بلا تقليب. العامودي: التصغير حتى ثلث عرض الشاشة (`_verticalSizing`: minScale = coverScale/3، عدة صفحات معًا في الوسط، 1.9ms). تحقق Claude على الهاتف: تمرير عامودي، تقليب أفقي، زوم في الوضعين (بخطاف مؤقت لأن adb لا يقرص بإصبعين: SELinux يمنع sendevent)، تحديد وقلم في الأفقي (بيانات الاختبار أُرجعت من نسخة احتياطية). **لم يُختبر:** القرص بالأصابع نفسها.
  - **الوضع الليلي الجديد ولوحة إعدادات القراءة (23 أكتوبر، مواصفات المستخدم + مرجع):** `NightBackground` (night `#1E222D`، slate `#242D3A`، charcoal `#292B30`، mocha `#342D2B`، olive `#293530`، plum `#30283A`) في `ReaderSettings.nightBackground` (يُحفظ)، ونصها `#E3DEDC` (تباين فوق 7:1، اختبار `reader_settings_test.dart`). في الليلي تظهر هذه الستة بدل ألوان النهار (كانت معطلة). `ReaderChrome(night:)`: لوحة `#252B39`، بطاقة `#303747`، حد `#42495B`، نص `#F0EDF4`/`#A6A8B9`؛ والتمييز بلون الثيم (اختيار المستخدم). اللوحة بتصميم المرجع في الوضعين (اختيار المستخدم): رأس بالعنوان والوصف والبومة الليلية `assets/owl/owl_night.webp` (WebP شفاف 1254px، يُفك بحجم عرضه `cacheWidth`، لا يلتقط اللمس) في الزاوية يختفي ثلثها السفلي خلف بطاقة السطوع (طلب المستخدم بصورة)، ثم بطاقات بأيقونات hugeicons ووصف، وإعادة الضبط بأيقونة. عينات النهار باختيارها بلون أعمق منها (تفضيل 19 أكتوبر)، والليل بلون الثيم. **التصغير للبحث عن المذكرات (طلب المستخدم):** حتى سُدس العرض عامودي، وخُمس الصفحة أفقي (`_updateZoomLimits`)، والأفقي المصغر بلا استقرار على صفحة، وبلا ظل للصفحات والصفحات مصغرة (`_overview`). **أداء:** `ReadingProgressRepository.record` صار يُشعر مرة بعد 400ms من توقف التغيير (كان يعيد بناء المكتبة والرئيسية المخفيتين عدة مرات في الثانية). القياس: المصغر 3.3ms، العادي 2.2–4.7ms (الأعلى = صفحات تُرسم أول مرة). تحقق Claude على الهاتف: اللوحة ليلًا والبومة، اختيار برقوقي يلوّن الصفحة فورًا وإرجاع أردوازي، بقاء الاختيار بعد إعادة التشغيل. **لم يُختبر:** الشاشات الصغيرة والكبيرة، والقرص الحقيقي.
  - **التالي:** يختبر المستخدم علامات المذكرات والخطوة 2، ثم الخطوة 3 (أداتا مايك وصورة) ثم 4 (القلم الإلكتروني). يختبر أيضًا EPUB ونموذج الإضافة، ثم البحث عن الكتب في حقل الاسم (بعد حسم التصنيفات والبيانات المحفوظة)، ثم بقية ميزات EPUB (تظليل، ملاحظات، علامات، بحث داخل الكتاب، إعدادات النص). لاحقًا: ج (محادثة لكل شابتر).
