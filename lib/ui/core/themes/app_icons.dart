import 'package:hugeicons/hugeicons.dart';

// نوع بيانات أيقونات Hugeicons (مسارات SVG)
typedef AppIconData = List<List<dynamic>>;

// ---------------------------------------------------------------------------
// كل أيقونات التطبيق من مكان واحد (Hugeicons · Stroke Rounded)
// كل الأسماء هنا مُتحقق منها في hugeicons 1.2.0
// تُعرض بالويدجت AppIcon (في ui/core/ui/app_icon.dart)
// ---------------------------------------------------------------------------

abstract final class AppIcons {
  // التنقل
  static const AppIconData home = HugeIcons.strokeRoundedHome01;
  static const AppIconData study = HugeIcons.strokeRoundedMortarboard02;
  static const AppIconData libraryTab = HugeIcons.strokeRoundedBooks01;

  // الملفات
  static const AppIconData upload = HugeIcons.strokeRoundedCloudUpload;
  static const AppIconData download = HugeIcons.strokeRoundedCloudDownload;
  static const AppIconData link = HugeIcons.strokeRoundedLink01;
  static const AppIconData add = HugeIcons.strokeRoundedAdd01;
  static const AppIconData pdf = HugeIcons.strokeRoundedPdf01;
  static const AppIconData image = HugeIcons.strokeRoundedImage01;
  static const AppIconData file = HugeIcons.strokeRoundedDocumentAttachment;
  static const AppIconData folder = HugeIcons.strokeRoundedFolder01;
  static const AppIconData archive = HugeIcons.strokeRoundedArchive02;
  static const AppIconData trash = HugeIcons.strokeRoundedDelete02;
  static const AppIconData bookmark = HugeIcons.strokeRoundedBookmark01;
  static const AppIconData bookmarkSaved =
      HugeIcons.strokeRoundedBookmarkCheck01;
  static const AppIconData bookmarkAdd = HugeIcons.strokeRoundedBookmarkAdd02;
  static const AppIconData copy = HugeIcons.strokeRoundedCopy01;
  static const AppIconData stickyNote = HugeIcons.strokeRoundedStickyNote02;
  static const AppIconData pen = HugeIcons.strokeRoundedPencilEdit02;
  static const AppIconData draw = HugeIcons.strokeRoundedPenTool01;
  static const AppIconData penNib = HugeIcons.strokeRoundedPenTool01;
  static const AppIconData textTool = HugeIcons.strokeRoundedTextFont;
  static const AppIconData pencil = HugeIcons.strokeRoundedPencil;
  static const AppIconData highlighter = HugeIcons.strokeRoundedHighlighter;
  static const AppIconData eraser = HugeIcons.strokeRoundedEraser01;
  static const AppIconData undo = HugeIcons.strokeRoundedUndo02;
  static const AppIconData redo = HugeIcons.strokeRoundedRedo02;
  static const AppIconData calendar = HugeIcons.strokeRoundedCalendar03;

  // البحث والقوائم
  static const AppIconData search = HugeIcons.strokeRoundedSearch01;
  static const AppIconData close = HugeIcons.strokeRoundedCancel01;
  static const AppIconData sort =
      HugeIcons.strokeRoundedArrowDataTransferVertical;
  static const AppIconData more = HugeIcons.strokeRoundedMoreVertical;
  static const AppIconData moreHorizontal =
      HugeIcons.strokeRoundedMoreHorizontal;
  static const AppIconData edit = HugeIcons.strokeRoundedEdit02;
  static const AppIconData dragHandle = HugeIcons.strokeRoundedDragDropVertical;
  static const AppIconData remove = HugeIcons.strokeRoundedRemove01;
  static const AppIconData chat = HugeIcons.strokeRoundedBubbleChat;
  static const AppIconData folderAdd = HugeIcons.strokeRoundedFolderAdd;
  static const AppIconData chevron = HugeIcons.strokeRoundedArrowRight01;

  // المذاكرة
  static const AppIconData cards = HugeIcons.strokeRoundedCards01;
  static const AppIconData quiz = HugeIcons.strokeRoundedCheckList;
  static const AppIconData deck = HugeIcons.strokeRoundedLayers01;
  static const AppIconData book = HugeIcons.strokeRoundedBookOpen01;
  static const AppIconData brain = HugeIcons.strokeRoundedBrain02;
  static const AppIconData next = HugeIcons.strokeRoundedArrowRight02;
  static const AppIconData previous = HugeIcons.strokeRoundedArrowLeft02;
  static const AppIconData replay =
      HugeIcons.strokeRoundedArrowReloadHorizontal;
  static const AppIconData tap = HugeIcons.strokeRoundedCursorPointer01;
  static const AppIconData idea = HugeIcons.strokeRoundedBulb;
  static const AppIconData trophy = HugeIcons.strokeRoundedChampion;
  static const AppIconData award = HugeIcons.strokeRoundedAward01;
  static const AppIconData check = HugeIcons.strokeRoundedTick02;
  static const AppIconData correct = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const AppIconData wrong = HugeIcons.strokeRoundedCancelCircle;

  // عام
  static const AppIconData info = HugeIcons.strokeRoundedInformationCircle;
  static const AppIconData sparkle = HugeIcons.strokeRoundedAiSparkles;
  static const AppIconData error = HugeIcons.strokeRoundedAlertCircle;
  static const AppIconData dashboard = HugeIcons.strokeRoundedDashboardSquare02;

  // الإعدادات
  static const AppIconData settings = HugeIcons.strokeRoundedSettings02;
  static const AppIconData sun = HugeIcons.strokeRoundedSun03;
  static const AppIconData moon = HugeIcons.strokeRoundedMoon02;
  static const AppIconData phone = HugeIcons.strokeRoundedSmartPhone01;
  static const AppIconData language = HugeIcons.strokeRoundedTranslate;

  // أيقونات اتجاهية: تنعكس تلقائيًا في العربية (من اليمين لليسار)
  static final Set<AppIconData> directional = {chevron, next, previous};

  // صورة الغلاف
  static const AppIconData imageAdd = HugeIcons.strokeRoundedImageAdd01;

  // صفحة المذاكرة: التحية والاقتباس والزخرفة
  static const AppIconData wave = HugeIcons.strokeRoundedWavingHand01;
  static const AppIconData quote = HugeIcons.strokeRoundedQuoteUp;
  static const AppIconData sparkles = HugeIcons.strokeRoundedSparkles;

  // لوحة الرئيسية
  static const AppIconData fire = HugeIcons.strokeRoundedFire;
  static const AppIconData timer = HugeIcons.strokeRoundedTimer01;
  static const AppIconData target = HugeIcons.strokeRoundedTarget02;
  static const AppIconData files = HugeIcons.strokeRoundedFiles01;
  static const AppIconData chart = HugeIcons.strokeRoundedChartHistogram;
}
