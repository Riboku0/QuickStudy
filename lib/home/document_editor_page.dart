import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/file_text_extractor.dart';

class DocumentEditorPage extends StatefulWidget {
  final int fileId;
  final String fileName;
  final String filePath;

  const DocumentEditorPage({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.filePath,
  });

  @override
  State<DocumentEditorPage> createState() =>
      _DocumentEditorPageState();
}

class _DocumentEditorPageState extends State<DocumentEditorPage> {
  static const Color background = Color(0xFFF3EFE6);
  static const Color dark = Color(0xFF202020);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color green = Color(0xFF218838);
  static const Color red = Color(0xFFC62828);

  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  bool _hasChanges = false;

  String? _error;
  String? _savedText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkChanges);
    _loadDocument();
  }

  void _checkChanges() {
    if (!mounted || _savedText == null) return;

    final changed = _controller.text != _savedText;

    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  // مجلد حفظ التعديلات
  Future<Directory> _getEditsDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final directory = Directory(
      p.join(appDirectory.path, 'quickstudy_edits'),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  // ملف النص المعدل لكل مستند
  Future<File> _getEditedTextFile() async {
    final directory = await _getEditsDirectory();

    return File(
      p.join(directory.path, '${widget.fileId}_edited.txt'),
    );
  }

  // تحميل التعديل المحفوظ أولًا، وإلا قراءة الملف الأصلي
  Future<void> _loadDocument() async {
    try {
      final editedFile = await _getEditedTextFile();

      String text;

      if (await editedFile.exists()) {
        text = await editedFile.readAsString();
      } else {
        final originalFile = File(widget.filePath);

        if (!await originalFile.exists()) {
          throw Exception(
            'The original document could not be found.',
          );
        }

        text = await FileTextExtractor.extractText(
          path: widget.filePath,
        );
      }

      if (!mounted) return;

      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

      setState(() {
        _savedText = text;
        _hasChanges = false;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // حفظ التعديلات في ملف مستقل
  Future<void> _saveChanges() async {
    if (_saving || _loading || _error != null) return;

    setState(() => _saving = true);

    try {
      final editedFile = await _getEditedTextFile();

      await editedFile.writeAsString(
        _controller.text,
        flush: true,
      );

      if (!mounted) return;

      setState(() {
        _savedText = _controller.text;
        _hasChanges = false;
      });

      _showMessage(
        'Changes saved successfully.',
        color: green,
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      _showMessage(
        'Could not save changes: $e',
        color: red,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // تصدير المحتوى الحالي إلى PDF
  Future<void> _exportPdf() async {
    if (_exporting || _loading || _error != null) return;

    setState(() => _exporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(36),
          build: (context) => [
            pw.Text(
              p.basenameWithoutExtension(widget.fileName),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              _controller.text,
              style: const pw.TextStyle(
                fontSize: 11,
                lineSpacing: 4,
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      final originalName =
          p.basenameWithoutExtension(widget.fileName);

      // الإصدار الجديد: saveFile دالة static (بدون .platform)
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save edited PDF',
        fileName: '${originalName}_edited.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted) return;

      if (outputPath == null) {
        _showMessage(
          'Export cancelled.',
          icon: Icons.info_outline,
        );
      } else {
        _showMessage(
          'PDF exported successfully.',
          color: green,
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      _showMessage(
        'PDF export failed: $e',
        color: red,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _showMessage(
    String message, {
    Color color = dark,
    IconData? icon,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<bool> _confirmExit() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes. Do you want to leave this page?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void dispose() {
    _controller.removeListener(_checkChanges);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final leave = await _confirmExit();

        if (leave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: dark,
          elevation: 0,
          title: const Text(
            'DOCUMENT EDITOR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Save changes',
              onPressed: _loading ||
                      _saving ||
                      _error != null
                  ? null
                  : _saveChanges,
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: 'Export PDF',
              onPressed: _loading ||
                      _exporting ||
                      _error != null
                  ? null
                  : _exportPdf,
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? _buildError()
                : _buildEditor(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not open this document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadDocument();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _hasChanges
                              ? 'Unsaved changes'
                              : 'All changes saved',
                          style: TextStyle(
                            color: _hasChanges ? red : green,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'EDIT YOUR CONTENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  readOnly: false,
                  enabled: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  enableInteractiveSelection: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Document content...',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: dark,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving || _loading
                    ? null
                    : _saveChanges,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? 'Saving...' : 'SAVE CHANGES',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _exporting || _loading
                    ? null
                    : _exportPdf,
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                ),
                label: Text(
                  _exporting
                      ? 'Exporting...'
                      : 'EXPORT PDF',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: yellow,
                  foregroundColor: dark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}