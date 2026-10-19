import 'package:flutter/foundation.dart';

import '../../../data/repositories/lecture/lecture_repository.dart';
import '../../../data/repositories/settings/settings_repository.dart';
import '../../../data/services/file_picker_service.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';
import 'home_view_model.dart';

// نتيجة الحفظ (الواجهة تحوّلها لرسالة)
enum AddBookOutcome { added, duplicate, needsFile, needsName }

// نموذج إضافة كتاب للمكتبة: الملف، الاسم (يبدأ باسم الملف)، والتصنيف.
class AddBookViewModel extends ChangeNotifier {
  AddBookViewModel({
    required LectureRepository lectures,
    required FilePickerService picker,
    required SettingsRepository settings,
    String? initialCategory,
  }) : _lectures = lectures,
       _picker = picker,
       _settings = settings,
       _category = initialCategory {
    pickFile = Command0<void>(_pickFile);
    save = Command0<AddBookOutcome>(_save);
    _settings.addListener(notifyListeners);
  }

  final LectureRepository _lectures;
  final FilePickerService _picker;
  final SettingsRepository _settings;

  late final Command0<void> pickFile;
  late final Command0<AddBookOutcome> save;

  SelectedFile? _file;
  String _name = '';
  String? _category;

  SelectedFile? get file => _file;
  String get name => _name;
  String? get category => _category;

  // الاسم المقترح بعد اختيار الملف (الواجهة تضعه في الحقل)
  String get suggestedName {
    final n = _file?.name ?? '';
    final dot = n.lastIndexOf('.');
    return dot > 0 ? n.substring(0, dot) : n;
  }

  List<String> get categories => [
    ...HomeViewModel.categories,
    ..._settings.bookCategories,
  ];

  void setName(String value) => _name = value;

  void setCategory(String? value) {
    if (value == _category) return;
    _category = value;
    notifyListeners();
  }

  // يضيف التصنيف ويختاره مباشرة
  Future<void> addCategory(String name) async {
    final added = await _settings.addBookCategory(
      name,
      taken: HomeViewModel.categories,
    );
    if (added != null) setCategory(added);
  }

  Future<Result<void>> _pickFile() async {
    try {
      final picked = await _picker.pickLectureFiles(
        extensions: FilePickerService.books,
      );
      if (picked.isEmpty) return const Result.ok(null);
      _file = picked.first;
      _name = suggestedName;
      notifyListeners();
      return const Result.ok(null);
    } catch (e) {
      return Result.error(asException(e));
    }
  }

  Future<Result<AddBookOutcome>> _save() async {
    final file = _file;
    if (file == null) return const Result.ok(AddBookOutcome.needsFile);

    // أحرف لا يقبلها اسم ملف
    final clean = _name.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    if (clean.isEmpty) return const Result.ok(AddBookOutcome.needsName);

    final ext = file.name.split('.').last.toLowerCase();
    final ids = <int>[];
    final result = await _lectures.importFiles(
      [SelectedFile(name: '$clean.$ext', path: file.path)],
      ids: ids,
    );

    switch (result) {
      case Err(:final error):
        return Result.error(error);
      case Ok():
        if (ids.isEmpty) return const Result.ok(AddBookOutcome.duplicate);
    }

    final category = _category;
    if (category != null) {
      final lecture = _lectures.lectures.where((l) => l.id == ids.first);
      if (lecture.isNotEmpty) {
        await _lectures.setCategory(lecture.first, category);
      }
    }
    return const Result.ok(AddBookOutcome.added);
  }

  @override
  void dispose() {
    _settings.removeListener(notifyListeners);
    pickFile.dispose();
    save.dispose();
    super.dispose();
  }
}
