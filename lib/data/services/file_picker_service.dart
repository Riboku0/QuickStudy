import 'package:file_picker/file_picker.dart';

// ملف اختاره المستخدم من الهاتف
class SelectedFile {
  const SelectedFile({required this.name, required this.path});

  final String name;
  final String? path;
}

// نافذة اختيار الملفات من النظام
class FilePickerService {
  static const List<String> allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  static const List<String> pdfOnly = ['pdf'];

  Future<List<SelectedFile>> pickLectureFiles({
    List<String> extensions = allowedExtensions,
  }) async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    return [
      for (final file in files) SelectedFile(name: file.name, path: file.path),
    ];
  }
}
