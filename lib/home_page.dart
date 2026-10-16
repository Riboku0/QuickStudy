import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/app_database.dart';
import 'home/document_editor_page.dart';
import 'home/document_viewer_page.dart';

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
  static const List<String> allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  static const Color background = Color(0xFFF3EFE6);
  static const Color dark = Color(0xFF202020);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color successGreen = Color(0xFF218838);
  static const Color errorRed = Color(0xFFC62828);

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 8)),
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

  void showMessage(String message, {Color color = dark, IconData? icon}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          // فوق شريط التنقل العائم
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 21),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

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

        await sourceFile.copy(savedPath);

        try {
          await AppDatabase.insertLecture(
            name: file.name,
            filePath: savedPath,
            fileType: ext,
            dateAdded: DateTime.now().toIso8601String(),
          );
        } catch (e) {
          final copied = File(savedPath);
          if (await copied.exists()) await copied.delete();
          rethrow;
        }

        added++;
      }

      await loadSavedFiles();

      if (!mounted) return;

      final skippedNote = skipped > 0
          ? ' ($skipped skipped: duplicate or unsupported)'
          : '';

      if (added > 0) {
        showMessage(
          added == 1
              ? 'File added successfully!$skippedNote'
              : '$added files added successfully!$skippedNote',
          color: successGreen,
          icon: Icons.check_circle_outline,
        );
      } else {
        showMessage(
          'No new files were added.$skippedNote',
          color: const Color(0xFF6D6250),
          icon: Icons.info_outline,
        );
      }
    } catch (e) {
      debugPrint('File saving error: $e');

      showMessage(
        'Could not save files. Please try again.',
        color: errorRed,
        icon: Icons.error_outline,
      );
    }
  }

  // فتح صفحة تحرير المستند
Future<void> openEditor(_SavedFile file) async {
  final viewAsImages =
      ['pdf', 'png', 'jpg', 'jpeg'].contains(
    file.type.toLowerCase(),
  );

  if (!viewAsImages) {
    showMessage(
      'This file type is no longer supported.',
      color: errorRed,
      icon: Icons.error_outline,
    );
    return;
  }

  try {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerPage(
          fileId: file.id,
          fileName: file.name,
          filePath: file.path,
          fileType: file.type,
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    showMessage(
      'Could not open document: $e',
      color: errorRed,
      icon: Icons.error_outline,
    );
  }
}

  // حذف النص المعدّل المرتبط بالملف، حتى لا يظهر لملف جديد يأخذ نفس المعرّف
  Future<void> _deleteEditedText(int fileId) async {
    try {
      final appDirectory = await getApplicationDocumentsDirectory();

      final editedFile = File(
        p.join(appDirectory.path, 'quickstudy_edits', '${fileId}_edited.txt'),
      );

      if (await editedFile.exists()) await editedFile.delete();
    } catch (e) {
      debugPrint('Could not delete edited text: $e');
    }
  }

  Future<void> removeFile(_SavedFile file) async {
    try {
      await AppDatabase.deleteLecture(file.id);
      await _deleteEditedText(file.id);

      final appDirectory = await getApplicationDocumentsDirectory();
      final notesFile = File(
        p.join(appDirectory.path, 'quickstudy_notes', '${file.id}_notes.json'),
      );
      if (await notesFile.exists()) await notesFile.delete();

      final localFile = File(file.path);
      if (await localFile.exists()) await localFile.delete();

      if (!mounted) return;

      setState(() {
        savedFiles.removeWhere((item) => item.id == file.id);
      });

      showMessage(
        'File deleted successfully.',
        color: successGreen,
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      debugPrint('File deletion error: $e');

      showMessage(
        'Could not delete the file.',
        color: errorRed,
        icon: Icons.error_outline,
      );
    }
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  _TypeStyle _styleFor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return const _TypeStyle(Color(0xFFFDE4E1), Color(0xFFC62828));
  
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const _TypeStyle(Color(0xFFDDEBFF), Color(0xFF1565C0));
      default:
        return const _TypeStyle(Color(0xFFE3E8FF), Color(0xFF3949AB));
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
    var step = 0;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _FadeIn(
              index: step++,
              child: const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 20),
                child: Text(
                  'HOME',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: dark,
                  ),
                ),
              ),
            ),

            // Upload card
            _FadeIn(
              index: step++,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFFFF6CF)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'SYNTHESIZE NEW MATERIAL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: yellow,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55FFD84D),
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Turn your lecture files into summaries, '
                      'flashcards and practice questions.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final label in const [
  'PDF',
  'PNG',
  'JPG',
  'JPEG',
])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: pickFiles,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text(
                          'UPLOAD NEW FILES',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            _FadeIn(
              index: step++,
              child: _SectionHeader(
                title: 'YOUR UPLOADED FILES',
                trailing: savedFiles.isEmpty ? null : '${savedFiles.length}',
              ),
            ),

            const SizedBox(height: 14),

            if (savedFiles.isEmpty)
              _FadeIn(
                index: step++,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 36,
                        color: Colors.black38,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No files uploaded yet.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

            // Saved files
            for (final file in savedFiles)
              _FadeIn(
                key: ValueKey('file_${file.id}'),
                index: step++,
                child: _FileTile(
                  name: file.name,
                  ext: file.type.toUpperCase(),
                  sizeText: _formatSize(file.size),
                  icon: _iconFor(file.type),
                  style: _styleFor(file.type),
                  onOpen: () => openEditor(file),
                  onDelete: () => removeFile(file),
                ),
              ),

            const SizedBox(height: 18),

            _FadeIn(
              index: step++,
              child: const _SectionHeader(title: 'YOUR STUDY STATISTICS'),
            ),

            const SizedBox(height: 14),

            _FadeIn(
              index: step++,
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.folder_copy_rounded,
                      iconBg: const Color(0xFFFFF1B8),
                      iconFg: const Color(0xFF8A6D00),
                      number: savedFiles.length.toString().padLeft(2, '0'),
                      label: 'FILES',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _StatCard(
                      icon: Icons.style_rounded,
                      iconBg: Color(0xFFDDEBFF),
                      iconFg: Color(0xFF1565C0),
                      number: '48',
                      label: 'CARDS',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _StatCard(
                      icon: Icons.schedule_rounded,
                      iconBg: Color(0xFFDDF3E2),
                      iconFg: Color(0xFF2E7D32),
                      number: '10',
                      label: 'HOURS',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _FadeIn(
              index: step++,
              child: _SectionHeader(
                title: 'ANALYSIS ARCHIVES',
                trailing: '${lectures.length} ITEMS',
              ),
            ),

            const SizedBox(height: 14),

            for (final lecture in lectures)
              _FadeIn(
                index: step++,
                child: _LectureCard(
                  title: lecture['title']!,
                  subject: lecture['subject']!,
                  details: lecture['details']!,
                  onOpen: () {
                    showMessage('Opening ${lecture['title']}');
                  },
                ),
              ),

            const SizedBox(height: 4),

            _FadeIn(
              index: step++,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE5FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFF3949AB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your study materials will appear here '
                        'after they are processed.',
                        style: TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عناصر مساعدة
// ---------------------------------------------------------------------------

class _TypeStyle {
  final Color bg;
  final Color fg;

  const _TypeStyle(this.bg, this.fg);
}

// ظهور تدريجي مع انزلاق خفيف
class _FadeIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _FadeIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + math.min(index, 8) * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD84D),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  final String name;
  final String ext;
  final String sizeText;
  final IconData icon;
  final _TypeStyle style;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _FileTile({
    required this.name,
    required this.ext,
    required this.sizeText,
    required this.icon,
    required this.style,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: _HomePageState.softShadow,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: style.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: style.fg, size: 26),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: style.bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ext,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: style.fg,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sizeText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  _RoundIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit document',
                    bg: const Color(0xFFF1EEE6),
                    fg: const Color(0xFF202020),
                    onTap: onOpen,
                  ),

                  const SizedBox(width: 8),

                  _RoundIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Remove file',
                    bg: const Color(0xFFFDE4E1),
                    fg: const Color(0xFFC62828),
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String number;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _HomePageState.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: iconFg),
          ),
          const SizedBox(height: 14),
          Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.black54,
            ),
          ),
        ],
      ),
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

  // لون مختلف لكل مادة
  _TypeStyle get _subjectStyle {
    switch (subject.toLowerCase()) {
      case 'biology':
        return const _TypeStyle(Color(0xFFDDF3E2), Color(0xFF2E7D32));
      case 'chemistry':
        return const _TypeStyle(Color(0xFFEBDDF8), Color(0xFF6A1B9A));
      case 'economics':
        return const _TypeStyle(Color(0xFFFFE9D0), Color(0xFFE65100));
      default:
        return const _TypeStyle(Color(0xFFFFE98A), Color(0xFF202020));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _subjectStyle;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: _HomePageState.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: style.fg,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  subject.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: style.fg,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.style_outlined, size: 15, color: Colors.black45),
              const SizedBox(width: 6),
              Text(
                details,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF202020),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OPEN LECTURE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
