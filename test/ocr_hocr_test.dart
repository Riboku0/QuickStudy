// يتحقق من قراءة hOCR (مخرجات Tesseract) إلى كلمات بمواضعها
import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/services/ocr_service.dart';

const _sample = '''
<div class='ocr_page' id='page_1' title='image "x.png"; bbox 0 0 1000 2000; ppageno 0'>
 <div class='ocr_carea' id='block_1_1' title="bbox 100 100 900 300">
  <p class='ocr_par' id='par_1_1' lang='ara' title="bbox 100 100 900 300">
   <span class='ocr_line' id='line_1_1' title="bbox 100 100 900 150; baseline 0 -8; x_size 43">
    <span class='ocrx_word' id='word_1_1' title='bbox 700 100 900 150; x_wconf 91'>مرحبا</span>
    <span class='ocrx_word' id='word_1_2' title='bbox 400 100 650 150; x_wconf 88'><strong>بالعالم</strong></span>
    <span class='ocrx_word' id='word_1_3' title='bbox 380 100 390 150; x_wconf 5'>~</span>
   </span>
   <span class='ocr_line' id='line_1_2' title="bbox 100 200 900 250; baseline 0 -8">
    <span class='ocrx_word' id='word_1_4' title='bbox 100 200 300 250; x_wconf 95'>Tom &amp; Jerry</span>
   </span>
  </p>
 </div>
</div>
''';

void main() {
  test('parse hOCR', () {
    final words = OcrService.parseHocr(_sample, 1000, 2000);
    expect(words.map((w) => w.text).toList(), ['مرحبا', 'بالعالم', 'Tom & Jerry']);
    expect(words.map((w) => w.line).toList(), [0, 0, 1]);
    expect(words.first.rect.left, closeTo(0.7, 1e-9));
    expect(words.first.rect.bottom, closeTo(0.075, 1e-9));
  });
}
