import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ---------------------------------------------------------------------------
// كل أيقونات التطبيق من مكان واحد (Lucide: خطوط رفيعة بزوايا ناعمة)
// إذا ظهر خطأ في اسم أيقونة، اكتب LucideIcons. في VS Code
// واختر البديل من الاقتراحات، وغيّر السطر هنا فقط.
// ---------------------------------------------------------------------------

abstract final class AppIcons {
  // التنقل (المختار يتميز باللون الأخضر والخلفية في الشريط)
  static const IconData home = LucideIcons.house;
  static const IconData homeActive = LucideIcons.house;
  static const IconData study = LucideIcons.graduationCap;
  static const IconData studyActive = LucideIcons.graduationCap;
  static const IconData books = LucideIcons.libraryBig;
  static const IconData booksActive = LucideIcons.libraryBig;

  // الملفات
  static const IconData upload = LucideIcons.upload;
  static const IconData add = LucideIcons.plus;
  static const IconData pdf = LucideIcons.fileText;
  static const IconData image = LucideIcons.image;
  static const IconData file = LucideIcons.file;
  static const IconData folder = LucideIcons.folderOpen;
  static const IconData trash = LucideIcons.trash2;
  static const IconData open = LucideIcons.externalLink;
  static const IconData bookmark = LucideIcons.bookmark;

  // البحث والقوائم
  static const IconData search = LucideIcons.search;
  static const IconData close = LucideIcons.x;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData chevron = LucideIcons.chevronRight;

  // المذاكرة
  static const IconData cards = LucideIcons.galleryVerticalEnd;
  static const IconData quiz = LucideIcons.listChecks;
  static const IconData deck = LucideIcons.layers;
  static const IconData next = LucideIcons.arrowRight;
  static const IconData previous = LucideIcons.arrowLeft;
  static const IconData replay = LucideIcons.rotateCcw;
  static const IconData finish = LucideIcons.flag;
  static const IconData tap = LucideIcons.pointer;
  static const IconData idea = LucideIcons.lightbulb;
  static const IconData trophy = LucideIcons.trophy;
  static const IconData check = LucideIcons.check;
  static const IconData cross = LucideIcons.x;

  // عام
  static const IconData info = LucideIcons.info;
  static const IconData sparkle = LucideIcons.sparkles;
  static const IconData error = LucideIcons.circleAlert;
}