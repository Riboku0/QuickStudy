import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/app_database.dart';

// ملف محفوظ داخل مساحة التطبيق (بديل عن إنشاء PlatformFile يدويًا)
class _SavedFile {
  final int id;
  final String name;
  final String path;
  final String type;
  final int size;

  const _SavedFile({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'pptx',
  ];

  final List<_SavedFile> savedFiles = [];

  static const List<Map<String, String>> lectures = [
    {
      'title': 'Biology 101 - Cell Respiration',
      'subject': 'Biology',
      'details': '12 study cards  •  5 questions',
    },
    {
      'title': 'Organic Chemistry - Reaction Mechanisms',
      'subject': 'Chemistry',
      'details': '20 study cards  •  8 questions',
    },
    {
      'title': 'Introduction to Microeconomics',
      'subject': 'Economics',
      'details': '15 study cards  •  6 questions',
    },
  ];

  @override
  void initState() {
    super.initState();
    loadSavedFiles();
  }

  // تحميل الملفات المحفوظة من قاعدة البيانات
  Future<void> loadSavedFiles() async {
    try {
      final rows = await AppDatabase.getLectures();
      final List<_SavedFile> restored = [];

      for (final lecture in rows) {
        final path = lecture['filePath'] as String;
        final file = File(path);

        if (!await file.exists()) continue;

        restored.add(
          _SavedFile(
            id: lecture['id'] as int,
            name: lecture['name'] as String,
            path: path,
            type: lecture['fileType'] as String,
            size: await file.length(),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        savedFiles
          ..clear()
          ..addAll(restored);
      });
    } catch (e) {
      debugPrint('Error loading saved files: $e');
    }
  }

  // اختيار الملفات ونسخها إلى مساحة التطبيق وحفظ بياناتها
  Future<void> pickFiles() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (!mounted || files.isEmpty) return;

      final appDirectory = await getApplicationDocumentsDirectory();

      int added = 0;
      int skipped = 0;

      for (final file in files) {
        final ext = p.extension(file.name).replaceFirst('.', '').toLowerCase();

        if (!allowedExtensions.contains(ext) || file.path == null) {
          skipped++;
          continue;
        }

        final sourceFile = File(file.path!);

        if (!await sourceFile.exists()) {
          skipped++;
          continue;
        }

        final sourceSize = await sourceFile.length();

        final alreadyExists = savedFiles.any(
          (item) => item.name == file.name && item.size == sourceSize,
        );

        if (alreadyExists) {
          skipped++;
          continue;
        }

        final savedName =
            '${DateTime.now().microsecondsSinceEpoch}_${p.basename(file.name)}';
        final savedPath = p.join(appDirectory.path, savedName);

        // نسخة خاصة بالتطبيق حتى لا يعتمد على الملف الأصلي
        await sourceFile.copy(savedPath);

        try {
          await AppDatabase.insertLecture(
            name: file.name,
            filePath: savedPath,
            fileType: ext,
            dateAdded: DateTime.now().toIso8601String(),
          );
        } catch (e) {
          // حذف النسخة إذا فشل حفظ بياناتها في قاعدة البيانات
          final copied = File(savedPath);
          if (await copied.exists()) await copied.delete();
          rethrow;
        }

        added++;
      }

      // إعادة التحميل من قاعدة البيانات للحصول على المعرّفات (id)
      await loadSavedFiles();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$added files saved, $skipped skipped.')),
      );
    } catch (e) {
      debugPrint('File saving error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save files. Please try again.'),
        ),
      );
    }
  }

  // حذف الملف من القاعدة والنسخة الداخلية والقائمة
  Future<void> removeFile(_SavedFile file) async {
    try {
      await AppDatabase.deleteLecture(file.id);

      final localFile = File(file.path);
      if (await localFile.exists()) await localFile.delete();

      if (!mounted) return;

      setState(() {
        savedFiles.removeWhere((item) => item.id == file.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted successfully.')),
      );
    } catch (e) {
      debugPrint('File deletion error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the file.')),
      );
    }
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.description;
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF3EFE6);
    const dark = Color(0xFF202020);
    const yellow = Color(0xFFFFD84D);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'HOME',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // بطاقة رفع الملفات
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'SYNTHESIZE NEW MATERIAL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: yellow,
                        child: const Icon(Icons.auto_awesome, size: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Turn your lecture files into summaries, '
                    'flashcards and practice questions.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'PDF  •  DOC  •  DOCX  •  PPTX',
                    style: TextStyle(fontSize: 10),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: pickFiles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('UPLOAD NEW FILES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dark,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'YOUR UPLOADED FILES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (savedFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No files uploaded yet.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),

            // قائمة الملفات المحفوظة
            for (final file in savedFiles)
              Container(
                key: ValueKey(file.id),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(_iconFor(file.type), size: 28),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _formatSize(file.size),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () => removeFile(file),
                      tooltip: 'Remove file',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            const Text(
              'YOUR STUDY STATISTICS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    number: savedFiles.length.toString().padLeft(2, '0'),
                    label: 'FILES',
                  ),
                ),
                const Expanded(
                  child: _StatItem(number: '48', label: 'CARDS'),
                ),
                const Expanded(
                  child: _StatItem(number: '10', label: 'HOURS'),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ANALYSIS ARCHIVES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${lectures.length} ITEMS',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),

            const SizedBox(height: 12),

            for (final lecture in lectures)
              _LectureCard(
                title: lecture['title']!,
                subject: lecture['subject']!,
                details: lecture['details']!,
                onOpen: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening ${lecture['title']}')),
                  );
                },
              ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFDCE5FF),
              child: const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your study materials will appear here '
                      'after they are processed.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String number;
  final String label;

  const _StatItem({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }
}

class _LectureCard extends StatelessWidget {
  final String title;
  final String subject;
  final String details;
  final VoidCallback onOpen;

  const _LectureCard({
    required this.title,
    required this.subject,
    required this.details,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFFFFD84D),
            child: Text(
              subject.toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            details,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF202020),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text(
                'OPEN LECTURE  →',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}