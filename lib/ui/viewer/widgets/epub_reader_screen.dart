import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/reader/reader_settings_repository.dart';
import '../../../data/services/epub_annotation_service.dart';
import '../../../data/services/epub_metadata_service.dart';
import '../../../data/services/epub_position_service.dart';
import '../../../domain/models/reader_settings.dart';
import '../../core/ui/core_ui.dart';
import 'reader_settings_sheet.dart';

class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({super.key, required this.lectureId, required this.title, required this.filePath, this.onProgress});
  final int lectureId;
  final String title;
  final String filePath;
  final ValueChanged<double>? onProgress;
  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubStart {
  const _EpubStart(this.cfi, this.fontSize, this.direction, this.locations);
  final String? cfi;
  final int fontSize;
  final String direction;
  final String? locations;
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  static const _colors = [Color(0xFFFFD54F), Color(0xFF81C784), Color(0xFF64B5F6), Color(0xFFF48FB1), Color(0xFFCE93D8)];
  final _controller = EpubController();
  final _positions = EpubPositionService.instance;
  final _store = EpubAnnotationService.instance;
  late final ReaderSettingsRepository _reader;
  late final Future<_EpubStart> _start;
  List<EpubChapter> _chapters = const [];
  List<EpubAnnotation> _annotations = const [];
  bool _loaded = false;
  bool _failed = false;
  double _progress = 0;
  String _direction = 'ltr';
  String? _currentCfi;
  String? _selectedText;
  String? _selectedCfi;
  Rect? _selectionRect;
  Rect? _selectionView;

  ReaderSettings get _settings => _reader.settings;
  Color get _paper => _settings.paperColor;
  Color get _ink => _settings.inkColor;
  EpubTheme get _theme => EpubTheme.custom(
    backgroundDecoration: BoxDecoration(color: _paper),
    foregroundColor: _ink,
    customCss: {
      'body': {'background': '#${_paper.toARGB32().toRadixString(16).substring(2)} !important', 'color': '#${_ink.toARGB32().toRadixString(16).substring(2)} !important'},
      'html': {'text-rendering': 'optimizeLegibility'},
    },
  );

  @override
  void initState() {
    super.initState();
    _reader = context.read<ReaderSettingsRepository>()..addListener(_onSettings);
    _start = _loadStart();
  }

  Future<_EpubStart> _loadStart() async {
    final savedDirection = await _positions.directionFor(widget.lectureId);
    final metadata = await EpubMetadataService.read(widget.filePath);
    _annotations = await _store.forLecture(widget.lectureId);
    _direction = savedDirection ?? metadata.direction ?? 'ltr';
    return _EpubStart(
      await _positions.cfiFor(widget.lectureId),
      await _positions.fontSize(),
      _direction,
      await _positions.locationsFor(widget.lectureId),
    );
  }

  @override
  void dispose() {
    _reader.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (!mounted) return;
    setState(() {});
    if (_loaded) _controller.updateTheme(theme: _theme);
  }

  void _onRelocated(EpubLocation location) {
    final progress = location.progress.clamp(0.0, 1.0);
    _currentCfi = location.startCfi;
    if (mounted) setState(() => _progress = progress);
    if (location.startCfi.isNotEmpty) _positions.saveCfi(widget.lectureId, location.startCfi);
    widget.onProgress?.call(progress);
  }

  void _paint(EpubAnnotation a) {
    final color = Color(a.color);
    switch (a.kind) {
      case EpubAnnotationKind.highlight:
      case EpubAnnotationKind.note:
        _controller.addHighlight(cfi: a.cfi, color: color);
      case EpubAnnotationKind.underline:
        _controller.addUnderline(cfi: a.cfi, color: color);
      case EpubAnnotationKind.strike:
        _controller.addStrike(cfi: a.cfi, color: color);
      case EpubAnnotationKind.wavy:
        _controller.addWavy(cfi: a.cfi, color: color);
      case EpubAnnotationKind.bookmark:
        break;
    }
  }

  void _erase(EpubAnnotation a) {
    switch (a.kind) {
      case EpubAnnotationKind.highlight:
      case EpubAnnotationKind.note:
        _controller.removeHighlight(cfi: a.cfi);
      case EpubAnnotationKind.underline:
        _controller.removeUnderline(cfi: a.cfi);
      case EpubAnnotationKind.strike:
        _controller.removeStrike(cfi: a.cfi);
      case EpubAnnotationKind.wavy:
        _controller.removeWavy(cfi: a.cfi);
      case EpubAnnotationKind.bookmark:
        break;
    }
  }

  void _clearSelection() {
    if (_loaded) _controller.clearSelection();
    if (mounted) setState(() { _selectedText = null; _selectedCfi = null; _selectionRect = null; _selectionView = null; });
  }

  Future<void> _addAnnotation(EpubAnnotationKind kind, Color color, {String? note}) async {
    final cfi = _selectedCfi;
    final text = _selectedText;
    if (cfi == null || text == null) return;
    final a = EpubAnnotation(
      id: '${DateTime.now().microsecondsSinceEpoch}', lectureId: widget.lectureId,
      kind: kind, cfi: cfi, text: text, color: color.toARGB32(), createdAt: DateTime.now(), note: note,
    );
    await _store.save(a);
    _paint(a);
    if (mounted) setState(() => _annotations = [..._annotations, a]);
    _clearSelection();
  }

  Future<String?> _askNote([String initial = '']) async {
    var value = initial;
    return showDialog<String>(context: context, builder: (dialogContext) {
      final s = AppStrings.of(dialogContext);
      return AlertDialog(
        title: Text(s.markNoteTitle),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          onChanged: (text) => value = text,
          decoration: InputDecoration(hintText: s.markNoteHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, value.trim()), child: Text(s.save)),
        ],
      );
    });
  }

  Future<void> _addNote() async {
    final note = await _askNote();
    if (note != null && note.isNotEmpty) await _addAnnotation(EpubAnnotationKind.note, _colors.first, note: note);
  }

  Future<Color?> _chooseColor() => showModalBottomSheet<Color>(context: context, backgroundColor: _paper, builder: (sheetContext) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(20), child: Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 14, children: [
        for (final color in _colors) Semantics(button: true, label: AppStrings.of(sheetContext).backgroundColor, child: InkWell(
          borderRadius: BorderRadius.circular(24), onTap: () => Navigator.pop(sheetContext, color), child: CircleAvatar(backgroundColor: color, radius: 22),
        )),
      ])),
    ));

  Future<void> _pickStyle(EpubAnnotationKind kind) async {
    final color = await _chooseColor();
    if (color != null) await _addAnnotation(kind, color);
  }

  Future<void> _externalAction(String action) async {
    final text = _selectedText?.trim();
    if (text == null || text.isEmpty) return;
    if (action == 'share') {
      await SharePlus.instance.share(ShareParams(text: text));
      return;
    }
    final target = Localizations.localeOf(context).languageCode;
    final uri = switch (action) {
      'google' => Uri.parse('https://translate.google.com/?sl=auto&tl=$target&text=${Uri.encodeComponent(text)}&op=translate'),
      'deepl' => Uri.parse('https://www.deepl.com/translator#auto/$target/${Uri.encodeComponent(text)}'),
      _ => Uri.parse('https://chatgpt.com/?q=${Uri.encodeComponent(AppStrings.of(context).chatGptPrompt(text))}'),
    };
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _addBookmark() async {
    final cfi = _currentCfi;
    if (cfi == null || cfi.isEmpty) return;
    final page = await _controller.extractCurrentPageText();
    final a = EpubAnnotation(
      id: '${DateTime.now().microsecondsSinceEpoch}', lectureId: widget.lectureId,
      kind: EpubAnnotationKind.bookmark, cfi: cfi, text: page.text?.trim() ?? '', color: _colors.first.toARGB32(), createdAt: DateTime.now(),
    );
    await _store.save(a);
    if (mounted) { setState(() => _annotations = [..._annotations, a]); showAppMessage(context, AppStrings.of(context).bookmarkAdded); }
  }

  Future<void> _delete(EpubAnnotation a) async {
    _erase(a);
    await _store.remove(a.id);
    if (mounted) setState(() => _annotations = _annotations.where((item) => item.id != a.id).toList());
  }

  Future<void> _edit(EpubAnnotation a) async {
    if (a.kind == EpubAnnotationKind.note) {
      final note = await _askNote(a.note ?? '');
      if (note == null || note.isEmpty) return;
      final updated = a.copyWith(note: note);
      await _store.save(updated);
      if (mounted) setState(() => _annotations = _annotations.map((item) => item.id == a.id ? updated : item).toList());
      return;
    }
    if (a.kind == EpubAnnotationKind.bookmark) return;
    final color = await _chooseColor();
    if (color == null) return;
    _selectedCfi = a.cfi;
    _selectedText = a.text;
    await _delete(a);
    await _addAnnotation(a.kind, color);
  }

  IconData _iconFor(EpubAnnotationKind kind) => switch (kind) {
    EpubAnnotationKind.highlight => Icons.highlight,
    EpubAnnotationKind.underline => Icons.format_underline,
    EpubAnnotationKind.strike => Icons.format_strikethrough,
    EpubAnnotationKind.wavy => Icons.gesture,
    EpubAnnotationKind.note => Icons.note_alt_outlined,
    EpubAnnotationKind.bookmark => Icons.bookmark,
  };

  void _showLibrary() {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(context: context, backgroundColor: _paper, isScrollControlled: true, builder: (sheetContext) => SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .72,
      child: Column(children: [
        ListTile(title: Text(s.epubAnnotations, style: AppText.title.copyWith(color: _ink))),
        Expanded(child: _annotations.isEmpty ? Center(child: Text(s.epubAnnotationsEmpty, style: TextStyle(color: _ink))) : ListView.builder(
          itemCount: _annotations.length,
          itemBuilder: (_, i) {
            final item = _annotations[i];
            return ListTile(
              leading: Icon(_iconFor(item.kind), color: Color(item.color)),
              title: Text(item.note?.isNotEmpty == true ? item.note! : item.text, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: textDirectionFor(item.text)),
              onTap: () { Navigator.pop(sheetContext); _controller.display(cfi: item.cfi); },
              trailing: PopupMenuButton<String>(onSelected: (value) => value == 'delete' ? _delete(item) : _edit(item), itemBuilder: (_) => [
                if (item.kind != EpubAnnotationKind.bookmark) PopupMenuItem(value: 'edit', child: Text(s.editText)),
                PopupMenuItem(value: 'delete', child: Text(s.delete)),
              ]),
            );
          },
        )),
      ]),
    )));
  }

  Future<void> _showSearch() async {
    final s = AppStrings.of(context);
    var results = <EpubSearchResult>[];
    var searching = false;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: _paper, builder: (sheetContext) => StatefulBuilder(builder: (_, setSheet) => SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .78,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          autofocus: true, textInputAction: TextInputAction.search,
          decoration: InputDecoration(labelText: s.epubSearch, hintText: s.epubSearchHint, suffixIcon: const Icon(Icons.search)),
          onSubmitted: (query) async { setSheet(() => searching = true); final found = await _controller.search(query: query.trim()); setSheet(() { results = found; searching = false; }); },
        )),
        if (searching) const LinearProgressIndicator(),
        Expanded(child: results.isEmpty ? Center(child: Text(s.epubNoSearchResults, style: TextStyle(color: _ink))) : ListView.builder(
          itemCount: results.length,
          itemBuilder: (_, i) => ListTile(title: Text(results[i].excerpt, textDirection: textDirectionFor(results[i].excerpt)), onTap: () { Navigator.pop(sheetContext); _controller.display(cfi: results[i].cfi); }),
        )),
      ]),
    ))));
  }

  void _showContents() {
    final items = <(EpubChapter, int)>[];
    void add(List<EpubChapter> chapters, int depth) { for (final chapter in chapters) { items.add((chapter, depth)); add(chapter.subitems, depth + 1); } }
    add(_chapters, 0);
    showModalBottomSheet<void>(context: context, backgroundColor: _paper, builder: (sheetContext) => SafeArea(child: ListView(shrinkWrap: true, children: [
      ListTile(title: Text(AppStrings.of(context).tableOfContents, style: AppText.title.copyWith(color: _ink))),
      for (final (chapter, depth) in items) ListTile(
        contentPadding: EdgeInsetsDirectional.only(start: 20 + depth * 18, end: 20),
        title: Text(chapter.title, textDirection: textDirectionFor(chapter.title)),
        onTap: () { Navigator.pop(sheetContext); _controller.display(cfi: chapter.href); },
      ),
    ])));
  }

  Future<void> _setDirection(String value) async {
    final metadata = await EpubMetadataService.read(widget.filePath);
    final direction = value == 'auto' ? (metadata.direction ?? 'ltr') : value;
    await _positions.saveDirection(widget.lectureId, value == 'auto' ? null : value);
    await _controller.setDirection(direction: direction == 'rtl' ? EpubDefaultDirection.rtl : EpubDefaultDirection.ltr);
    if (!mounted) return;
    setState(() => _direction = direction);
    showAppMessage(context, AppStrings.of(context).savedSuccessfully);
  }

  void _showSettings() {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(context: context, backgroundColor: _paper, builder: (sheetContext) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      Text(s.paperColor, style: AppText.title.copyWith(color: _ink)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, children: [for (final background in ReaderBackground.values) InkWell(
        onTap: () => _reader.update(_settings.copyWith(background: background)),
        child: CircleAvatar(backgroundColor: background.color, child: _settings.background == background ? Icon(Icons.check, color: background.ink) : null),
      )]),
      const Divider(height: 30),
      Text(s.readingDirection, style: AppText.title.copyWith(color: _ink)),
      RadioGroup<String>(
        groupValue: _direction,
        onChanged: (value) { if (value != null) _setDirection(value); },
        child: Column(children: [
          RadioListTile<String>(value: 'auto', title: Text(s.automaticDirection)),
          RadioListTile<String>(value: 'ltr', title: Text(s.leftToRight)),
          RadioListTile<String>(value: 'rtl', title: Text(s.rightToLeft)),
        ]),
      ),
    ])));
  }

  Widget _selectionBar() {
    final s = AppStrings.of(context);
    return PositionedDirectional(start: 10, end: 10, bottom: 12, child: Material(
      elevation: 8, borderRadius: BorderRadius.circular(18), color: _settings.chrome.surface,
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(children: [
        IconButton(tooltip: s.copyText, onPressed: () async { await Clipboard.setData(ClipboardData(text: _selectedText!)); _clearSelection(); }, icon: const Icon(Icons.copy)),
        IconButton(tooltip: s.highlight, onPressed: () => _pickStyle(EpubAnnotationKind.highlight), icon: const Icon(Icons.highlight)),
        IconButton(tooltip: s.epubUnderline, onPressed: () => _pickStyle(EpubAnnotationKind.underline), icon: const Icon(Icons.format_underline)),
        IconButton(tooltip: s.strikeThrough, onPressed: () => _pickStyle(EpubAnnotationKind.strike), icon: const Icon(Icons.format_strikethrough)),
        IconButton(tooltip: s.wavyUnderline, onPressed: () => _pickStyle(EpubAnnotationKind.wavy), icon: const Icon(Icons.gesture)),
        IconButton(tooltip: s.markNote, onPressed: _addNote, icon: const Icon(Icons.note_alt_outlined)),
        PopupMenuButton<String>(tooltip: s.more, onSelected: _externalAction, itemBuilder: (_) => [
          PopupMenuItem(value: 'google', child: Text(s.translateGoogle)), PopupMenuItem(value: 'deepl', child: Text(s.translateDeepL)),
          PopupMenuItem(value: 'chatgpt', child: Text(s.askChatGpt)), PopupMenuItem(value: 'share', child: Text(s.share)),
        ]),
        IconButton(tooltip: s.close, onPressed: _clearSelection, icon: const Icon(Icons.close)),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(backgroundColor: _paper, body: SafeArea(child: Column(children: [
      Row(children: [
        IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.pop(context), icon: AppIcon(AppIcons.previous, color: _ink)),
        Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: textDirectionFor(widget.title), style: AppText.headline.copyWith(color: _ink))),
        IconButton(tooltip: s.epubSearch, onPressed: _loaded ? _showSearch : null, icon: Icon(Icons.search, color: _ink)),
        IconButton(tooltip: s.tableOfContents, onPressed: _loaded ? _showContents : null, icon: Icon(Icons.format_list_bulleted, color: _ink)),
        IconButton(tooltip: s.epubAnnotations, onPressed: _loaded ? _showLibrary : null, icon: Icon(Icons.collections_bookmark_outlined, color: _ink)),
        IconButton(tooltip: s.readerSettings, onPressed: _loaded ? _showSettings : null, icon: Icon(Icons.tune, color: _ink)),
      ]),
      Expanded(child: FutureBuilder<_EpubStart>(future: _start, builder: (_, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (_failed) return EmptyState(icon: AppIcons.error, title: s.couldNotOpen, message: widget.title);
        final start = snapshot.data!;
        return Stack(children: [
          EpubViewer(
            epubController: _controller, epubSource: EpubSource.fromFile(File(widget.filePath)), initialCfi: start.cfi,
            initialLocations: start.locations, onLocationsGenerated: (value) => _positions.saveLocations(widget.lectureId, value),
            displaySettings: EpubDisplaySettings(fontSize: start.fontSize, flow: EpubFlow.paginated, snap: true, defaultDirection: start.direction == 'rtl' ? EpubDefaultDirection.rtl : EpubDefaultDirection.ltr, theme: _theme),
            suppressNativeContextMenu: true, selectAnnotationRange: true, clearSelectionOnPageChange: true,
            onSelection: (text, cfi, rect, view) => setState(() { _selectedText = text; _selectedCfi = cfi; _selectionRect = rect; _selectionView = view; }),
            onSelectionChanging: () => setState(() => _selectionRect = null),
            onDeselection: () { if (mounted) setState(() { _selectedText = null; _selectedCfi = null; _selectionRect = null; _selectionView = null; }); },
            onTouchDown: (x, y) {
              final rect = _selectionRect;
              final view = _selectionView;
              if (rect != null && view != null && !rect.inflate(18).contains(Offset(x * view.width, y * view.height))) _clearSelection();
            },
            onAnnotationClicked: (cfi, _) { final found = _annotations.where((a) => a.cfi == cfi); if (found.isNotEmpty) _showLibrary(); },
            onFootnoteTapped: (footnote) => showModalBottomSheet<void>(context: context, backgroundColor: _paper, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: SelectableText(footnote.text, textDirection: textDirectionFor(footnote.text), style: TextStyle(color: _ink))))),
            onEpubLoaded: () { setState(() => _loaded = true); for (final a in _annotations) { _paint(a); } },
            onChaptersLoaded: (value) => setState(() => _chapters = value), onRelocated: _onRelocated,
            onLoadError: (_) => setState(() => _failed = true),
          ),
          if (!_loaded) ColoredBox(color: _paper, child: const Center(child: CircularProgressIndicator())),
          if (_selectionRect != null && _selectedText?.isNotEmpty == true) _selectionBar(),
        ]);
      })),
      Row(children: [
        IconButton(tooltip: MaterialLocalizations.of(context).previousPageTooltip, onPressed: _loaded ? _controller.prev : null, icon: AppIcon(AppIcons.previous, color: _ink)),
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [LinearProgressIndicator(value: _progress, color: StudyTone.purple, backgroundColor: _ink.withValues(alpha: .1)), Text('${(_progress * 100).round()}%', style: AppText.caption.copyWith(color: _ink))])),
        IconButton(tooltip: s.addBookmark, onPressed: _loaded ? _addBookmark : null, icon: Icon(Icons.bookmark_add_outlined, color: _ink)),
        IconButton(tooltip: MaterialLocalizations.of(context).nextPageTooltip, onPressed: _loaded ? _controller.next : null, icon: AppIcon(AppIcons.next, color: _ink)),
      ]),
    ])));
  }
}
