import 'package:file_picker/file_picker.dart';

// ملف اختاره المستخدم من الهاتف
class SelectedFile {
  const SelectedFile({required this.name, required this.path});

  final String name;
  final String? path;
}

// نافذة اختيار الملفات من النظام
class FilePickerService {
  static const List<String> allowedExtensions = [
    'pdf',
    'epub',
    'png',
    'jpg',
    'jpeg',
  ];

  static const List<String> pdfOnly = ['pdf'];
  static const List<String> epubOnly = ['epub'];

  // الكتب: PDF أو EPUB (المكتبة وشباتر المذاكرة)
  static const List<String> books = ['pdf', 'epub'];

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

  // صورة واحدة من المعرض (غلاف المادة). null عند الإلغاء
  Future<String?> pickImage() async {
    final List<PlatformFile> files =
        await FilePicker.pickFiles(type: FileType.image);
    return files.isEmpty ? null : files.first.path;
  }
}
