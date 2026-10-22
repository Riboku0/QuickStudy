import 'package:flutter/widgets.dart';

// كل نصوص الواجهة بالعربية والإنجليزية.
// الاستخدام: final s = AppStrings.of(context);  ثم  Text(s.home)
//
// لإضافة نص جديد: أضفه في AppStrings ثم في _En و _Ar
// (المحرر سيعطيك خطأ إذا نسيت إحدى اللغتين).
abstract class AppStrings {
  const AppStrings();

  static AppStrings of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode;
    return code == 'ar' ? const _Ar() : const _En();
  }
  bool get isArabic;

  // ---- عام ----
  String get appName => 'QuickStudy';
  String get home;
  String get study;
  String get library;
  String get settings;
  String get open;
  String get delete;
  String get cancel;
  String get tryAgain;
  String get today;
  String get yesterday;
  String get unknownDate;
  String get pdf => 'PDF';
  String get images;
  String files(int n);
  String cards(int n);
  String questions(int n);
  List<String> get monthsShort;
  List<String> get monthsLong;
  List<String> get weekdays; // يبدأ من الإثنين

  // ---- رسائل الملفات ----
  String get fileDeleted;
  String get fileNotDeleted;
  String get fileMissing;
  String filesAdded(int n);
  String get noNewFiles;
  String skipped(int n);
  String get filesNotSaved;
  String get deleteFileTitle;
  String deleteFileBody(String name);
  String get deleteFile;
  String get missing;

  // ---- Home ----
  String get goodMorning;
  String get goodAfternoon;
  String get goodEvening;
  String get uploadFiles;
  String get searchFiles;
  String get overview;
  String get continueReading;
  String get pdfFiles;
  String pageOf(int page, int count);
  String openedOn(String day);
  String get notStarted;
  String get startReading;
  String get resumeReading;
  String get noPdfsTitle;
  String get noPdfsBody;
  String get addPdf;

  // ---- إعدادات القراءة ----
  String get readerSettings;
  String get brightness;
  String get margins;
  String get marginNone;
  String get marginStandard;
  String get marginWide;
  String get backgroundColor;
  String get colorsDayOnly;
  List<String> get readerBackgrounds; // بترتيب ReaderBackground
  String get verticalReading;
  String get nightMode;
  String get resetSettings;

  // ---- تحديد النص ----
  List<String> get markStyles; // بترتيب MarkStyle
  List<String> get markColors; // بترتيب markColors
  String get copyText;
  String get markNote;
  String get markNoteTitle;
  String get saveNote;
  String get removeMark;
  String get copied;
  String get noSelectableText;
  String get recognizingPage;
  String get recognizingHint;

  // ---- المزيد: الترجمة ----
  String get more;
  String get translateDeepL;
  String get askChatGpt;
  String get translateGoogle;
  String chatGptPrompt(String text);
  String get openAppFailed;

  // ---- العلامات المرجعية ----
  String get addBookmark;
  String get removeBookmark;
  String get bookmarkAdded;
  String get bookmarkRemoved;
  String get bookmarkAction;
  String get bookmarksTitle;
  String get bookmarksEmpty;
  String get shelvesTitle;
  String pageNumber(int n);
  String get recentFiles;
  String get seeAll;
  String get comingSoon;
  String get addLectureFiles;
  String get addLectureHint;
  String get addingFiles;
  String get uploadNewFiles;
  String get cardsAndQuizzes;
  String get todayLabel;
  String get lastAdded;
  String get noFilesYet;

  // ---- Library ----
  String get yourArchive;
  String get libraryEmptyTitle;
  String get libraryEmptyBody;
  String get sortFiles;
  String get newestFirst;
  String get oldestFirst;
  String get nameAZ;
  String usedBy(int n);
  String get searchYourFiles;
  String get clearSearch;
  String get all;
  String get fileOptions;
  String get noMatchTitle;
  String get noMatchBody;
  String get clearFilters;
  String get allFiles;
  String get thisWeek;
  String get thisMonth;
  String get earlier;

  // ---- Study ----
  String get studyLoadFailedTitle;
  String get studyLoadFailedBody;
  String get noDecksTitle;
  String get noDecksBody;
  String get focusMode;
  String get sampleDecks;
  String get chooseMode;
  String get flashcards;
  String get quiz;
  String get insideDeck;
  String get sampleNote;
  String get nothingYet;

  // ---- المواد والشباتر ----
  String get subjectsOverline;
  String get subjectsTitle;
  String get allSubjects;

  // ---- لوحة الرئيسية ----
  String get dashboardSubtitle;
  String get readingToday;
  String get continueLabel;
  String get noReadingYet;
  String get noReadingYetHint;
  String get todayStats;
  String get statPagesRead;
  String get statStudyTime;
  String get statCardsReviewed;
  String get statQuestionsSolved;
  String bookCount(int n);
  String subjectCount(int n);
  String get dayStreak;
  String get allTime;
  String get statBooks;
  String get statFinished;
  String get statReadingNow;
  String get statBookmarks;
  String get statSubjects;
  String get statChaptersDone;
  String get statCompletion;
  String get statReadingTime;
  String get statPages;
  String get statSessions;
  String get statReadingDays;
  String duration(int seconds);
  String get studyGreeting;
  String get studyTagline;
  String get yourProgress;
  String get chaptersDone;
  String get studyQuote;

  // ---- الحساب والمكتبة الجديدة ----
  String get account;
  String get appColor;
  String get defaultLabel;
  String accentName(String key);
  String get addYourName;
  String get yourName;
  String get accountLocalNote;
  String get allSettings;
  String studyGreetingName(String name);
  String get librarySubtitle;
  String get recentlyRead;
  String get allCategories;
  String categoryPlural(String key);
  String categoryName(String key);
  String get bookCategory;
  String get noCategory;
  // نموذج إضافة كتاب
  String get addBookTitle;
  String get bookFile;
  String get chooseFile;
  String get changeFile;
  String get bookName;
  String get newCategory;
  String get categoryNameLabel;
  String get addToLibrary;
  String get bookNeedsName;
  String get bookAdded;
  String get bookAlreadyAdded;
  // قارئ EPUB
  String get tableOfContents;
  String get textSize;
  String get noContents;
  String get noBooksInCategory;
  String get noBookmarksInBook;

  String get newSubject;
  String get editSubject;
  String get subjectName;
  String get subjectNameHint;
  String get subjectIcon;
  String get coverImage;
  String get chooseImage;
  String get changeImage;
  String get removeImage;
  String readPercent(int n);
  String get create;
  String get save;
  String get deleteSubjectTitle;
  String deleteSubjectBody(String name);
  String get noSubjectsTitle;
  String get noSubjectsBody;
  String chapters(int n);
  String chapterN(int i);
  String get addChapter;
  String get noChaptersTitle;
  String get noChaptersBody;
  String get renameChapter;
  String get chapterName;
  String get removeFromSubject;
  String get chapterRemoved;
  String get chapterFinished;
  String get reorder;
  String get studySaveFailed;
  String get readChapter;
  String get readFromStart;
  String get chat;
  String get chatDetail;
  String get soon;
  String get sampleLabel;
  String get sampleChapterNote;

  // ---- Flashcards ----
  String get noCardsTitle;
  String get noCardsBody;
  String get backToDecks;
  String cardOf(int i, int total);
  String get lastCard;
  String cardsLeft(int n);
  String get previousCard;
  String get finishDeck;
  String get nextCard;
  String get question;
  String get answer;
  String get tapForAnswer;
  String get tapForQuestion;
  String get doubleTapForAnswer;
  String get doubleTapForQuestion;
  String get deckComplete;
  String reviewedAll(int n);
  String get testWithQuiz;
  String get studyAgain;

  // ---- Quiz ----
  String get noQuestionsTitle;
  String get noQuestionsBody;
  String questionOf(int i, int total);
  String score(int n);
  String get chooseAnswer;
  String get seeScore;
  String get nextQuestion;
  String get greatWork;
  String get greatWorkBody;
  String get goodEffort;
  String get goodEffortBody;
  String get keepPracticing;
  String get keepPracticingBody;
  String get retakeQuiz;
  String get reviewFlashcards;
  String get yourAnswers;
  String scoreOutOf(int score, int total);
  String get correct;
  String get notQuite;
  String theAnswerIs(String a);
  String get noAnswer;
  String yourAnswer(String a);
  String answerIs(String a);

  // ---- Settings ----
  String get preferences;
  String get appearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get themeSystemHint;
  String get language;
  String get languageSystem;
  String get languageSystemHint;
  String get version;
  String get settingsNote;

  // ---- عارض الملفات ----
  String get addText;
  String get editText;
  String get typeYourText;
  String get none;
  String get exportFailed;
  String get notesNotSaved;
  String get saveCopy;
  String get savedSuccessfully;
  String goToPageRange(int count);
  String get go;
  String get goToPage;
  String get classicViewer;
  String get drawMode;
  String get penTool;
  String get markerTool;
  String get pencilTool;
  String get noteFont;
  String get noteColor;
  String get noteBackground;
  String get noteStyle;
  String get noteAlign;
  String get noteOpacity;
  String get noteRotate;
  String get closeNote;
  String get resizeNote;
  // علامات المذكرات
  String get bookmarkNote;
  String get editNoteBookmark;
  String get noteBookmarkName;
  String get noteBookmarkSaved;
  String get removeFromBookmarks;
  String get noteBookmarkHint;
  String get bookmarkPagesTab;
  String get bookmarkNotesTab;
  String get untitledNote;
  String get drawingNote;
  String get noteMissing;
  String get noteTool;
  String get textTool;
  String get lineStyle;
  String get inkColor;
  String get shapeTool;
  // مرفقات الصفحات (صوت وصورة)
  String get audioTool;
  String get imageTool;
  String get recordAudio;
  String get chooseAudioFile;
  String get recordingNow;
  String get tapToRecord;
  String get recordLimit;
  String get micDenied;
  String get attachFailed;
  String get replaceImage;
  String get moveToPage;
  String get audioClip;
  String get closePlayer;
  String get play;
  String get pause;
  String get close;
  String get lineSolid;
  String get lineDashed;
  String get lineDotted;
  String get lineArrow;
  String get shapeLine;
  String get shapeArrow;
  String get shapeRect;
  String get shapeCircle;
  String get moreColors;
  String get pickColor;
  String get eraserTool;
  String get thickness;
  String get undo;
  String get redo;
  String get zoomIn;
  String get zoomOut;
  String get finishEditing;
  String get addEditText;
  String get saveShare;
  String get share;
  String get couldNotOpen;
  String get tapToAddText;
  String get done;
  String get bold;
  String get italic;
  String get underline;
  String get alignLeft;
  String get alignCenter;
  String get alignRight;
  String get coverBackgroundTitle;
  String get coverBackground;
  String get duplicate;
  String get textColor;
  String get size;
  String get opacity;
  String get rotation;
  String retryPage(int n);
}

// ---------------------------------------------------------------------------
// English
// ---------------------------------------------------------------------------

class _En extends AppStrings {
  const _En();

  static String _n(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

  @override bool get isArabic => false;

  @override String get home => 'Home';
  @override String get study => 'Study';
  @override String get library => 'Library';
  @override String get settings => 'Settings';
  @override String get open => 'Open';
  @override String get delete => 'Delete';
  @override String get cancel => 'Cancel';
  @override String get tryAgain => 'Try again';
  @override String get today => 'Today';
  @override String get yesterday => 'Yesterday';
  @override String get unknownDate => 'Unknown date';
  @override String get images => 'Images';
  @override String files(int n) => _n(n, 'file', 'files');
  @override String cards(int n) => _n(n, 'card', 'cards');
  @override String questions(int n) => _n(n, 'question', 'questions');
  @override List<String> get monthsShort => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
  @override List<String> get monthsLong => const [
        'January', 'February', 'March', 'April', 'May', 'June', //
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
  @override List<String> get weekdays => const [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ];

  @override String get fileDeleted => 'File deleted.';
  @override String get fileNotDeleted => 'The file was not deleted. Try again.';
  @override String get fileMissing => 'This file is no longer in the app. Delete it to clean up the list.';
  @override String filesAdded(int n) => n == 1 ? 'File added.' : '$n files added.';
  @override String get noNewFiles => 'No new files added.';
  @override String skipped(int n) => ' $n skipped (already added or not supported).';
  @override String get filesNotSaved => 'The files were not saved. Try again.';
  @override String get deleteFileTitle => 'Delete this file?';
  @override String deleteFileBody(String name) =>
      '"$name" and its notes will be removed from QuickStudy. The original file on your phone stays where it is.';
  @override String get deleteFile => 'Delete file';
  @override String get missing => 'MISSING';

  @override String get goodMorning => 'Good morning';
  @override String get goodAfternoon => 'Good afternoon';
  @override String get goodEvening => 'Good evening';
  @override String get uploadFiles => 'Upload files';
  @override String get searchFiles => 'Search files';
  @override String get overview => 'Overview';
  @override String get continueReading => 'Continue reading';
  @override String get pdfFiles => 'PDF files';
  @override String pageOf(int page, int count) => 'Page $page of $count';
  @override String openedOn(String day) => 'Last opened · $day';
  @override String get notStarted => 'Not started';
  @override String get startReading => 'Start reading';
  @override String get resumeReading => 'Continue reading';
  @override String get noPdfsTitle => 'No PDF files yet';
  @override String get noPdfsBody => 'Add your books and lectures as PDF files to read them here.';
  @override String get addPdf => 'Add book';
  @override String get readerSettings => 'Reading settings';
  @override String get brightness => 'Brightness';
  @override String get margins => 'Margins';
  @override String get marginNone => 'None';
  @override String get marginStandard => 'Standard';
  @override String get marginWide => 'Wide';
  @override String get backgroundColor => 'Background color';
  @override String get colorsDayOnly => 'Night mode uses its own calm colors. Colors apply in day mode.';
  @override List<String> get readerBackgrounds =>
      const ['Classic', 'Green', 'Blue', 'Light', 'Warm', 'Dark'];
  @override String get verticalReading => 'Vertical reading';
  @override String get nightMode => 'Night mode';
  @override String get resetSettings => 'Reset settings';
  @override List<String> get markStyles =>
      const ['Highlight', 'Underline', 'Strikethrough', 'Squiggly'];
  @override List<String> get markColors =>
      const ['Yellow', 'Green', 'Orange', 'Pink', 'Blue'];
  @override String get copyText => 'Copy';
  @override String get markNote => 'Note';
  @override String get markNoteTitle => 'Note on selection';
  @override String get saveNote => 'Save';
  @override String get removeMark => 'Remove';
  @override String get copied => 'Copied';
  @override String get noSelectableText => 'No text found on this page.';
  @override String get recognizingPage => 'One moment, getting the text ready to copy';
  @override String get recognizingHint => 'Scanned pages can take a few seconds';
  @override String get more => 'More';
  @override String get translateDeepL => 'Translate with DeepL';
  @override String get askChatGpt => 'Ask ChatGPT';
  @override String get translateGoogle => 'Google Translate';
  @override String chatGptPrompt(String text) => 'Translate and explain this text briefly:\n\n$text';
  @override String get openAppFailed => 'Could not open the app.';
  @override String get addBookmark => 'Bookmark this page';
  @override String get removeBookmark => 'Remove bookmark';
  @override String get bookmarkAdded => 'Bookmark saved';
  @override String get bookmarkRemoved => 'Bookmark removed';
  @override String get bookmarkAction => 'Bookmark';
  @override String get bookmarksTitle => 'Bookmarks';
  @override String get bookmarksEmpty =>
      'Save a page with the bookmark button while reading, or select text and tap Bookmark.';
  @override String get shelvesTitle => 'Your books';
  @override String pageNumber(int n) => 'Page $n';
  @override String get recentFiles => 'Recent files';
  @override String get seeAll => 'See all';
  @override String get comingSoon =>
      'Summaries, flashcards and quizzes made from your files are coming next. Until then, try the sample decks in Study.';
  @override String get addLectureFiles => 'Add lecture files';
  @override String get addLectureHint => 'Upload PDFs or photos of your notes to read, annotate and study them.';
  @override String get addingFiles => 'Adding files…';
  @override String get uploadNewFiles => 'Upload new files';
  @override String get cardsAndQuizzes => 'Cards and quizzes';
  @override String get todayLabel => 'TODAY';
  @override String get lastAdded => 'Last added';
  @override String get noFilesYet => 'No files uploaded yet.';

  @override String get yourArchive => 'Your archive';
  @override String get libraryEmptyTitle => 'No files yet';
  @override String get libraryEmptyBody => 'Upload PDF files and images of your lectures. Everything you add is kept here.';
  @override String get sortFiles => 'Sort files';
  @override String get newestFirst => 'Newest first';
  @override String get oldestFirst => 'Oldest first';
  @override String get nameAZ => 'Name (A to Z)';
  @override String usedBy(int n) => 'used by ${files(n)}';
  @override String get searchYourFiles => 'Search your files';
  @override String get clearSearch => 'Clear search';
  @override String get all => 'All';
  @override String get fileOptions => 'File options';
  @override String get noMatchTitle => 'No files match';
  @override String get noMatchBody => 'Try another name, or clear the search and filters.';
  @override String get clearFilters => 'Clear search and filters';
  @override String get allFiles => 'All files';
  @override String get thisWeek => 'This week';
  @override String get thisMonth => 'This month';
  @override String get earlier => 'Earlier';

  @override String get studyLoadFailedTitle => 'Study materials did not load';
  @override String get studyLoadFailedBody => 'Check your connection or try again.';
  @override String get noDecksTitle => 'No decks yet';
  @override String get noDecksBody => 'Upload a lecture from Home. Its flashcards and quiz will show up here.';
  @override String get focusMode => 'Focus mode';
  @override String get sampleDecks => 'SAMPLE DECKS';
  @override String get chooseMode => 'Choose a mode';
  @override String get flashcards => 'Flashcards';
  @override String get quiz => 'Quiz';
  @override String get insideDeck => 'Inside this deck';
  @override String get sampleNote =>
      'These are sample decks for trying things out. Decks made from your lectures will replace them.';
  @override String get nothingYet => 'Nothing yet';

  @override String get subjectsOverline => 'YOUR SUBJECTS';
  @override String get subjectsTitle => 'Subjects';
  @override String get allSubjects => 'All subjects';

  @override String get dashboardSubtitle => 'Your reading and study in numbers';
  @override String get readingToday => 'Reading today';
  @override String get continueLabel => 'Continue reading';
  @override String get noReadingYet => 'Nothing opened yet';
  @override String get noReadingYetHint => 'Open a book and it shows up here.';
  @override String get todayStats => "Today's stats";
  @override String get statPagesRead => 'Pages read';
  @override String get statStudyTime => 'Study time';
  @override String get statCardsReviewed => 'Cards reviewed';
  @override String get statQuestionsSolved => 'Questions solved';
  @override String bookCount(int n) => _n(n, 'book', 'books');
  @override String subjectCount(int n) => _n(n, 'subject', 'subjects');
  @override String get dayStreak => 'Day streak';
  @override String get allTime => 'All time';
  @override String get statBooks => 'Books';
  @override String get statFinished => 'Finished';
  @override String get statReadingNow => 'Reading now';
  @override String get statBookmarks => 'Bookmarks';
  @override String get statSubjects => 'Subjects';
  @override String get statChaptersDone => 'Chapters done';
  @override String get statCompletion => 'Completion';
  @override String get statReadingTime => 'Reading time';
  @override String get statPages => 'Pages reached';
  @override String get statSessions => 'Reading sessions';
  @override String get statReadingDays => 'Reading days';
  @override String duration(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }
  @override String get studyGreeting => 'Hi there';
  @override String get studyTagline => 'Ready to get something done today?';
  @override String get yourProgress => 'Your progress';
  @override String get chaptersDone => 'chapters done';
  @override String get studyQuote => 'Discipline today, success tomorrow.';

  @override String get account => 'Account';
  @override String get defaultLabel => 'Default';
  @override String get appColor => 'App color';
  @override String accentName(String key) => switch (key) {
        'ocean' => 'Ocean',
        'emerald' => 'Emerald',
        'rose' => 'Rose',
        'sunset' => 'Sunset',
        'graphite' => 'Graphite',
        _ => 'Violet',
      };
  @override String get addYourName => 'Add your name';
  @override String get yourName => 'Your name';
  @override String get accountLocalNote => 'Saved on this phone. Google sign-in comes later.';
  @override String get allSettings => 'All settings';
  @override String studyGreetingName(String name) => 'Hi, $name';
  @override String get librarySubtitle => 'Your books, all in one place';
  @override String get recentlyRead => 'Recently read';
  @override String get allCategories => 'All';
  @override String categoryPlural(String key) => switch (key) {
        'novel' => 'Novels',
        'study' => 'Studies',
        'philosophy' => 'Philosophy',
        'works' => 'Works',
        _ => key, // تصنيف أضافه المستخدم: يظهر باسمه
      };
  @override String categoryName(String key) => switch (key) {
        'novel' => 'Novel',
        'study' => 'Study',
        'philosophy' => 'Philosophy',
        'works' => 'Work',
        _ => key, // تصنيف أضافه المستخدم: يظهر باسمه
      };
  @override String get bookCategory => 'Category';
  @override String get noCategory => 'No category';
  @override String get addBookTitle => 'Add a book';
  @override String get bookFile => 'File';
  @override String get chooseFile => 'Choose a PDF or EPUB file';
  @override String get changeFile => 'Change';
  @override String get bookName => 'Book name';
  @override String get newCategory => 'New category';
  @override String get categoryNameLabel => 'Category name';
  @override String get addToLibrary => 'Add to library';
  @override String get bookNeedsName => 'Write a name for the book.';
  @override String get bookAdded => 'Book added to the library.';
  @override String get bookAlreadyAdded => 'This book is already in the library.';
  @override String get tableOfContents => 'Contents';
  @override String get textSize => 'Text size';
  @override String get noContents => 'This book has no table of contents.';
  @override String get noBooksInCategory => 'No books here yet.';
  @override String get noBookmarksInBook => 'No bookmarks in this book yet. Add one from the reader.';

  @override String get newSubject => 'New subject';
  @override String get editSubject => 'Edit subject';
  @override String get subjectName => 'Subject name';
  @override String get subjectNameHint => 'e.g. Machine Learning';
  @override String get subjectIcon => 'Icon';
  @override String get coverImage => 'Cover image (optional)';
  @override String get chooseImage => 'Choose an image';
  @override String get changeImage => 'Change';
  @override String get removeImage => 'Remove';
  @override String readPercent(int n) => '$n% read';
  @override String get create => 'Create';
  @override String get save => 'Save';
  @override String get deleteSubjectTitle => 'Delete this subject?';
  @override String deleteSubjectBody(String name) =>
      '"$name" and all its chapter files will be deleted.';
  @override String get noSubjectsTitle => 'No subjects yet';
  @override String get noSubjectsBody => 'Create a subject, then add its chapters from your PDF files.';
  @override String chapters(int n) =>
      n == 0 ? 'No chapters yet' : _n(n, 'chapter', 'chapters');
  @override String chapterN(int i) => 'Chapter $i';
  @override String get addChapter => 'Add chapter';
  @override String get noChaptersTitle => 'No chapters yet';
  @override String get noChaptersBody => 'Upload a PDF for each chapter. These files stay in Study and do not appear in the Library.';
  @override String get renameChapter => 'Rename';
  @override String get chapterName => 'Chapter name';
  @override String get removeFromSubject => 'Delete chapter';
  @override String get chapterRemoved => 'Chapter deleted.';
  @override String get chapterFinished => 'Finished';
  @override String get reorder => 'Reorder';
  @override String get studySaveFailed => "Couldn't save. Try again.";
  @override String get readChapter => 'Read';
  @override String get readFromStart => 'Open the file';
  @override String get chat => 'Chat';
  @override String get chatDetail => 'Ask about this chapter';
  @override String get soon => 'Soon';
  @override String get sampleLabel => 'Sample';
  @override String get sampleChapterNote =>
      'Flashcards and quiz are samples for now. Later they will be made from this chapter.';

  @override String get noCardsTitle => 'No cards in this deck';
  @override String get noCardsBody => 'Cards made from this lecture will appear here.';
  @override String get backToDecks => 'Back to decks';
  @override String cardOf(int i, int total) => 'CARD $i / $total';
  @override String get lastCard => 'Last card';
  @override String cardsLeft(int n) => '$n left';
  @override String get previousCard => 'Previous card';
  @override String get finishDeck => 'Finish deck';
  @override String get nextCard => 'Next card';
  @override String get question => 'QUESTION';
  @override String get answer => 'ANSWER';
  @override String get tapForAnswer => 'Tap to reveal the answer';
  @override String get tapForQuestion => 'Tap to see the question';
  @override String get doubleTapForAnswer => 'Double tap to reveal the answer';
  @override String get doubleTapForQuestion => 'Double tap to see the question';
  @override String get deckComplete => 'Deck complete';
  @override String reviewedAll(int n) => 'You reviewed all ${cards(n)}.';
  @override String get testWithQuiz => 'Test yourself with the quiz';
  @override String get studyAgain => 'Study the cards again';

  @override String get noQuestionsTitle => 'No questions in this deck';
  @override String get noQuestionsBody => 'A quiz made from this lecture will appear here.';
  @override String questionOf(int i, int total) => 'QUESTION $i / $total';
  @override String score(int n) => 'SCORE $n';
  @override String get chooseAnswer => 'Choose an answer';
  @override String get seeScore => 'See my score';
  @override String get nextQuestion => 'Next question';
  @override String get greatWork => 'Great work';
  @override String get greatWorkBody => 'You know this lecture well.';
  @override String get goodEffort => 'Good effort';
  @override String get goodEffortBody => 'Look over the questions you missed, then try again.';
  @override String get keepPracticing => 'Keep practicing';
  @override String get keepPracticingBody => 'Go through the flashcards, then retake the quiz.';
  @override String get retakeQuiz => 'Retake the quiz';
  @override String get reviewFlashcards => 'Review the flashcards';
  @override String get yourAnswers => 'Your answers';
  @override String scoreOutOf(int score, int total) => 'Score $score out of $total';
  @override String get correct => 'Correct';
  @override String get notQuite => 'Not quite';
  @override String theAnswerIs(String a) => 'The answer is: $a';
  @override String get noAnswer => 'No answer';
  @override String yourAnswer(String a) => 'Your answer: $a';
  @override String answerIs(String a) => 'Answer: $a';

  @override String get preferences => 'Preferences';
  @override String get appearance => 'Appearance';
  @override String get themeSystem => 'Auto';
  @override String get themeLight => 'Light';
  @override String get themeDark => 'Dark';
  @override String get themeSystemHint => 'Auto follows your phone setting.';
  @override String get language => 'Language';
  @override String get languageSystem => 'Phone language';
  @override String get languageSystemHint => 'Uses Arabic if your phone is in Arabic, otherwise English.';
  @override String get version => 'Version';
  @override String get settingsNote => 'Your choices are saved on this phone and apply right away.';

  @override String get addText => 'Add text';
  @override String get editText => 'Edit text';
  @override String get typeYourText => 'Type your text...';
  @override String get none => 'None';
  @override String get exportFailed => 'Export failed';
  @override String get notesNotSaved => 'Could not save notes';
  @override String get saveCopy => 'Save a copy';
  @override String get savedSuccessfully => 'Saved successfully';
  @override String goToPageRange(int count) => 'Go to page (1 - $count)';
  @override String get go => 'Go';
  @override String get goToPage => 'Go to page';
  @override String get classicViewer => 'Classic viewer (pen and highlights)';
  @override String get drawMode => 'Draw';
  @override String get penTool => 'Pen';
  @override String get markerTool => 'Marker';
  @override String get pencilTool => 'Pencil';
  @override String get noteFont => 'Font';
  @override String get noteColor => 'Color';
  @override String get noteBackground => 'Background';
  @override String get noteStyle => 'Style';
  @override String get noteAlign => 'Alignment';
  @override String get noteOpacity => 'Opacity';
  @override String get noteRotate => 'Rotate';
  @override String get closeNote => 'Close note';
  @override String get resizeNote => 'Drag to resize the note';
  @override String get bookmarkNote => 'Bookmark this note';
  @override String get editNoteBookmark => 'Edit bookmark';
  @override String get noteBookmarkName => 'Name (optional)';
  @override String get noteBookmarkSaved => 'Note saved to bookmarks';
  @override String get removeFromBookmarks => 'Remove from bookmarks';
  @override String get noteBookmarkHint => 'Save this note to your bookmarks for quick access.';
  @override String get bookmarkPagesTab => 'Pages';
  @override String get bookmarkNotesTab => 'Notes';
  @override String get untitledNote => 'Note';
  @override String get drawingNote => 'Drawing';
  @override String get noteMissing => 'This note no longer exists.';
  @override String get noteTool => 'Note';
  @override String get textTool => 'Text';
  @override String get lineStyle => 'Line';
  @override String get inkColor => 'Color';
  @override String get shapeTool => 'Shapes';
  @override String get audioTool => 'Audio';
  @override String get imageTool => 'Photo';
  @override String get recordAudio => 'Record now';
  @override String get chooseAudioFile => 'Choose an audio file';
  @override String get recordingNow => 'Recording';
  @override String get tapToRecord => 'Tap to start recording';
  @override String get recordLimit => 'Up to 10 minutes';
  @override String get micDenied => 'Microphone access is off. Allow it in the phone settings.';
  @override String get attachFailed => 'Could not add the file.';
  @override String get replaceImage => 'Replace';
  @override String get moveToPage => 'Move to page';
  @override String get audioClip => 'Audio clip';
  @override String get closePlayer => 'Close player';
  @override String get play => 'Play';
  @override String get pause => 'Pause';
  @override String get close => 'Close';
  @override String get lineSolid => 'Solid';
  @override String get lineDashed => 'Dashed';
  @override String get lineDotted => 'Dotted';
  @override String get lineArrow => 'Arrow';
  @override String get shapeLine => 'Line';
  @override String get shapeArrow => 'Arrow';
  @override String get shapeRect => 'Rectangle';
  @override String get shapeCircle => 'Circle';
  @override String get moreColors => 'More colors';
  @override String get pickColor => 'Pick a color';
  @override String get eraserTool => 'Eraser';
  @override String get thickness => 'Thickness';
  @override String get undo => 'Undo';
  @override String get redo => 'Redo';
  @override String get zoomIn => 'Zoom in';
  @override String get zoomOut => 'Zoom out';
  @override String get finishEditing => 'Finish editing';
  @override String get addEditText => 'Add / edit text';
  @override String get saveShare => 'Save / Share';
  @override String get share => 'Share';
  @override String get couldNotOpen => 'Could not open this file';
  @override String get tapToAddText => 'Tap anywhere to add text, or tap a text to edit it';
  @override String get done => 'Done';
  @override String get bold => 'Bold';
  @override String get italic => 'Italic';
  @override String get underline => 'Underline';
  @override String get alignLeft => 'Align left';
  @override String get alignCenter => 'Align center';
  @override String get alignRight => 'Align right';
  @override String get coverBackgroundTitle => 'Background (cover original text)';
  @override String get coverBackground => 'Background / cover original text';
  @override String get duplicate => 'Duplicate';
  @override String get textColor => 'Text color';
  @override String get size => 'Size';
  @override String get opacity => 'Opacity';
  @override String get rotation => 'Rotation';
  @override String retryPage(int n) => 'Retry page $n';
}

// ---------------------------------------------------------------------------
// العربية
// ---------------------------------------------------------------------------

class _Ar extends AppStrings {
  const _Ar();

  // صيغ الجمع العربية: 1، 2، 3-10، 11+
  static String _n(int n, String one, String two, String few, String many) {
    if (n == 0) return '0 $many';
    if (n == 1) return one;
    if (n == 2) return two;
    if (n % 100 >= 3 && n % 100 <= 10) return '$n $few';
    return '$n $many';
  }

  @override bool get isArabic => true;

  @override String get appName => 'كويك ستادي';
  @override String get home => 'الرئيسية';
  @override String get study => 'المذاكرة';
  @override String get library => 'المكتبة';
  @override String get settings => 'الإعدادات';
  @override String get open => 'فتح';
  @override String get delete => 'حذف';
  @override String get cancel => 'إلغاء';
  @override String get tryAgain => 'حاول مرة أخرى';
  @override String get today => 'اليوم';
  @override String get yesterday => 'أمس';
  @override String get unknownDate => 'تاريخ غير معروف';
  @override String get images => 'الصور';
  @override String files(int n) => _n(n, 'ملف واحد', 'ملفان', 'ملفات', 'ملف');
  @override String cards(int n) => _n(n, 'بطاقة واحدة', 'بطاقتان', 'بطاقات', 'بطاقة');
  @override String questions(int n) => _n(n, 'سؤال واحد', 'سؤالان', 'أسئلة', 'سؤال');
  @override List<String> get monthsShort => monthsLong;
  @override List<String> get monthsLong => const [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
      ];
  @override List<String> get weekdays => const [
        'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
      ];

  @override String get fileDeleted => 'تم حذف الملف.';
  @override String get fileNotDeleted => 'لم يُحذف الملف. حاول مرة أخرى.';
  @override String get fileMissing => 'هذا الملف لم يعد موجودًا في التطبيق. احذفه لتنظيف القائمة.';
  @override String filesAdded(int n) => n == 1 ? 'تمت إضافة الملف.' : 'تمت إضافة ${files(n)}.';
  @override String get noNewFiles => 'لم تُضف ملفات جديدة.';
  @override String skipped(int n) => ' تم تخطي ${files(n)} (مضاف مسبقًا أو غير مدعوم).';
  @override String get filesNotSaved => 'لم تُحفظ الملفات. حاول مرة أخرى.';
  @override String get deleteFileTitle => 'حذف هذا الملف؟';
  @override String deleteFileBody(String name) =>
      'سيُحذف "$name" وملاحظاته من التطبيق. الملف الأصلي في هاتفك يبقى كما هو.';
  @override String get deleteFile => 'حذف الملف';
  @override String get missing => 'مفقود';

  @override String get goodMorning => 'صباح الخير';
  @override String get goodAfternoon => 'مساء الخير';
  @override String get goodEvening => 'مساء الخير';
  @override String get uploadFiles => 'رفع ملفات';
  @override String get searchFiles => 'البحث في الملفات';
  @override String get overview => 'نظرة عامة';
  @override String get continueReading => 'تابع القراءة';
  @override String get pdfFiles => 'ملفات PDF';
  @override String pageOf(int page, int count) => 'صفحة $page من $count';
  @override String openedOn(String day) => 'آخر فتح · $day';
  @override String get notStarted => 'لم تبدأ بعد';
  @override String get startReading => 'ابدأ القراءة';
  @override String get resumeReading => 'تابع القراءة';
  @override String get noPdfsTitle => 'لا توجد ملفات PDF';
  @override String get noPdfsBody => 'أضف كتبك ومحاضراتك بصيغة PDF لتقرأها هنا.';
  @override String get addPdf => 'إضافة كتاب';
  @override String get readerSettings => 'إعدادات القراءة';
  @override String get brightness => 'السطوع';
  @override String get margins => 'الهوامش';
  @override String get marginNone => 'بدون';
  @override String get marginStandard => 'قياسية';
  @override String get marginWide => 'واسعة';
  @override String get backgroundColor => 'لون الخلفية';
  @override String get colorsDayOnly => 'الوضع الليلي له ألوان هادئة خاصة، والألوان تعمل في الوضع النهاري.';
  @override List<String> get readerBackgrounds =>
      const ['كلاسيكي', 'أخضر', 'أزرق', 'فاتح', 'دافئ', 'داكن'];
  @override String get verticalReading => 'قراءة عامودية';
  @override String get nightMode => 'الوضع الليلي';
  @override String get resetSettings => 'إعادة ضبط الإعدادات';
  @override List<String> get markStyles =>
      const ['تظليل', 'خط تحت', 'شطب', 'خط متموج'];
  @override List<String> get markColors =>
      const ['أصفر', 'أخضر', 'برتقالي', 'وردي', 'أزرق'];
  @override String get copyText => 'نسخ';
  @override String get markNote => 'ملاحظة';
  @override String get markNoteTitle => 'ملاحظة على التحديد';
  @override String get saveNote => 'حفظ';
  @override String get removeMark => 'مسح التحديد';
  @override String get copied => 'تم النسخ';
  @override String get noSelectableText => 'لم يُعثر على نص في هذه الصفحة.';
  @override String get recognizingPage => 'لحظة، نجهّز النص للنسخ';
  @override String get recognizingHint => 'قد يأخذ ثوانٍ في الصفحات الممسوحة';
  @override String get more => 'المزيد';
  @override String get translateDeepL => 'ترجمة بـ DeepL';
  @override String get askChatGpt => 'اسأل ChatGPT';
  @override String get translateGoogle => 'ترجمة Google';
  @override String chatGptPrompt(String text) => 'ترجم هذا النص واشرحه باختصار:\n\n$text';
  @override String get openAppFailed => 'تعذّر فتح التطبيق.';
  @override String get addBookmark => 'علامة على هذه الصفحة';
  @override String get removeBookmark => 'إزالة العلامة';
  @override String get bookmarkAdded => 'حُفظت العلامة';
  @override String get bookmarkRemoved => 'أُزيلت العلامة';
  @override String get bookmarkAction => 'علامة';
  @override String get bookmarksTitle => 'العلامات المرجعية';
  @override String get bookmarksEmpty =>
      'احفظ صفحة بزر العلامة أثناء القراءة، أو حدّد نصًا واضغط علامة.';
  @override String get shelvesTitle => 'كتبك';
  @override String pageNumber(int n) => 'صفحة $n';
  @override String get recentFiles => 'آخر الملفات';
  @override String get seeAll => 'عرض الكل';
  @override String get comingSoon =>
      'قريبًا: ملخصات وبطاقات واختبارات من ملفاتك. حتى ذلك الحين، جرّب المجموعات التجريبية في المذاكرة.';
  @override String get addLectureFiles => 'أضف ملفات المحاضرات';
  @override String get addLectureHint => 'ارفع ملفات PDF أو صور ملاحظاتك لتقرأها وتكتب عليها وتذاكرها.';
  @override String get addingFiles => 'جارٍ إضافة الملفات…';
  @override String get uploadNewFiles => 'رفع ملفات جديدة';
  @override String get cardsAndQuizzes => 'بطاقات واختبارات';
  @override String get todayLabel => 'اليوم';
  @override String get lastAdded => 'آخر إضافة';
  @override String get noFilesYet => 'لم ترفع أي ملف بعد.';

  @override String get yourArchive => 'أرشيفك';
  @override String get libraryEmptyTitle => 'لا توجد ملفات بعد';
  @override String get libraryEmptyBody => 'ارفع ملفات PDF وصور محاضراتك. كل ما تضيفه يُحفظ هنا.';
  @override String get sortFiles => 'ترتيب الملفات';
  @override String get newestFirst => 'الأحدث أولًا';
  @override String get oldestFirst => 'الأقدم أولًا';
  @override String get nameAZ => 'الاسم (أ إلى ي)';
  @override String usedBy(int n) => 'في ${files(n)}';
  @override String get searchYourFiles => 'ابحث في ملفاتك';
  @override String get clearSearch => 'مسح البحث';
  @override String get all => 'الكل';
  @override String get fileOptions => 'خيارات الملف';
  @override String get noMatchTitle => 'لا توجد ملفات مطابقة';
  @override String get noMatchBody => 'جرّب اسمًا آخر، أو امسح البحث والفلاتر.';
  @override String get clearFilters => 'مسح البحث والفلاتر';
  @override String get allFiles => 'كل الملفات';
  @override String get thisWeek => 'هذا الأسبوع';
  @override String get thisMonth => 'هذا الشهر';
  @override String get earlier => 'أقدم';

  @override String get studyLoadFailedTitle => 'لم تُحمَّل مواد المذاكرة';
  @override String get studyLoadFailedBody => 'تحقق من الاتصال أو حاول مرة أخرى.';
  @override String get noDecksTitle => 'لا توجد مجموعات بعد';
  @override String get noDecksBody => 'ارفع محاضرة من الرئيسية، وستظهر بطاقاتها واختبارها هنا.';
  @override String get focusMode => 'وضع التركيز';
  @override String get sampleDecks => 'مجموعات تجريبية';
  @override String get chooseMode => 'اختر طريقة المذاكرة';
  @override String get flashcards => 'البطاقات';
  @override String get quiz => 'الاختبار';
  @override String get insideDeck => 'داخل هذه المجموعة';
  @override String get sampleNote =>
      'هذه مجموعات تجريبية للتجربة فقط. ستحل محلها المجموعات المصنوعة من محاضراتك.';
  @override String get nothingYet => 'لا شيء بعد';

  @override String get subjectsOverline => 'موادك';
  @override String get subjectsTitle => 'المواد';
  @override String get allSubjects => 'كل المواد';

  @override String get dashboardSubtitle => 'قراءتك ومذاكرتك بالأرقام';
  @override String get readingToday => 'قراءتك اليوم';
  @override String get continueLabel => 'متابعة القراءة';
  @override String get noReadingYet => 'لم تفتح كتابًا بعد';
  @override String get noReadingYetHint => 'افتح كتابًا ليظهر هنا.';
  @override String get todayStats => 'إحصائيات اليوم';
  @override String get statPagesRead => 'صفحة مقروءة';
  @override String get statStudyTime => 'وقت الدراسة';
  @override String get statCardsReviewed => 'بطاقة مراجعة';
  @override String get statQuestionsSolved => 'سؤال محلول';
  @override String bookCount(int n) => _n(n, 'كتاب واحد', 'كتابان', 'كتب', 'كتابًا');
  @override String subjectCount(int n) => _n(n, 'مادة واحدة', 'مادتان', 'مواد', 'مادة');
  @override String get dayStreak => 'أيام متتالية';
  @override String get allTime => 'الإجمالي';
  @override String get statBooks => 'كتب';
  @override String get statFinished => 'أنهيتها';
  @override String get statReadingNow => 'تقرؤها الآن';
  @override String get statBookmarks => 'علامات';
  @override String get statSubjects => 'مواد';
  @override String get statChaptersDone => 'شباتر منتهية';
  @override String get statCompletion => 'نسبة الإنجاز';
  @override String get statReadingTime => 'وقت القراءة';
  @override String get statPages => 'صفحات وصلت إليها';
  @override String get statSessions => 'جلسات قراءة';
  @override String get statReadingDays => 'أيام قراءة';
  @override String duration(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '$m د';
    return '${m ~/ 60} س ${m % 60} د';
  }
  @override String get studyGreeting => 'أهلًا';
  @override String get studyTagline => 'جاهز تنجز شيئًا اليوم؟';
  @override String get yourProgress => 'تقدمك';
  @override String get chaptersDone => 'شباتر منتهية';
  @override String get studyQuote => 'انضباط اليوم، نجاح الغد.';

  @override String get account => 'الحساب';
  @override String get defaultLabel => 'الافتراضي';
  @override String get appColor => 'لون التطبيق';
  @override String accentName(String key) => switch (key) {
        'ocean' => 'أزرق',
        'emerald' => 'أخضر',
        'rose' => 'وردي',
        'sunset' => 'برتقالي',
        'graphite' => 'رمادي',
        _ => 'بنفسجي',
      };
  @override String get addYourName => 'أضف اسمك';
  @override String get yourName => 'اسمك';
  @override String get accountLocalNote => 'محفوظ على هذا الهاتف. الربط بحساب قوقل لاحقًا.';
  @override String get allSettings => 'كل الإعدادات';
  @override String studyGreetingName(String name) => 'أهلًا، $name';
  @override String get librarySubtitle => 'كتبك كلها في مكان واحد';
  @override String get recentlyRead => 'آخر ما قرأت';
  @override String get allCategories => 'الكل';
  @override String categoryPlural(String key) => switch (key) {
        'novel' => 'روايات',
        'study' => 'دراسات',
        'philosophy' => 'فلسفة',
        'works' => 'مؤلفات',
        _ => key, // تصنيف أضافه المستخدم: يظهر باسمه
      };
  @override String categoryName(String key) => switch (key) {
        'novel' => 'رواية',
        'study' => 'دراسة',
        'philosophy' => 'فلسفة',
        'works' => 'مؤلَّف',
        _ => key, // تصنيف أضافه المستخدم: يظهر باسمه
      };
  @override String get bookCategory => 'التصنيف';
  @override String get noCategory => 'بلا تصنيف';
  @override String get addBookTitle => 'إضافة كتاب';
  @override String get bookFile => 'الملف';
  @override String get chooseFile => 'اختر ملف PDF أو EPUB';
  @override String get changeFile => 'تغيير';
  @override String get bookName => 'اسم الكتاب';
  @override String get newCategory => 'تصنيف جديد';
  @override String get categoryNameLabel => 'اسم التصنيف';
  @override String get addToLibrary => 'إضافة إلى المكتبة';
  @override String get bookNeedsName => 'اكتب اسمًا للكتاب.';
  @override String get bookAdded => 'أُضيف الكتاب إلى المكتبة.';
  @override String get bookAlreadyAdded => 'هذا الكتاب موجود في المكتبة.';
  @override String get tableOfContents => 'الفهرس';
  @override String get textSize => 'حجم الخط';
  @override String get noContents => 'لا فهرس في هذا الكتاب.';
  @override String get noBooksInCategory => 'لا كتب هنا بعد.';
  @override String get noBookmarksInBook => 'لا علامات في هذا الكتاب بعد. أضفها من شاشة القراءة.';

  @override String get newSubject => 'مادة جديدة';
  @override String get editSubject => 'تعديل المادة';
  @override String get subjectName => 'اسم المادة';
  @override String get subjectNameHint => 'مثل: تعلم الآلة';
  @override String get subjectIcon => 'الأيقونة';
  @override String get coverImage => 'صورة الغلاف (اختيارية)';
  @override String get chooseImage => 'اختر صورة';
  @override String get changeImage => 'تغيير';
  @override String get removeImage => 'إزالة';
  // علامة LTR حتى تظهر 4% لا %4 داخل النص العربي
  @override String readPercent(int n) => 'قرأت ‎$n%';
  @override String get create => 'إنشاء';
  @override String get save => 'حفظ';
  @override String get deleteSubjectTitle => 'حذف هذه المادة؟';
  @override String deleteSubjectBody(String name) =>
      'ستُحذف "$name" وكل ملفات شباترها.';
  @override String get noSubjectsTitle => 'لا توجد مواد بعد';
  @override String get noSubjectsBody => 'أنشئ مادة، ثم أضف شباترها من ملفات PDF.';
  @override String chapters(int n) =>
      n == 0 ? 'لا شباتر بعد' : _n(n, 'شابتر واحد', 'شابتران', 'شباتر', 'شابتر');
  @override String chapterN(int i) => 'الشابتر $i';
  @override String get addChapter => 'إضافة شابتر';
  @override String get noChaptersTitle => 'لا توجد شباتر بعد';
  @override String get noChaptersBody => 'ارفع ملف PDF لكل شابتر. ملفات المذاكرة تبقى هنا ولا تظهر في المكتبة.';
  @override String get renameChapter => 'تغيير الاسم';
  @override String get chapterName => 'اسم الشابتر';
  @override String get removeFromSubject => 'حذف الشابتر';
  @override String get chapterRemoved => 'حُذف الشابتر.';
  @override String get chapterFinished => 'انتهيت منه';
  @override String get reorder => 'تغيير الترتيب';
  @override String get studySaveFailed => 'تعذّر الحفظ. حاول مرة أخرى.';
  @override String get readChapter => 'قراءة';
  @override String get readFromStart => 'افتح الملف';
  @override String get chat => 'محادثة';
  @override String get chatDetail => 'اسأل عن الشابتر';
  @override String get soon => 'قريبًا';
  @override String get sampleLabel => 'تجريبي';
  @override String get sampleChapterNote =>
      'البطاقات والاختبار تجريبية الآن. لاحقًا تُصنع من الشابتر نفسه.';

  @override String get noCardsTitle => 'لا توجد بطاقات في هذه المجموعة';
  @override String get noCardsBody => 'ستظهر هنا البطاقات المصنوعة من هذه المحاضرة.';
  @override String get backToDecks => 'العودة للمجموعات';
  @override String cardOf(int i, int total) => 'البطاقة $i من $total';
  @override String get lastCard => 'آخر بطاقة';
  @override String cardsLeft(int n) => 'بقي ${cards(n)}';
  @override String get previousCard => 'البطاقة السابقة';
  @override String get finishDeck => 'إنهاء المجموعة';
  @override String get nextCard => 'البطاقة التالية';
  @override String get question => 'سؤال';
  @override String get answer => 'الجواب';
  @override String get tapForAnswer => 'اضغط لرؤية الجواب';
  @override String get tapForQuestion => 'اضغط لرؤية السؤال';
  @override String get doubleTapForAnswer => 'اضغط مرتين لرؤية الجواب';
  @override String get doubleTapForQuestion => 'اضغط مرتين لرؤية السؤال';
  @override String get deckComplete => 'أنهيت المجموعة';
  @override String reviewedAll(int n) => 'راجعت ${cards(n)}، كل المجموعة.';
  @override String get testWithQuiz => 'اختبر نفسك';
  @override String get studyAgain => 'ذاكر البطاقات مرة أخرى';

  @override String get noQuestionsTitle => 'لا توجد أسئلة في هذه المجموعة';
  @override String get noQuestionsBody => 'سيظهر هنا اختبار هذه المحاضرة.';
  @override String questionOf(int i, int total) => 'السؤال $i من $total';
  @override String score(int n) => 'النتيجة $n';
  @override String get chooseAnswer => 'اختر إجابة';
  @override String get seeScore => 'عرض نتيجتي';
  @override String get nextQuestion => 'السؤال التالي';
  @override String get greatWork => 'عمل رائع';
  @override String get greatWorkBody => 'أنت تفهم هذه المحاضرة جيدًا.';
  @override String get goodEffort => 'جهد جيد';
  @override String get goodEffortBody => 'راجع الأسئلة التي أخطأت فيها، ثم حاول مرة أخرى.';
  @override String get keepPracticing => 'استمر في التدريب';
  @override String get keepPracticingBody => 'راجع البطاقات، ثم أعد الاختبار.';
  @override String get retakeQuiz => 'أعد الاختبار';
  @override String get reviewFlashcards => 'راجع البطاقات';
  @override String get yourAnswers => 'إجاباتك';
  @override String scoreOutOf(int score, int total) => 'النتيجة $score من $total';
  @override String get correct => 'إجابة صحيحة';
  @override String get notQuite => 'ليست صحيحة';
  @override String theAnswerIs(String a) => 'الإجابة الصحيحة: $a';
  @override String get noAnswer => 'بلا إجابة';
  @override String yourAnswer(String a) => 'إجابتك: $a';
  @override String answerIs(String a) => 'الصحيح: $a';

  @override String get preferences => 'التفضيلات';
  @override String get appearance => 'المظهر';
  @override String get themeSystem => 'تلقائي';
  @override String get themeLight => 'فاتح';
  @override String get themeDark => 'داكن';
  @override String get themeSystemHint => 'التلقائي يتبع إعداد هاتفك.';
  @override String get language => 'اللغة';
  @override String get languageSystem => 'لغة الهاتف';
  @override String get languageSystemHint => 'العربية إذا كان هاتفك بالعربية، وإلا الإنجليزية.';
  @override String get version => 'الإصدار';
  @override String get settingsNote => 'اختياراتك تُحفظ على هذا الهاتف وتُطبَّق فورًا.';

  @override String get addText => 'إضافة نص';
  @override String get editText => 'تعديل النص';
  @override String get typeYourText => 'اكتب النص...';
  @override String get none => 'بدون';
  @override String get exportFailed => 'فشل التصدير';
  @override String get notesNotSaved => 'لم تُحفظ الملاحظات';
  @override String get saveCopy => 'حفظ نسخة';
  @override String get savedSuccessfully => 'تم الحفظ';
  @override String goToPageRange(int count) => 'الذهاب إلى صفحة (1 - $count)';
  @override String get go => 'اذهب';
  @override String get goToPage => 'الذهاب إلى صفحة';
  @override String get classicViewer => 'العارض القديم (القلم والتحديد)';
  @override String get drawMode => 'الرسم';
  @override String get penTool => 'قلم';
  @override String get markerTool => 'قلم تظليل';
  @override String get pencilTool => 'رصاص';
  @override String get noteFont => 'الخط';
  @override String get noteColor => 'اللون';
  @override String get noteBackground => 'الخلفية';
  @override String get noteStyle => 'النمط';
  @override String get noteAlign => 'المحاذاة';
  @override String get noteOpacity => 'الشفافية';
  @override String get noteRotate => 'الدوران';
  @override String get closeNote => 'إغلاق المذكرة';
  @override String get resizeNote => 'اسحب لتغيير حجم المذكرة';
  @override String get bookmarkNote => 'أضف المذكرة إلى العلامات';
  @override String get editNoteBookmark => 'تعديل العلامة';
  @override String get noteBookmarkName => 'الاسم (اختياري)';
  @override String get noteBookmarkSaved => 'حُفظت المذكرة في العلامات';
  @override String get removeFromBookmarks => 'إزالة من العلامات';
  @override String get noteBookmarkHint => 'احفظ هذه المذكرة في العلامات لتصل إليها بسرعة.';
  @override String get bookmarkPagesTab => 'الصفحات';
  @override String get bookmarkNotesTab => 'المذكرات';
  @override String get untitledNote => 'مذكرة';
  @override String get drawingNote => 'رسم';
  @override String get noteMissing => 'هذه المذكرة لم تعد موجودة.';
  @override String get noteTool => 'مذكرة';
  @override String get textTool => 'نص';
  @override String get lineStyle => 'نمط الخط';
  @override String get inkColor => 'اللون';
  @override String get shapeTool => 'أشكال';
  @override String get audioTool => 'صوت';
  @override String get imageTool => 'صورة';
  @override String get recordAudio => 'سجّل الآن';
  @override String get chooseAudioFile => 'اختر ملفًا صوتيًا';
  @override String get recordingNow => 'جارٍ التسجيل';
  @override String get tapToRecord => 'المس لبدء التسجيل';
  @override String get recordLimit => 'حتى 10 دقائق';
  @override String get micDenied => 'الوصول إلى الميكروفون مغلق. اسمح به من إعدادات الهاتف.';
  @override String get attachFailed => 'تعذّرت إضافة الملف.';
  @override String get replaceImage => 'استبدال';
  @override String get moveToPage => 'إرجاع إلى الصفحة';
  @override String get audioClip => 'مقطع صوتي';
  @override String get closePlayer => 'إغلاق المشغل';
  @override String get play => 'تشغيل';
  @override String get pause => 'إيقاف مؤقت';
  @override String get close => 'إغلاق';
  @override String get lineSolid => 'متصل';
  @override String get lineDashed => 'متقطع';
  @override String get lineDotted => 'منقط';
  @override String get lineArrow => 'سهم';
  @override String get shapeLine => 'خط';
  @override String get shapeArrow => 'سهم';
  @override String get shapeRect => 'مستطيل';
  @override String get shapeCircle => 'دائرة';
  @override String get moreColors => 'ألوان أكثر';
  @override String get pickColor => 'اختر لونًا';
  @override String get eraserTool => 'ممحاة';
  @override String get thickness => 'السماكة';
  @override String get undo => 'تراجع';
  @override String get redo => 'إعادة';
  @override String get zoomIn => 'تكبير';
  @override String get zoomOut => 'تصغير';
  @override String get finishEditing => 'إنهاء التعديل';
  @override String get addEditText => 'إضافة / تعديل نص';
  @override String get saveShare => 'حفظ / مشاركة';
  @override String get share => 'مشاركة';
  @override String get couldNotOpen => 'تعذّر فتح هذا الملف';
  @override String get tapToAddText => 'اضغط في أي مكان لإضافة نص، أو على نص لتعديله';
  @override String get done => 'تم';
  @override String get bold => 'عريض';
  @override String get italic => 'مائل';
  @override String get underline => 'تسطير';
  @override String get alignLeft => 'محاذاة لليسار';
  @override String get alignCenter => 'توسيط';
  @override String get alignRight => 'محاذاة لليمين';
  @override String get coverBackgroundTitle => 'الخلفية (تغطية النص الأصلي)';
  @override String get coverBackground => 'خلفية / تغطية النص الأصلي';
  @override String get duplicate => 'تكرار';
  @override String get textColor => 'لون النص';
  @override String get size => 'الحجم';
  @override String get opacity => 'الشفافية';
  @override String get rotation => 'الدوران';
  @override String retryPage(int n) => 'إعادة تحميل الصفحة $n';
}
