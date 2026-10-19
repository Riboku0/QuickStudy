import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

import '../../../data/services/epub_position_service.dart';
import '../../core/ui/core_ui.dart';

// قارئ كتب EPUB: صفحات بالسحب، يفتح على آخر مكان، الفهرس، حجم الخط، والتقدم.
// ألوانه ثابتة فاتحة مثل عارض PDF.
class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({
    super.key,
    required this.lectureId,
    required this.title,
    required this.filePath,
    this.onProgress,
  });

  final int lectureId;
  final String title;
  final String filePath;

  // 0..1 من الكتاب كله (لتقدم القراءة في المكتبة)
  final ValueChanged<double>? onProgress;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  static const Color _paper = Color(0xFFFBF7F4);
  static const Color _ink = Color(0xFF2A2622);

  final EpubController _controller = EpubController();
  final EpubPositionService _positions = EpubPositionService.instance;

  // يُقرأ قبل فتح الكتاب: آخر مكان وحجم الخط
  late final Future<(String?, int)> _start = _loadStart();

  List<EpubChapter> _chapters = const [];
  bool _loaded = false;
  bool _failed = false;
  double _progress = 0;
  int _fontSize = 18;

  Future<(String?, int)> _loadStart() async {
    final cfi = await _positions.cfiFor(widget.lectureId);
    final size = await _positions.fontSize();
    _fontSize = size;
    return (cfi, size);
  }

  void _onRelocated(EpubLocation location) {
    final progress = location.progress.clamp(0.0, 1.0);
    if (mounted) setState(() => _progress = progress);
    if (location.startCfi.isNotEmpty) {
      _positions.saveCfi(widget.lectureId, location.startCfi);
    }
    widget.onProgress?.call(progress);
  }

  Future<void> _setFontSize(int size) async {
    final clean = size.clamp(12, 34);
    if (clean == _fontSize) return;
    setState(() => _fontSize = clean);
    await _controller.setFontSize(fontSize: clean.toDouble());
    await _positions.saveFontSize(clean);
  }

  void _showContents() {
    final s = AppStrings.of(context);
    // الفهرس بفصوله الفرعية في قائمة واحدة مع إزاحة
    final items = <(EpubChapter, int)>[];
    void add(List<EpubChapter> list, int depth) {
      for (final c in list) {
        items.add((c, depth));
        add(c.subitems, depth + 1);
      }
    }

    add(_chapters, 0);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  s.tableOfContents,
                  style: AppText.title.copyWith(color: _ink),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.noContents,
                    style: AppText.body.copyWith(color: _ink),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final (chapter, depth) = items[i];
                      final title = chapter.title.trim();
                      return ListTile(
                        contentPadding: EdgeInsetsDirectional.only(
                          start: 20.0 + depth * 18,
                          end: 20,
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: textDirectionFor(title),
                          style: (depth == 0 ? AppText.headline : AppText.body)
                              .copyWith(color: _ink),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _controller.display(cfi: chapter.href);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextSize() {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          Future<void> change(int delta) async {
            await _setFontSize(_fontSize + delta);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.textSize, style: AppText.title.copyWith(color: _ink)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SizeButton(
                        label: 'A−',
                        small: true,
                        onTap: _fontSize <= 12 ? null : () => change(-2),
                      ),
                      Expanded(
                        child: Text(
                          '$_fontSize',
                          textAlign: TextAlign.center,
                          style: AppText.display.copyWith(color: _ink),
                        ),
                      ),
                      _SizeButton(
                        label: 'A+',
                        onTap: _fontSize >= 34 ? null : () => change(2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final rtl = textDirectionFor(widget.title) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            // الشريط العلوي: رجوع، العنوان، الفهرس، حجم الخط
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: AppIcon(AppIcons.previous, size: 22, color: _ink),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: textDirectionFor(widget.title),
                      style: AppText.headline.copyWith(color: _ink),
                    ),
                  ),
                  IconButton(
                    tooltip: s.tableOfContents,
                    onPressed: _loaded ? _showContents : null,
                    icon: const Icon(Icons.format_list_bulleted, color: _ink),
                  ),
                  IconButton(
                    tooltip: s.textSize,
                    onPressed: _loaded ? _showTextSize : null,
                    icon: const Icon(Icons.text_fields, color: _ink),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<(String?, int)>(
                future: _start,
                builder: (context, snapshot) {
                  final start = snapshot.data;
                  if (start == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_failed) {
                    return EmptyState(
                      icon: AppIcons.error,
                      title: s.couldNotOpen,
                      message: widget.title,
                    );
                  }

                  return Stack(
                    children: [
                      EpubViewer(
                        epubController: _controller,
                        epubSource: EpubSource.fromFile(File(widget.filePath)),
                        initialCfi: start.$1,
                        displaySettings: EpubDisplaySettings(
                          fontSize: start.$2,
                          flow: EpubFlow.paginated,
                          snap: true,
                          defaultDirection: rtl
                              ? EpubDefaultDirection.rtl
                              : EpubDefaultDirection.ltr,
                          theme: EpubTheme.custom(
                            backgroundDecoration: const BoxDecoration(
                              color: _paper,
                            ),
                            foregroundColor: _ink,
                          ),
                        ),
                        onEpubLoaded: () {
                          if (mounted) setState(() => _loaded = true);
                        },
                        onChaptersLoaded: (chapters) {
                          if (mounted) setState(() => _chapters = chapters);
                        },
                        onRelocated: _onRelocated,
                        onLoadError: (_) {
                          if (mounted) setState(() => _failed = true);
                        },
                      ),
                      if (!_loaded)
                        const ColoredBox(
                          color: _paper,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  );
                },
              ),
            ),

            // الشريط السفلي: السابقة، التقدم، التالية
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loaded ? _controller.prev : null,
                    icon: AppIcon(AppIcons.previous, size: 22, color: _ink),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 4,
                            backgroundColor: _ink.withValues(alpha: 0.08),
                            color: StudyTone.purple,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(_progress * 100).round()}%',
                          style: AppText.caption.copyWith(
                            color: _ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loaded ? _controller.next : null,
                    icon: AppIcon(AppIcons.next, size: 22, color: _ink),
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

class _SizeButton extends StatelessWidget {
  const _SizeButton({required this.label, required this.onTap, this.small = false});

  final String label;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 15 : 21,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2A2622),
          ),
        ),
      ),
    );
  }
}
