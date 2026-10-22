import 'package:flutter/material.dart';

import '../../core/ui/core_ui.dart';
import 'reader_chrome.dart';

// نتيجة نافذة علامة المذكرة: حفظ باسم (اختياري) أو إزالة من العلامات
sealed class NoteBookmarkAction {
  const NoteBookmarkAction();
}

class SaveNoteBookmark extends NoteBookmarkAction {
  const SaveNoteBookmark(this.title);
  final String title; // فارغ = بلا اسم
}

class RemoveNoteBookmark extends NoteBookmarkAction {
  const RemoveNoteBookmark();
}

// نافذة صغيرة: اسم مقترح من أول سطر في المذكرة (أو الاسم الحالي) يمكن تعديله،
// وحفظ، وإزالة إن كانت المذكرة في العلامات. null = إلغاء
Future<NoteBookmarkAction?> showNoteBookmarkDialog(
  BuildContext context, {
  required ReaderChrome chrome,
  required String suggestion,
  required bool bookmarked,
}) {
  return showDialog<NoteBookmarkAction>(
    context: context,
    builder: (_) => _NoteBookmarkDialog(
      chrome: chrome,
      suggestion: suggestion,
      bookmarked: bookmarked,
    ),
  );
}

// تملك الـ controller وتتخلص منه في dispose (لا controller خارج النافذة)
class _NoteBookmarkDialog extends StatefulWidget {
  const _NoteBookmarkDialog({
    required this.chrome,
    required this.suggestion,
    required this.bookmarked,
  });

  final ReaderChrome chrome;
  final String suggestion;
  final bool bookmarked;

  @override
  State<_NoteBookmarkDialog> createState() => _NoteBookmarkDialogState();
}

class _NoteBookmarkDialogState extends State<_NoteBookmarkDialog> {
  late final _name = TextEditingController(text: widget.suggestion)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.suggestion.length,
    );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(SaveNoteBookmark(_name.text));

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.chrome;

    return AlertDialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      title: Row(
        children: [
          AppIcon(AppIcons.bookmarkSaved, size: 22, color: c.strong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.bookmarked ? s.editNoteBookmark : s.bookmarkNote,
              style: TextStyle(
                color: c.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ListenableBuilder(
        listenable: _name,
        builder: (context, _) => TextField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          cursorColor: c.strong,
          textDirection:
              strongDirection(_name.text) ?? Directionality.of(context),
          style: TextStyle(color: c.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: s.noteBookmarkName,
            hintStyle: TextStyle(color: c.muted),
            counterText: '',
            filled: true,
            fillColor: c.chip,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: c.strong, width: 1.4),
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        if (widget.bookmarked)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const RemoveNoteBookmark()),
            child: Text(
              s.removeFromBookmarks,
              style: TextStyle(color: c.muted),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel, style: TextStyle(color: c.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.strong),
          onPressed: _save,
          child: Text(s.save),
        ),
      ],
    );
  }
}
