import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/services/thumbnail_service.dart';
import '../../../domain/models/lecture.dart';
import '../themes/app_icons.dart';
import '../themes/app_theme.dart';
import 'app_icon.dart';

// معاينة حقيقية لمحتوى الملف:
// - الصور: الصورة نفسها مصغّرة (cacheWidth يمنع تحميلها بالحجم الكامل)
// - PDF: الصفحة الأولى، تُرسم مرة واحدة وتُحفظ
// أثناء التحميل أو عند الخطأ تظهر أيقونة النوع على خلفية ملونة.
class FileThumbnail extends StatefulWidget {
  const FileThumbnail({
    super.key,
    required this.lecture,
    required this.width,
    required this.height,
    this.radius = 14,
    this.showBadge = true,
  });

  final Lecture lecture;
  final double width;
  final double height;
  final double radius;
  final bool showBadge; // شارة صغيرة PDF/JPG في الزاوية

  @override
  State<FileThumbnail> createState() => _FileThumbnailState();
}

class _FileThumbnailState extends State<FileThumbnail> {
  Future<Uint8List?>? _pdfPage;
  Uint8List? _cached; // معاينة جاهزة في الذاكرة
  bool _retried = false; // إعادة رسم واحدة فقط عند تلف المعاينة

  @override
  void initState() {
    super.initState();
    _loadPdfIfNeeded();
  }

  @override
  void didUpdateWidget(FileThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lecture.filePath != widget.lecture.filePath) {
      _pdfPage = null;
      _cached = null;
      _loadPdfIfNeeded();
    }
  }

  void _loadPdfIfNeeded() {
    final lecture = widget.lecture;
    if (!lecture.isPdf || !lecture.exists) return;
    try {
      _cached = ThumbnailService.instance.peek(lecture.filePath);
      _pdfPage = ThumbnailService.instance.pdfFirstPage(lecture.filePath);
    } catch (_) {
      _pdfPage = Future.value(null); // تظهر الأيقونة بدل المعاينة
    }
  }

  // المعاينة المحفوظة لم تُفتح كصورة: نحذفها ونرسمها مرة أخرى
  void _retryAfterBadImage(Object error) {
    if (_retried) return;
    _retried = true;
    final path = widget.lecture.filePath;
    debugPrint('[Thumbnail] image decode failed for $path: $error');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ThumbnailService.instance.evict(path);
      if (!mounted) return;
      setState(() {
        _cached = null;
        _pdfPage = ThumbnailService.instance.pdfFirstPage(path);
      });
    });
  }

  Tint get _tint => widget.lecture.isPdf
      ? Tint.pdf
      : (widget.lecture.isImage ? Tint.image : Tint.neutral);

  @override
  Widget build(BuildContext context) {
    final lecture = widget.lecture;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (widget.width * ratio).round();

    Widget content;
    if (!lecture.exists) {
      content = _placeholder();
    } else if (lecture.isImage) {
      content = Image.file(
        File(lecture.filePath),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        frameBuilder: _fadeIn,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else if (lecture.isPdf) {
      content = FutureBuilder<Uint8List?>(
        future: _pdfPage,
        initialData: _cached,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return _placeholder(loading: !snapshot.hasError &&
              snapshot.connectionState != ConnectionState.done);

          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // أعلى الصفحة فيه العنوان غالبًا
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            frameBuilder: _fadeIn,
            errorBuilder: (_, error, _) {
              _retryAfterBadImage(error);
              return _placeholder();
            },
          );
        },
      );
    } else {
      content = _placeholder();
    }

    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: lecture.isPdf ? Colors.white : _tint.background,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: AppColors.line),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (widget.showBadge && lecture.exists)
              PositionedDirectional(
                start: 5,
                bottom: 5,
                child: _TypeBadge(
                  label: lecture.fileType.toUpperCase(),
                  color: _tint.foreground,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    final iconSize = (widget.width < widget.height ? widget.width : widget.height) * 0.38;
    final icon = widget.lecture.isPdf
        ? AppIcons.pdf
        : (widget.lecture.isImage ? AppIcons.image : AppIcons.file);

    return ColoredBox(
      color: _tint.background,
      child: Center(
        child: AnimatedOpacity(
          opacity: loading ? 0.45 : 1,
          duration: const Duration(milliseconds: 300),
          child: AppIcon(icon, size: iconSize.clamp(16, 40).toDouble(), color: _tint.foreground),
        ),
      ),
    );
  }

  static Widget _fadeIn(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
    );
  }
}
