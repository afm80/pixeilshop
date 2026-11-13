import '../poster_builder/model/doc.dart';
import '../poster_builder/model/layer.dart';

/// قالب جاهز: يبني تصميماً جديداً في كل مرة (بمعرّف جديد) بنصوص وأشكال قابلة للتعديل.
class TemplateDef {
  const TemplateDef(this.id, this.name, this.category, this.w, this.h, this.fonts, this.build);
  final String id, name, category;
  final double w, h;
  final List<String> fonts;
  final void Function(Doc d) build;

  Doc create() {
    final d = Doc.blank(name: name, w: w, h: h);
    build(d);
    return d;
  }
}

Layer _text(
  String s,
  double x,
  double y, {
  double w = 900,
  double size = 96,
  int color = 0xFFFFFFFF,
  String font = 'Cairo',
  bool bold = true,
  double stroke = 0,
  int strokeColor = 0xFF000000,
  double lh = 1.2,
  double spacing = 0,
  double opacity = 1,
}) {
  final l = Layer.create(LayerType.text, name: 'نص')
    ..text = s
    ..x = x
    ..y = y
    ..w = w
    ..fontSize = size
    ..color = color
    ..font = font
    ..bold = bold
    ..strokeW = stroke
    ..strokeColor = strokeColor
    ..lineHeight = lh
    ..letterSpacing = spacing
    ..opacity = opacity;
  return l;
}

Layer _shape(
  ShapeKind k,
  double x,
  double y,
  double w,
  double h, {
  int color = 0xFFFFFFFF,
  int? g1,
  int? g2,
  double angle = 45,
  double radius = 0,
  double stroke = 0,
  int strokeColor = 0xFF000000,
  double opacity = 1,
  double rot = 0,
}) {
  final l = Layer.create(LayerType.shape, name: 'شكل')
    ..shape = k
    ..x = x
    ..y = y
    ..w = w
    ..h = h
    ..color = color
    ..cornerRadius = radius
    ..strokeW = stroke
    ..strokeColor = strokeColor
    ..opacity = opacity
    ..rotation = rot;
  if (g1 != null && g2 != null) {
    l
      ..fillKind = 1
      ..grad1 = g1
      ..grad2 = g2
      ..gradAngle = angle;
  }
  return l;
}

void _bg(Doc d, int c1, [int? c2, double angle = 90]) {
  d.bgKind = c2 == null ? 0 : 1;
  d.bgColor1 = c1;
  if (c2 != null) {
    d.bgColor2 = c2;
    d.bgAngle = angle;
  }
}

const _clear = 0x00000000;
const kTemplateCategories = ['الكل', 'انستغرام', 'فيسبوك', 'يوتيوب', 'X', 'تيك توك', 'لينكدإن', 'ستوري', 'منشور', 'شعار', 'دعوة'];

final List<TemplateDef> kTemplates = [
  // ───────── ستوري ─────────
  TemplateDef('story_grad', 'ستوري متدرج', 'ستوري', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF6A11CB, 0xFFFF4E8A, 135);
    d.layers.addAll([
      _shape(ShapeKind.circle, 900, 280, 700, 700, opacity: 0.12),
      _shape(ShapeKind.circle, 140, 1680, 520, 520, opacity: 0.10),
      _text('عنوانك الرئيسي هنا', 540, 780, size: 150, lh: 1.15),
      _text('اكتب وصفاً قصيراً يشرح فكرتك في سطرين', 540, 1100, size: 62, bold: false, opacity: 0.9),
      _shape(ShapeKind.rect, 540, 1480, 560, 140, radius: 70),
      _text('اكتشف المزيد', 540, 1480, w: 520, size: 64, color: 0xFF6A11CB),
    ]);
  }),
  TemplateDef('story_sale', 'ستوري عرض', 'ستوري', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF111111);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 760, 800, 800, g1: 0xFFFFD54F, g2: 0xFFFF9800),
      _text('خصم', 540, 560, size: 130, color: 0xFF111111),
      _text('50%', 540, 800, size: 330, color: 0xFF111111),
      _text('على جميع المنتجات', 540, 1300, size: 84),
      _shape(ShapeKind.rect, 540, 1560, 600, 150, color: 0xFFFFC400, radius: 75),
      _text('تسوق الآن', 540, 1560, w: 560, size: 70, color: 0xFF111111),
    ]);
  }),
  TemplateDef('story_quote', 'ستوري اقتباس', 'ستوري', 1080, 1920, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFFFFF4E0);
    d.layers.addAll([
      _text('“', 540, 520, size: 420, color: 0xFFF39B00, font: 'Amiri'),
      _text('اكتب هنا عبارتك أو اقتباسك المفضل ليظهر بخط أنيق وواضح', 540, 980, w: 860, size: 92, color: 0xFF3A2A12, font: 'Amiri', lh: 1.5),
      _shape(ShapeKind.rect, 540, 1380, 220, 8, color: 0xFFF39B00),
      _text('اسم القائل', 540, 1470, size: 58, color: 0xFF7A6A52, bold: false),
    ]);
  }),
  // ───────── منشور ─────────
  TemplateDef('post_promo', 'منشور إعلاني', 'منشور', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF0D1B3E);
    d.layers.addAll([
      _shape(ShapeKind.circle, 840, 240, 640, 640, g1: 0xFFFFD54F, g2: 0xFFFF9800, opacity: 0.95),
      _shape(ShapeKind.circle, 120, 960, 380, 380, color: 0xFF1E3A8A, opacity: 0.7),
      _text('عرض خاص', 540, 560, size: 170),
      _text('لفترة محدودة فقط', 540, 740, size: 70, color: 0xFFFFD54F),
      _shape(ShapeKind.rect, 540, 920, 520, 110, color: 0xFFFFC400, radius: 55),
      _text('اطلب الآن', 540, 920, w: 480, size: 58, color: 0xFF0D1B3E),
    ]);
  }),
  TemplateDef('post_quote', 'منشور عبارة', 'منشور', 1080, 1080, const ['Amiri'], (d) {
    _bg(d, 0xFF11998E, 0xFF38EF7D, 135);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 540, 940, 940, color: _clear, stroke: 8, strokeColor: 0xFFFFFFFF, opacity: 0.9),
      _text('اكتب عبارتك هنا بخط واضح وجميل', 540, 520, w: 780, size: 104, font: 'Amiri', lh: 1.45),
      _text('@حسابك', 540, 900, size: 52, bold: false, opacity: 0.9),
    ]);
  }),
  TemplateDef('post_product', 'إعلان منتج', 'منشور', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFFF5F5F5);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 430, 640, 640, g1: 0xFFFFC400, g2: 0xFFFF7A00),
      _text('ضع صورة المنتج هنا', 540, 430, w: 420, size: 52, color: 0xFFFFFFFF, opacity: 0.9),
      _text('اسم المنتج', 540, 860, size: 110, color: 0xFF222222),
      _text('99 ر.س', 540, 990, size: 72, color: 0xFFE53935),
      _shape(ShapeKind.star, 900, 210, 250, 250, color: 0xFFE53935, rot: 0.2),
      _text('-30%', 900, 215, w: 220, size: 64)..rotation = 0.2,
    ]);
  }),
  // ───────── شعار ─────────
  TemplateDef('logo_round', 'شعار دائري', 'شعار', 1024, 1024, const ['Cairo'], (d) {
    _bg(d, 0xFFFFFFFF);
    d.layers.addAll([
      _shape(ShapeKind.circle, 512, 512, 800, 800, color: 0xFF1B1B3A),
      _shape(ShapeKind.circle, 512, 512, 710, 710, color: _clear, stroke: 10, strokeColor: 0xFFFFC400),
      _text('ش', 512, 450, w: 500, size: 380, color: 0xFFFFC400),
      _text('اسم علامتك', 512, 700, w: 600, size: 76),
    ]);
  }),
  TemplateDef('logo_hex', 'شعار أنيق', 'شعار', 1024, 1024, const ['Cairo'], (d) {
    _bg(d, 0xFF101820);
    d.layers.addAll([
      _shape(ShapeKind.hexagon, 512, 390, 560, 560, color: _clear, stroke: 12, strokeColor: 0xFFD4AF37),
      _text('ب', 512, 390, w: 400, size: 300, color: 0xFFD4AF37),
      _text('اسم علامتك', 512, 770, size: 112),
      _text('شعارك التجاري هنا', 512, 880, size: 44, color: 0xFFAAAAAA, bold: false),
    ]);
  }),
  // ───────── دعوة ─────────
  TemplateDef('invite_wed', 'دعوة زفاف', 'دعوة', 1080, 1350, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFFFDF6EC);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 675, 980, 1250, color: _clear, stroke: 6, strokeColor: 0xFFC9A227),
      _shape(ShapeKind.rect, 540, 675, 930, 1200, color: _clear, stroke: 2, strokeColor: 0xFFC9A227),
      _text('دعوة زفاف', 540, 280, size: 76, color: 0xFFC9A227, font: 'Amiri'),
      _text('أحمد  &  سارة', 540, 600, size: 160, color: 0xFF4A3A1A, font: 'Amiri'),
      _text('يتشرفان بدعوتكم لحضور حفل زفافهما', 540, 860, w: 780, size: 56, color: 0xFF4A3A1A, font: 'Amiri', bold: false, lh: 1.5),
      _text('الخميس  ١٥ / ١٢ / ٢٠٢٦', 540, 1060, size: 64, color: 0xFFC9A227),
      _text('قاعة الأفراح - المدينة', 540, 1160, size: 52, color: 0xFF4A3A1A, bold: false),
    ]);
  }),
  TemplateDef('invite_party', 'دعوة حفل', 'دعوة', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFF1F1C2C, 0xFF928DAB, 90);
    d.layers.addAll([
      _shape(ShapeKind.star, 160, 200, 120, 120, color: 0xFFFFD54F, opacity: 0.9),
      _shape(ShapeKind.star, 920, 340, 80, 80, color: 0xFFFFD54F, opacity: 0.8),
      _shape(ShapeKind.star, 880, 1100, 140, 140, color: 0xFFFFD54F, opacity: 0.9),
      _shape(ShapeKind.star, 200, 1180, 70, 70, color: 0xFFFFD54F, opacity: 0.8),
      _text('ندعوكم لحضور', 540, 420, size: 84, bold: false),
      _text('حفل التخرج', 540, 640, size: 210, color: 0xFFFFD54F),
      _text('السبت ٢٠ / ٦ / ٢٠٢٦  -  الساعة ٧ مساءً', 540, 900, w: 880, size: 60),
      _text('القاعة الكبرى - الجامعة', 540, 1010, size: 52, bold: false, opacity: 0.9),
    ]);
  }),
  // ───────── يوتيوب ─────────
  TemplateDef('yt_thumb', 'صورة مصغرة يوتيوب', 'يوتيوب', 1280, 720, const ['Cairo'], (d) {
    _bg(d, 0xFFFFD600);
    d.layers.addAll([
      _shape(ShapeKind.rect, 1030, 360, 560, 1000, color: 0xFF111111, rot: 0.22),
      _shape(ShapeKind.triangle, 1040, 360, 230, 230, color: 0xFFE53935, rot: 1.5708),
      _text('عنوان الفيديو هنا', 420, 300, w: 760, size: 170, stroke: 16, strokeColor: 0xFF111111, lh: 1.1),
      _text('شاهد الآن', 330, 590, w: 500, size: 80, color: 0xFF111111),
    ]);
  }),
  // ───────── غلاف ─────────
  TemplateDef('fb_cover', 'غلاف فيسبوك', 'فيسبوك', 820, 312, const ['Cairo'], (d) {
    _bg(d, 0xFF1877F2, 0xFF0B3D91, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 720, 40, 360, 360, opacity: 0.12),
      _shape(ShapeKind.circle, 90, 300, 260, 260, opacity: 0.10),
      _text('اسم صفحتك', 410, 125, w: 700, size: 86),
      _text('جملة قصيرة تعبّر عن نشاطك', 410, 215, w: 700, size: 36, bold: false, opacity: 0.9),
    ]);
  }),
  // ───────── انستغرام ─────────
  TemplateDef('ig_post', 'منشور انستغرام', 'انستغرام', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFFFF5F6D, 0xFFFFC371, 120);
    d.layers.addAll([
      _shape(ShapeKind.circle, 880, 220, 560, 560, opacity: 0.14),
      _shape(ShapeKind.rect, 540, 675, 940, 1210, color: _clear, stroke: 6, strokeColor: 0xFFFFFFFF, opacity: 0.8),
      _text('عنوان المنشور', 540, 560, size: 150, lh: 1.15),
      _text('اكتب هنا الفكرة الرئيسية بجملتين قصيرتين لتجذب القارئ', 540, 880, w: 780, size: 60, bold: false, lh: 1.4),
      _text('@حسابك', 540, 1190, size: 56),
    ]);
  }),
  TemplateDef('ig_highlight', 'غلاف قصة مميزة', 'انستغرام', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF833AB4, 0xFFFD1D1D, 150);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 960, 620, 620, color: _clear, stroke: 14, strokeColor: 0xFFFFFFFF),
      _shape(ShapeKind.star, 540, 960, 300, 300, color: 0xFFFFFFFF),
    ]);
  }),
  TemplateDef('ig_profile', 'بروفايل انستغرام', 'انستغرام', 320, 320, const ['Cairo'], (d) {
    _bg(d, 0xFF405DE6, 0xFFE1306C, 135);
    d.layers.addAll([
      _text('ش', 160, 150, w: 280, size: 190),
    ]);
  }),
  // ───────── فيسبوك ─────────
  TemplateDef('fb_post', 'منشور فيسبوك', 'فيسبوك', 1200, 630, const ['Cairo'], (d) {
    _bg(d, 0xFF1877F2, 0xFF0A3D91, 120);
    d.layers.addAll([
      _shape(ShapeKind.circle, 1080, 80, 520, 520, opacity: 0.12),
      _shape(ShapeKind.circle, 100, 600, 360, 360, opacity: 0.10),
      _text('عنوان المنشور هنا', 600, 260, w: 1000, size: 120),
      _text('وصف قصير يوضح الفكرة', 600, 430, w: 900, size: 52, bold: false, opacity: 0.92),
    ]);
  }),
  TemplateDef('fb_profile', 'بروفايل فيسبوك', 'فيسبوك', 320, 320, const ['Cairo'], (d) {
    _bg(d, 0xFF1877F2);
    d.layers.addAll([
      _shape(ShapeKind.circle, 160, 160, 250, 250, color: _clear, stroke: 6, strokeColor: 0xFFFFFFFF, opacity: 0.8),
      _text('ب', 160, 150, w: 260, size: 170),
    ]);
  }),
  // ───────── يوتيوب ─────────
  TemplateDef('yt_banner', 'غلاف قناة يوتيوب', 'يوتيوب', 2560, 1440, const ['Cairo'], (d) {
    _bg(d, 0xFF0F0F0F, 0xFF3A0CA3, 120);
    d.layers.addAll([
      _shape(ShapeKind.circle, 2200, 220, 900, 900, opacity: 0.10),
      _shape(ShapeKind.circle, 360, 1260, 700, 700, opacity: 0.08),
      _text('اسم قناتك', 1280, 640, w: 1400, size: 260),
      _text('محتوى جديد كل أسبوع', 1280, 860, w: 1400, size: 90, bold: false, color: 0xFFFFD54F),
    ]);
  }),
  TemplateDef('yt_profile', 'صورة قناة يوتيوب', 'يوتيوب', 800, 800, const ['Cairo'], (d) {
    _bg(d, 0xFFE53935, 0xFFB71C1C, 135);
    d.layers.addAll([
      _text('ق', 400, 380, w: 600, size: 480),
    ]);
  }),
  // ───────── X ─────────
  TemplateDef('x_post', 'منشور X', 'X', 1600, 900, const ['Cairo'], (d) {
    _bg(d, 0xFF0B0B0B);
    d.layers.addAll([
      _shape(ShapeKind.rect, 800, 450, 1480, 780, color: _clear, stroke: 4, strokeColor: 0xFF2F3336),
      _text('اكتب فكرتك هنا بجملة قوية', 800, 380, w: 1250, size: 130, lh: 1.2),
      _text('@حسابك', 800, 700, size: 58, color: 0xFF1D9BF0),
    ]);
  }),
  TemplateDef('x_cover', 'غلاف X', 'X', 1500, 500, const ['Cairo'], (d) {
    _bg(d, 0xFF0F172A, 0xFF1D9BF0, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 1350, 60, 480, 480, opacity: 0.10),
      _text('اسمك أو شعارك', 750, 200, w: 1100, size: 110),
      _text('نبذة قصيرة عنك', 750, 330, w: 1000, size: 46, bold: false, opacity: 0.9),
    ]);
  }),
  // ───────── تيك توك ─────────
  TemplateDef('tt_cover', 'غلاف تيك توك', 'تيك توك', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF010101, 0xFF1B1B1B, 90);
    d.layers.addAll([
      _text('عنوان الفيديو', 556, 905, w: 900, size: 170, color: 0xFF25F4EE, lh: 1.15),
      _text('عنوان الفيديو', 524, 895, w: 900, size: 170, color: 0xFFFE2C55, lh: 1.15),
      _text('عنوان الفيديو', 540, 900, w: 900, size: 170, lh: 1.15),
      _text('اضغط للمشاهدة', 540, 1300, size: 64, bold: false, opacity: 0.85),
    ]);
  }),
  // ───────── لينكدإن ─────────
  TemplateDef('li_cover', 'غلاف لينكدإن', 'لينكدإن', 1584, 396, const ['Cairo'], (d) {
    _bg(d, 0xFF0A66C2, 0xFF004182, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 1450, 40, 420, 420, opacity: 0.10),
      _text('اسمك  |  مسماك الوظيفي', 1000, 150, w: 1200, size: 84),
      _text('خبرتك أو مجال تخصصك في جملة واحدة', 1000, 260, w: 1200, size: 40, bold: false, opacity: 0.9),
    ]);
  }),
];
