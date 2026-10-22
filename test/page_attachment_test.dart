import 'package:flutter_test/flutter_test.dart';
import 'package:project/ui/viewer/widgets/pdf_attachments.dart';

// المرفق يُحفظ ويُقرأ كما هو (الحقول الاختيارية والقيم الافتراضية)
void main() {
  test('attachment survives a save and reload', () {
    final audio = PageAttachment(
      id: 'a1',
      page: 3,
      kind: AttachmentKind.audio,
      file: 'rec_1.m4a',
      x: 0.2,
      y: 0.5,
      durationMs: 64000,
    );
    final back = PageAttachment.fromJson(audio.toJson());
    expect(back.isAudio, isTrue);
    expect(back.page, 3);
    expect(back.durationMs, 64000);

    final image = PageAttachment.fromJson({
      'id': 'i1',
      'page': 0,
      'kind': 'image',
      'file': 'p.jpg',
      'x': 0.1,
      'y': 0.1,
    });
    expect(image.isAudio, isFalse);
    expect(image.w, 0.4); // القيمة الافتراضية
    expect(image.durationMs, isNull);
  });
}
