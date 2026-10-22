import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import 'reader_chrome.dart';

// رسالة "نجهّز النص للنسخ" أسفل العارض: بألوان القراءة ولون الثيم وصورة البومة،
// وبلغة التطبيق. تبقى حتى يجهز النص، فيخفيها المستدعي بـ hideReadingWait.
const _owlAsset = 'assets/owl/owl_waiting.webp';

void showReadingWait(BuildContext context, ReaderChrome chrome) {
  final s = AppStrings.of(context);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 30),
        backgroundColor: chrome.surface,
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: chrome.line),
        ),
        content: Directionality(
          textDirection: Directionality.of(context),
          child: Row(
            children: [
              // خلفية الصورة بيضاء، فتظهر داخل دائرة بيضاء بإطار من لون الثيم
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: chrome.accent, width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    _owlAsset,
                    cacheWidth: 144,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.recognizingPage,
                      style: TextStyle(
                        color: chrome.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.recognizingHint,
                      style: TextStyle(color: chrome.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        color: chrome.strong,
                        backgroundColor: chrome.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

void hideReadingWait(BuildContext context) =>
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
