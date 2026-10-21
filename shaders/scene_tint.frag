#version 460 core

#include <flutter/runtime_effect.glsl>

// خلفية الرئيسية المرسومة: يمزج صورتي النهار والليل حسب الساعة،
// ويحوّل الدرجات البنفسجية والكحلية فقط إلى لون الثيم،
// فيبقى ضوء المصباح والخشب والنباتات والكتب بألوانها الدافئة.

uniform vec4 uRect;      // موضع الصورة على اللوحة: x, y, عرض, ارتفاع
uniform float uNight;    // 0 نهار … 1 ليل
uniform float uHue;      // لون الثيم (0..1)
uniform float uSatScale; // تشبع اللون بعد التلوين (أقل للرمادي)
uniform float uStrength; // 0 للبنفسجي الأصلي (الرسمة كما هي)، 1 لبقية الثيمات
uniform float uDim;      // تعتيم خفيف في مظهر التطبيق الداكن
uniform float uDayShift; // إزاحة صورة النهار عموديًا لتطابق الليل (نسبة)
uniform sampler2D uDay;
uniform sampler2D uNightTex;
uniform sampler2D uMask;  // خريطة المناطق: R داخل النافذة، G جدار الغرفة وستائرها

out vec4 fragColor;

vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// وزن التلوين لدرجة واحدة: الكحلي والبنفسجي والوردي البارد (200°–350° تقريبًا)
// بحواف ناعمة، والدرجات الدافئة (ضوء المصباح، الخشب، النباتات) لا تتأثر
float tintWeight(vec3 c) {
  vec3 hsv = rgb2hsv(c);
  float w = smoothstep(0.55, 0.62, hsv.x) * (1.0 - smoothstep(0.96, 1.0, hsv.x));
  return w * smoothstep(0.02, 0.12, hsv.y);
}

vec3 sceneAt(vec2 uv) {
  vec3 day = texture(uDay, vec2(uv.x, clamp(uv.y - uDayShift, 0.0, 1.0))).rgb;
  vec3 night = texture(uNightTex, uv).rgb;
  return mix(day, night, uNight);
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - uRect.xy) / uRect.zw;
  vec3 c = sceneAt(uv);
  vec3 hsv = rgb2hsv(c);

  // الوزن متوسط ما حول البكسل (5×5) حتى تتدرج حدود ضوء المصباح بنعومة
  float w = 0.0;
  vec2 stepUv = vec2(5.0 / 1586.0, 5.0 / 493.0);
  for (int i = -2; i <= 2; i++) {
    for (int j = -2; j <= 2; j++) {
      w += tintWeight(sceneAt(uv + vec2(float(i), float(j)) * stepUv));
    }
  }
  w /= 25.0;

  // الألوان الدافئة أو الخضراء المشبعة في البكسل نفسه (نوافذ القرية المضاءة)
  // تبقى كما هي داخل النافذة
  float own = (1.0 - smoothstep(0.45, 0.52, hsv.x)) * smoothstep(0.15, 0.45, hsv.y);

  // خريطة المناطق (assets/scene/scene_mask.png) تحدد ما يُلوَّن عمدًا بدل التخمين:
  // داخل النافذة تلوين كامل للكحلي والبنفسجي، والجدار والستائر صبغة متساوية
  // تتلاشى بنعومة حول المصباح، والباقي (المكتب، المصباح، الكتب، النباتات) كما رُسم
  vec3 region = texture(uMask, uv).rgb;
  float lampDist = length((uv - vec2(378.0 / 1586.0, 212.0 / 493.0)) * vec2(1586.0, 493.0));
  float lampGlow = 1.0 - smoothstep(110.0, 310.0, lampDist);
  w = region.r * w * (1.0 - own) + region.g * 0.32 * (1.0 - lampGlow);

  // تلوين بلون الثيم مباشرة (لا تدوير) فلا تظهر بقع عند الحواف
  vec3 tinted = hsv2rgb(vec3(uHue, hsv.y * uSatScale, hsv.z));
  c = mix(c, tinted, w * uStrength);

  c = mix(c, c * vec3(0.62, 0.6, 0.68), uDim);
  fragColor = vec4(c, 1.0);
}
