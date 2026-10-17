import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/app_database.dart';
import 'home/document_viewer_page.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

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

  bool get isPdf => type.toLowerCase() == 'pdf';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenTab});
   final ValueChanged<int>? onOpenTab;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg'];

  final List<_SavedFile> savedFiles = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // تحديث تلقائي عند الحذف أو الإضافة من صفحة أخرى (مثل Library)
    AppDatabase.changes.addListener(loadSavedFiles);
    loadSavedFiles();
  }

  @override
  void dispose() {
    AppDatabase.changes.removeListener(loadSavedFiles);
    super.dispose();
  }

  // ------------------------- البيانات -------------------------

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

  void showMessage(String message, {MessageTone tone = MessageTone.neutral}) {
    if (!mounted) return;
    showAppMessage(context, message, tone: tone);
  }

  Future<void> pickFiles() async {
    if (_uploading) return;

    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (!mounted || files.isEmpty) return;

      setState(() => _uploading = true);

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
          ? ' $skipped skipped (already added or not supported).'
          : '';

      if (added > 0) {
        showMessage(
          added == 1
              ? 'File added.$skippedNote'
              : '$added files added.$skippedNote',
          tone: MessageTone.success,
        );
      } else {
        showMessage('No new files added.$skippedNote');
      }
    } catch (e) {
      debugPrint('File saving error: $e');

      showMessage(
        'The files were not saved. Try again.',
        tone: MessageTone.error,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // فتح الملف في العارض
  Future<void> openFile(_SavedFile file) async {
    if (!allowedExtensions.contains(file.type.toLowerCase())) {
      showMessage('This file type cannot be opened.', tone: MessageTone.error);
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
      showMessage('The file did not open: $e', tone: MessageTone.error);
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
    if (!await confirmDeleteFile(context, file.name)) return;

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

      showMessage('File deleted.', tone: MessageTone.success);
    } catch (e) {
      debugPrint('File deletion error: $e');
      showMessage('The file was not deleted. Try again.',
          tone: MessageTone.error);
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  // ------------------------- الواجهة -------------------------

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    return ListView(
      // insets.bottom يشمل شريط التنقل العائم
      padding: EdgeInsets.fromLTRB(20, insets.top + 20, 20, insets.bottom + 24),
      children: [
        ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageTitle('Home'),
              const SizedBox(height: 24),
              _UploadCard(uploading: _uploading, onUpload: pickFiles),
              const SizedBox(height: 32),
              SectionHeader(
                'Your files',
                trailing: savedFiles.isEmpty ? null : '${savedFiles.length}',
              ),
              const SizedBox(height: 12),
              if (savedFiles.isEmpty)
                const _EmptyFiles()
              else
                for (final file in savedFiles)
                  Padding(
                    key: ValueKey('file_${file.id}'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FileTile(
                      name: file.name,
                      ext: file.type.toUpperCase(),
                      sizeText: _formatSize(file.size),
                      style: file.isPdf ? SubjectStyle.pdf : SubjectStyle.image,
                      icon: file.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      onOpen: () => openFile(file),
                      onDelete: () => removeFile(file),
                    ),
                  ),
              const SizedBox(height: 20),
              const InfoNote(
                'Summaries, flashcards and quizzes made from your files are '
                'coming next. Until then, try the sample decks in Study.',
                icon: Icons.auto_awesome_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة الرفع (البطاقة الداكنة الرئيسية في Home)
// ---------------------------------------------------------------------------

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.uploading, required this.onUpload});

  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTokens.heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.surface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(t.radiusSmall),
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    color: t.accent,
                    size: 24,
                  ),
                ),
                const Spacer(),
                for (final format in const ['PDF', 'PNG', 'JPG'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: AppPill(
                      format,
                      background: t.surface.withValues(alpha: 0.1),
                      foreground: t.surface.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Add lecture files',
              style: AppText.title.copyWith(color: t.surface),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload PDFs or photos of your notes to read, annotate and '
              'study them in one place.',
              style: AppText.body.copyWith(
                color: t.surface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: uploading ? 'Adding files…' : 'Upload files',
              icon: Icons.add_rounded,
              kind: AppButtonKind.accent,
              onPressed: uploading ? null : onUpload,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  const _EmptyFiles();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(t.radiusMedium),
        border: Border.all(color: t.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: t.chip, shape: BoxShape.circle),
            child: Icon(Icons.folder_open_rounded, color: t.muted, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('No files yet', style: AppText.headline),
          const SizedBox(height: 4),
          Text(
            'Files you upload show up here.',
            style: AppText.caption.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final String name;
  final String ext;
  final String sizeText;
  final IconData icon;
  final SubjectStyle style;
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
    final t = AppTokens.of(context);

    return SoftCard(
      onTap: onOpen,
      radius: t.radiusMedium,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(t.radiusSmall),
            ),
            child: Icon(icon, color: style.foreground, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: textDirectionFor(name),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AppPill(
                      ext,
                      background: style.background,
                      foreground: style.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sizeText,
                      style: AppText.caption.copyWith(
                        color: t.muted,
                        fontFeatures: AppText.tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete file',
            size: 44,
            background: t.wrongSoft,
            foreground: t.wrong,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
