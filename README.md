# OmniStudio AI Free

استوديو تصميم وتحرير صور مبني بـ Flutter، مجاني 100%، والمعالجة كلها **على جهاز المستخدم** (بدون API Keys وبدون سيرفرات مدفوعة).

## الميزات

| الميزة | التنفيذ |
|---|---|
| إزالة الخلفية (عناصر/منتجات/أشخاص) | ML Kit Subject Segmentation (Android) ← Selfie Segmentation ← بديل بالألوان (Dart) |
| ظل ديناميكي يتبع شكل العنصر | رسم قناع الشفافية + `ImageFilter.blur` (ظل ساقط / أرضي) |
| نظام طبقات ونصوص عربية/إنجليزية | `CustomPainter` + `google_fonts` (30 خطاً)، تحريك/تدوير/تكبير، ترتيب Z، قفل/إخفاء، تراجع/إعادة |
| تعديل ألوان على طريقة Lightroom | `ColorFilter.matrix`: سطوع، تباين، تشبع، حرارة، صبغة، بهتان، Hue، فينيت + 13 فلتراً سينمائياً، على طبقة أو التصميم كله |
| دمج وتراكب | 12 وضع `BlendMode` لكل طبقة |
| الممحاة اليدوية | `BlendMode.clear` غير مدمّرة (قابلة للتراجع) |
| كولاج | 4 تخطيطات + `flutter_staggered_grid_view` |
| أنمي/كرتون | `tflite_flutter` (AnimeGANv2/CartoonGAN) + فلاتر كوميك/رسم رصاص بـ Dart كبديل |
| المساعد الذكي | `speech_to_text` + محلل أوامر Regex عربي/إنجليزي ينفّذ على الـ Blocs |
| التصدير | PNG/JPG/WEBP حتى 4096px، حفظ في المعرض (`gal`) ومشاركة |
| حفظ المشاريع | Hive (JSON) + صور مصغّرة |

## البنية

```
lib/
├── core/
│   ├── utils/      # poster_painter, color_matrices, pixel_ops (Isolate), text_metrics
│   ├── services/   # tflite / mlkit / export / storage / media / speech / font / image_store
│   └── theme/
├── features/
│   ├── background_remover/  # SubjectSegmentationBloc + الخدمة
│   ├── poster_builder/      # CanvasBloc + النماذج + المحرر وكل اللوحات
│   ├── color_grading/       # لوحة الألوان
│   ├── anime_morph/         # AnimeBloc + لوحة التحويل
│   ├── ai_copilot/          # CommandParser + CopilotBloc + CommandExecutor
│   ├── collage/  home/
└── main.dart
```

إدارة الحالة: `flutter_bloc`. التصدير يستخدم **نفس دالة الرسم** المستعملة في العرض (`paintDoc`) فما تراه هو ما يُصدَّر.

## أوامر المساعد (أمثلة)

- «ازل الخلفية» / «remove background»
- «اضف نص "عرض خاص"»
- «حول الصورة إلى أنمي / كرتون / كوميك / رسم رصاص»
- «طبق فلتر سينمائي» / «اجعلها أبيض وأسود»
- «زد السطوع 20» / «قلل التباين»
- «اضف ظل» / «ازل الظل» / «لون الخلفية أحمر» / «لون النص ذهبي»
- «تراجع» / «كرر» / «احذف» / «احفظ»

## التشغيل

المستودع لا يحتوي مجلد `android/` (يُولَّد). محلياً:

```bash
flutter create --platforms=android --org com.omnistudio --project-name omnistudio_ai .
python3 tool/patch_android.py      # أذونات + minSdk 24 + نموذج ML Kit
flutter pub get
flutter run
```

أو ارفع المشروع إلى GitHub وشغّل workflow **Build APK** (`.github/workflows/build.yml`) وحمّل ملف الـ APK من Artifacts.

## نماذج TFLite (اختيارية)

ضع `animeganv2.tflite` و/أو `cartoongan.tflite` في `assets/models/`. بدونها يعمل التحويل بفلتر Dart محلي. التفاصيل في `assets/models/README.md`.

## ملاحظات

- ML Kit و TFLite يعملان على **Android/iOS**؛ إزالة الخلفية بنموذج العناصر (Subject) على Android فقط، وعلى iOS يُستخدم نموذج الأشخاص ثم الألوان.
- خطوط جوجل تُنزَّل عند أول استخدام (تحتاج إنترنت مرة واحدة ثم تُخزَّن).
- واجهة التطبيق بالعربية (RTL).
