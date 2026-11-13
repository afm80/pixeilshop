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
/// تبويبات الصفحة: «منوعة» تضم كل القوالب غير الخاصة بمنصات التواصل.
const kTemplateCategories = ['الكل', 'منوعة', 'انستغرام', 'فيسبوك', 'يوتيوب', 'X', 'تيك توك', 'لينكدإن'];
const _socialTabs = {'انستغرام', 'فيسبوك', 'يوتيوب', 'X', 'تيك توك', 'لينكدإن'};

/// التبويب الذي يظهر فيه القالب.
String templateTab(TemplateDef t) => _socialTabs.contains(t.category) ? t.category : 'منوعة';

final List<TemplateDef> _handmade = [
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


final List<TemplateDef> kTemplates = [..._handmade, ..._more];

Layer _dashed(Layer l) => l..dashed = true;

/// قوالب إضافية: كل قالب بتركيب مختلف (لا تخطيطات مكررة).
final List<TemplateDef> _more = [
  // ───────── مطاعم ─────────
  TemplateDef('m_menu', 'قائمة طعام', 'مطاعم', 1080, 1350, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFFFBF3E4);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 675, 1000, 1270, color: _clear, stroke: 4, strokeColor: 0xFF8B5E34),
      _text('قائمة الطعام', 540, 200, size: 130, color: 0xFF5A3A1A, font: 'Amiri'),
      _shape(ShapeKind.rect, 540, 310, 300, 6, color: 0xFFC8963E),
      _text('برجر لحم', 360, 470, w: 480, size: 62, color: 0xFF3A2410),
      _text('35', 860, 470, w: 200, size: 62, color: 0xFFC8963E),
      _text('بيتزا مارغريتا', 360, 620, w: 480, size: 62, color: 0xFF3A2410),
      _text('45', 860, 620, w: 200, size: 62, color: 0xFFC8963E),
      _text('سلطة سيزر', 360, 770, w: 480, size: 62, color: 0xFF3A2410),
      _text('28', 860, 770, w: 200, size: 62, color: 0xFFC8963E),
      _text('عصير طبيعي', 360, 920, w: 480, size: 62, color: 0xFF3A2410),
      _text('15', 860, 920, w: 200, size: 62, color: 0xFFC8963E),
      _text('حلوى اليوم', 360, 1070, w: 480, size: 62, color: 0xFF3A2410),
      _text('22', 860, 1070, w: 200, size: 62, color: 0xFFC8963E),
      _text('الأسعار بالريال', 540, 1240, size: 40, bold: false, color: 0xFF8B5E34),
    ]);
  }),
  TemplateDef('m_burger', 'إعلان برجر', 'مطاعم', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFFFFD600);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 330, 1500, 330, color: 0xFF111111, rot: -0.1),
      _text('برجر لذيذ', 540, 330, w: 980, size: 190, color: 0xFFFFD600)..rotation = -0.1,
      _text('بالجبنة المدخنة', 540, 640, size: 90, color: 0xFF111111),
      _shape(ShapeKind.circle, 840, 860, 280, 280, color: 0xFFE53935),
      _text('19 ريال', 840, 860, w: 240, size: 64)..rotation = 0.15,
      _text('اطلب عبر التوصيل', 330, 880, w: 520, size: 56, color: 0xFF111111),
    ]);
  }),
  TemplateDef('m_coffee', 'قهوة الصباح', 'مطاعم', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF3E2723, 0xFF6D4C41, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 640, 760, 760, color: 0xFFF5E6D3),
      _shape(ShapeKind.circle, 540, 640, 600, 600, color: 0xFF4E342E),
      _shape(ShapeKind.circle, 540, 640, 520, 520, color: 0xFF2E1B16),
      _shape(ShapeKind.circle, 540, 640, 380, 380, color: _clear, stroke: 6, strokeColor: 0xFFC8A27A, opacity: 0.7),
      _text('قهوتك الصباحية', 540, 1260, w: 900, size: 130, color: 0xFFF5E6D3, lh: 1.15),
      _text('حبوب مختارة ومحمصة بعناية', 540, 1480, w: 800, size: 54, bold: false, color: 0xFFC8A27A),
    ]);
  }),
  // ───────── عقارات ─────────
  TemplateDef('r_rent', 'شقة للإيجار', 'عقارات', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFFFFFFFF);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 340, 1080, 680, color: 0xFFDCE3EC),
      _text('ضع صورة العقار هنا', 540, 340, size: 54, color: 0xFF7A8AA0, bold: false),
      _shape(ShapeKind.rect, 200, 690, 360, 90, color: 0xFF0B3C6E),
      _text('للإيجار', 200, 690, w: 340, size: 56),
      _text('شقة فاخرة بإطلالة مميزة', 540, 810, w: 960, size: 74, color: 0xFF0B3C6E),
      _shape(ShapeKind.circle, 240, 960, 120, 120, color: 0xFFEAF1FA),
      _text('3\nغرف', 240, 960, w: 110, size: 34, color: 0xFF0B3C6E, lh: 1.0),
      _shape(ShapeKind.circle, 540, 960, 120, 120, color: 0xFFEAF1FA),
      _text('2\nحمام', 540, 960, w: 110, size: 34, color: 0xFF0B3C6E, lh: 1.0),
      _shape(ShapeKind.circle, 840, 960, 120, 120, color: 0xFFEAF1FA),
      _text('140\nمتر', 840, 960, w: 110, size: 34, color: 0xFF0B3C6E, lh: 1.0),
    ]);
  }),
  TemplateDef('r_sale', 'لافتة للبيع', 'عقارات', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFF0B1F3A);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 1130, 1080, 440, color: 0xFFF2F2F2),
      _shape(ShapeKind.diamond, 540, 760, 1400, 330, color: 0xFFF2F2F2),
      _text('للبيع', 540, 380, size: 320, color: 0xFFD4AF37),
      _shape(ShapeKind.rect, 540, 560, 420, 10, color: 0xFFD4AF37),
      _text('فيلا بمساحة 400 متر', 540, 700, w: 900, size: 78),
      _text('للتواصل', 540, 1020, size: 56, color: 0xFF0B1F3A, bold: false),
      _text('05 0000 0000', 540, 1130, size: 110, color: 0xFF0B1F3A),
      _text('عنوان العقار هنا', 540, 1260, size: 46, color: 0xFF51627C, bold: false),
    ]);
  }),
  // ───────── مناسبات ─────────
  TemplateDef('o_eid', 'عيد مبارك', 'مناسبات', 1080, 1080, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFF0B3D2E, 0xFF06241B, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 330, 360, 360, color: 0xFFFFD54F),
      _shape(ShapeKind.circle, 610, 300, 320, 320, color: 0xFF0A3426),
      _shape(ShapeKind.star, 700, 250, 70, 70, color: 0xFFFFD54F),
      _shape(ShapeKind.star, 230, 180, 40, 40, color: 0xFFFFD54F, opacity: 0.7),
      _shape(ShapeKind.star, 880, 640, 50, 50, color: 0xFFFFD54F, opacity: 0.8),
      _text('عيد مبارك', 540, 700, size: 200, color: 0xFFFFD54F, font: 'Amiri'),
      _text('كل عام وأنتم بخير', 540, 880, size: 70, bold: false),
    ]);
  }),
  TemplateDef('o_ramadan', 'رمضان كريم', 'مناسبات', 1080, 1350, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFF0D1B4C, 0xFF251A5E, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 420, 520, 520, color: 0xFFFFC857),
      _shape(ShapeKind.circle, 640, 380, 470, 470, color: 0xFF14235F),
      _shape(ShapeKind.star, 800, 300, 90, 90, color: 0xFFFFC857),
      _shape(ShapeKind.star, 210, 220, 60, 60, color: 0xFFFFC857, opacity: 0.8),
      _shape(ShapeKind.star, 160, 640, 40, 40, color: 0xFFFFC857, opacity: 0.6),
      _shape(ShapeKind.rect, 540, 1000, 700, 4, color: 0xFFFFC857, opacity: 0.6),
      _text('رمضان كريم', 540, 860, size: 210, color: 0xFFFFC857, font: 'Amiri'),
      _text('تقبل الله طاعاتكم', 540, 1130, size: 66, bold: false),
    ]);
  }),
  TemplateDef('o_baby', 'مولود جديد', 'مناسبات', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFFFFF1F5);
    d.layers.addAll([
      _shape(ShapeKind.circle, 240, 300, 260, 260, color: 0xFFFFB3C7),
      _shape(ShapeKind.circle, 440, 220, 220, 220, color: 0xFFB3D9FF),
      _shape(ShapeKind.circle, 650, 290, 250, 250, color: 0xFFFFE08A),
      _shape(ShapeKind.circle, 850, 210, 200, 200, color: 0xFFC9F0D0),
      _shape(ShapeKind.rect, 345, 540, 4, 280, color: 0xFFB0B0B0),
      _text('أهلاً بالقادم الجديد', 540, 820, w: 880, size: 120, color: 0xFFE0577F, lh: 1.15),
      _text('اسم المولود', 540, 1080, size: 90, color: 0xFF4A4A68),
      _text('الحمد لله على سلامة الأم والمولود', 540, 1230, w: 860, size: 46, bold: false, color: 0xFF7A7A90),
    ]);
  }),
  TemplateDef('o_grad', 'مبروك التخرج', 'مناسبات', 1080, 1080, const ['Cairo', 'Amiri'], (d) {
    _bg(d, 0xFF0F0F0F);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 540, 980, 980, color: _clear, stroke: 5, strokeColor: 0xFFD4AF37),
      _shape(ShapeKind.triangle, 150, 180, 60, 60, color: 0xFFFF4081, rot: 0.4),
      _shape(ShapeKind.circle, 900, 220, 40, 40, color: 0xFF40C4FF),
      _shape(ShapeKind.triangle, 860, 860, 70, 70, color: 0xFFFFD54F, rot: 2.4),
      _shape(ShapeKind.circle, 190, 840, 46, 46, color: 0xFF69F0AE),
      _text('مبروك', 540, 400, size: 230, color: 0xFFD4AF37, font: 'Amiri'),
      _text('التخرج', 540, 620, size: 170),
      _text('اسم الخريج', 540, 840, size: 72, bold: false, color: 0xFFE0E0E0),
    ]);
  }),
  TemplateDef('o_open', 'افتتاح قريباً', 'مناسبات', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF111827);
    d.layers.addAll([
      _shape(ShapeKind.circle, 300, 200, 700, 700, color: 0xFFFFFFFF, opacity: 0.05),
      _shape(ShapeKind.circle, 820, 800, 800, 800, color: 0xFFFFFFFF, opacity: 0.05),
      _shape(ShapeKind.rect, 540, 540, 1500, 220, color: 0xFFFF3D71, rot: -0.35),
      _text('افتتاح قريباً', 540, 540, w: 1000, size: 150)..rotation = -0.35,
      _text('ترقبوا الإعلان عن الموعد', 540, 900, size: 60, bold: false, color: 0xFFCBD5E1),
    ]);
  }),
  // ───────── رياضة ─────────
  TemplateDef('s_challenge', 'تحدي ٣٠ يوماً', 'رياضة', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFF0A0A0A);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 1000, 1500, 150, color: 0xFFC6FF00, rot: -0.12),
      _text('30', 540, 440, w: 900, size: 560, color: _clear, stroke: 6, strokeColor: 0xFFFFFFFF),
      _text('يوم تحدي', 540, 880, size: 150),
      _text('ابدأ اليوم', 540, 1000, w: 700, size: 76, color: 0xFF0A0A0A)..rotation = -0.12,
      _text('سجّل الآن واحصل على خطتك', 540, 1220, size: 52, bold: false, color: 0xFFC6FF00),
    ]);
  }),
  TemplateDef('s_match', 'مباراة', 'رياضة', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF0D47A1);
    d.layers.addAll([
      _shape(ShapeKind.rect, 810, 540, 540, 1080, color: 0xFFC62828),
      _shape(ShapeKind.circle, 540, 540, 300, 300, color: 0xFFFFFFFF),
      _text('VS', 540, 540, w: 260, size: 130, color: 0xFF111111),
      _text('الفريق الأول', 270, 300, w: 440, size: 74),
      _text('الفريق الثاني', 810, 300, w: 440, size: 74),
      _text('السبت  8:00 م', 540, 900, size: 70),
      _text('الملعب الرئيسي', 540, 1000, size: 48, bold: false, opacity: 0.85),
    ]);
  }),
  // ───────── تعليم ─────────
  TemplateDef('e_cert', 'شهادة تقدير', 'تعليم', 1350, 1000, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFFFFFBF0);
    d.layers.addAll([
      _shape(ShapeKind.rect, 675, 500, 1290, 940, color: _clear, stroke: 10, strokeColor: 0xFF1B3A6B),
      _shape(ShapeKind.rect, 675, 500, 1230, 880, color: _clear, stroke: 2, strokeColor: 0xFFC9A227),
      _text('شهادة تقدير', 675, 190, size: 130, color: 0xFF1B3A6B, font: 'Amiri'),
      _text('تُمنح هذه الشهادة إلى', 675, 330, size: 50, bold: false, color: 0xFF555555),
      _text('اسم المستلم', 675, 450, size: 110, color: 0xFFC9A227, font: 'Amiri'),
      _shape(ShapeKind.rect, 675, 540, 600, 4, color: 0xFF1B3A6B),
      _text('تقديراً لجهوده المتميزة وتفوقه خلال الفترة الماضية', 675, 640, w: 960, size: 48, bold: false, color: 0xFF333333, lh: 1.5),
      _shape(ShapeKind.star, 675, 810, 150, 150, color: 0xFFC9A227),
      _text('التاريخ', 260, 860, size: 40, bold: false, color: 0xFF555555),
      _text('التوقيع', 1090, 860, size: 40, bold: false, color: 0xFF555555),
    ]);
  }),
  TemplateDef('e_course', 'إعلان دورة', 'تعليم', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFFF4F7FF);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 250, 1080, 500, g1: 0xFF3949AB, g2: 0xFF1A237E, angle: 90),
      _shape(ShapeKind.circle, 540, 500, 700, 700, color: 0xFFF4F7FF),
      _text('دورة', 540, 190, size: 90, bold: false),
      _text('التصميم الجرافيكي', 540, 330, w: 900, size: 120),
      _text('ما ستتعلمه', 540, 650, size: 60, color: 0xFF1A237E),
      _shape(ShapeKind.circle, 880, 790, 54, 54, color: 0xFF43A047),
      _text('أساسيات التصميم', 480, 790, w: 700, size: 52, color: 0xFF263238),
      _shape(ShapeKind.circle, 880, 910, 54, 54, color: 0xFF43A047),
      _text('العمل على الألوان والخطوط', 480, 910, w: 700, size: 52, color: 0xFF263238),
      _shape(ShapeKind.circle, 880, 1030, 54, 54, color: 0xFF43A047),
      _text('مشروع تطبيقي كامل', 480, 1030, w: 700, size: 52, color: 0xFF263238),
      _shape(ShapeKind.rect, 540, 1210, 600, 100, color: 0xFFFFB300, radius: 50),
      _text('سجّل الآن', 540, 1210, size: 56, color: 0xFF1A237E),
    ]);
  }),
  // ───────── متجر ─────────
  TemplateDef('sh_black', 'الجمعة السوداء', 'متجر', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF050505);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 540, 900, 900, color: _clear, stroke: 3, strokeColor: 0xFFFFFFFF, opacity: 0.18),
      _shape(ShapeKind.rect, 540, 250, 560, 110, color: 0xFFE50914, radius: 8, rot: -0.04),
      _text('عروض', 540, 250, size: 76),
      _text('الجمعة', 540, 470, size: 190),
      _text('السوداء', 540, 660, size: 190, color: 0xFFE50914),
      _text('خصومات حتى 70%', 540, 880, size: 78, color: 0xFFFFD600),
      _text('لمدة 3 أيام فقط', 540, 980, size: 44, bold: false, opacity: 0.8),
    ]);
  }),
  TemplateDef('sh_tag', 'وصل حديثاً', 'متجر', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFFFFE9EC);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 520, 620, 620, color: 0xFFFFFFFF),
      _text('ضع صورة المنتج', 540, 520, w: 440, size: 54, color: 0xFFC9A0A8, bold: false),
      _shape(ShapeKind.rect, 840, 250, 300, 130, color: 0xFFD81B60, radius: 20, rot: 0.2),
      _text('99 ر.س', 840, 250, w: 280, size: 64)..rotation = 0.2,
      _text('وصل حديثاً', 540, 930, size: 130, color: 0xFF880E4F),
      _text('كمية محدودة', 540, 1030, size: 46, bold: false, color: 0xFFB04566),
    ]);
  }),
  TemplateDef('sh_coupon', 'كوبون خصم', 'متجر', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF6A1B9A, 0xFF311B92, 160);
    d.layers.addAll([
      _text('هدية لك', 540, 420, size: 150),
      _shape(ShapeKind.rect, 540, 960, 880, 560, color: 0xFFFFFFFF, radius: 36),
      _shape(ShapeKind.circle, 100, 960, 120, 120, color: 0xFF4A148C),
      _shape(ShapeKind.circle, 980, 960, 120, 120, color: 0xFF4A148C),
      _text('خصم', 540, 800, size: 90, color: 0xFF4A148C),
      _text('25%', 540, 960, size: 220, color: 0xFFD81B60),
      _dashed(_shape(ShapeKind.rect, 540, 1160, 660, 110, color: _clear, stroke: 4, strokeColor: 0xFF4A148C, radius: 12)),
      _text('كود: SAVE25', 540, 1160, w: 620, size: 62, color: 0xFF4A148C),
      _text('صالح حتى نهاية الشهر', 540, 1500, size: 54, bold: false, opacity: 0.9),
    ]);
  }),
  // ───────── سفر ─────────
  TemplateDef('t_sea', 'رحلة بحرية', 'سفر', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFFFF9A5A, 0xFFFFD9A0, 90);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 780, 460, 460, color: 0xFFFFF3C4),
      _shape(ShapeKind.circle, 540, 1900, 2000, 1000, color: 0xFF0288D1),
      _shape(ShapeKind.circle, 540, 2050, 2200, 1000, color: 0xFF01579B),
      _text('رحلتك القادمة', 540, 340, w: 900, size: 150, color: 0xFF5D2A00),
      _text('تبدأ من هنا', 540, 520, size: 80, bold: false, color: 0xFF8A4B15),
      _text('احجز الآن', 540, 1560, size: 90),
    ]);
  }),
  TemplateDef('t_ticket', 'تذكرة سفر', 'سفر', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF1E88E5, 0xFF0D47A1, 135);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 540, 940, 520, color: 0xFFFFFFFF, radius: 30),
      _shape(ShapeKind.circle, 70, 540, 100, 100, color: 0xFF1668C0),
      _shape(ShapeKind.circle, 1010, 540, 100, 100, color: 0xFF1668C0),
      _text('تذكرة سفر', 540, 340, size: 70, color: 0xFF0D47A1),
      _text('الرياض', 820, 500, w: 300, size: 96, color: 0xFF263238),
      _text('دبي', 260, 500, w: 300, size: 96, color: 0xFF263238),
      _shape(ShapeKind.triangle, 540, 500, 70, 70, color: 0xFF1E88E5, rot: -1.5708),
      _text('التاريخ  15 / 12', 540, 660, size: 52, bold: false, color: 0xFF546E7A),
      _text('احجز مقعدك الآن', 540, 880, size: 80),
    ]);
  }),
  // ───────── صحة ─────────
  TemplateDef('h_tip', 'نصيحة صحية', 'صحة', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFFF1F8E9);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 330, 330, 330, color: 0xFF2E7D32),
      _shape(ShapeKind.rect, 540, 330, 190, 56, color: 0xFFFFFFFF, radius: 10),
      _shape(ShapeKind.rect, 540, 330, 56, 190, color: 0xFFFFFFFF, radius: 10),
      _text('نصيحة اليوم', 540, 620, size: 70, color: 0xFF2E7D32),
      _text('اشرب ثمانية أكواب ماء يومياً', 540, 800, w: 880, size: 100, color: 0xFF1B3A1E, lh: 1.25),
      _text('لصحة أفضل وجسم نشيط', 540, 1000, size: 46, bold: false, color: 0xFF5C7A5E),
    ]);
  }),
  // ───────── تقنية ─────────
  TemplateDef('te_app', 'إطلاق تطبيق', 'تقنية', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF0F0C29, 0xFF302B63, 160);
    d.layers.addAll([
      _shape(ShapeKind.circle, 200, 300, 600, 600, color: 0xFF7C4DFF, opacity: 0.25),
      _shape(ShapeKind.rect, 540, 820, 480, 900, color: 0xFF1B1B2F, radius: 70, stroke: 8, strokeColor: 0xFFB388FF),
      _shape(ShapeKind.rect, 540, 820, 420, 820, g1: 0xFF7C4DFF, g2: 0xFF00E5FF, angle: 135, radius: 50),
      _text('تطبيقك', 540, 800, w: 380, size: 80),
      _text('نزّل الآن', 540, 1500, size: 110),
      _text('متوفر على أندرويد و آيفون', 540, 1650, size: 50, bold: false, opacity: 0.8),
    ]);
  }),
  TemplateDef('te_code', 'نافذة برمجة', 'تقنية', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF0D1117);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 560, 900, 700, color: 0xFF161B22, radius: 24, stroke: 3, strokeColor: 0xFF30363D),
      _shape(ShapeKind.circle, 160, 260, 36, 36, color: 0xFFFF5F56),
      _shape(ShapeKind.circle, 220, 260, 36, 36, color: 0xFFFFBD2E),
      _shape(ShapeKind.circle, 280, 260, 36, 36, color: 0xFF27C93F),
      _shape(ShapeKind.rect, 380, 400, 400, 28, color: 0xFF58A6FF, radius: 14),
      _shape(ShapeKind.rect, 460, 470, 560, 28, color: 0xFF7EE787, radius: 14),
      _shape(ShapeKind.rect, 330, 540, 300, 28, color: 0xFFD2A8FF, radius: 14),
      _shape(ShapeKind.rect, 520, 610, 680, 28, color: 0xFF8B949E, radius: 14),
      _shape(ShapeKind.rect, 400, 680, 440, 28, color: 0xFFFFA657, radius: 14),
      _text('تعلّم البرمجة', 540, 900, size: 120),
      _text('من الصفر حتى الاحتراف', 540, 1010, size: 50, bold: false, color: 0xFF8B949E),
    ]);
  }),
  // ───────── أعمال ─────────
  TemplateDef('b_card', 'بطاقة عمل', 'أعمال', 1050, 600, const ['Cairo'], (d) {
    _bg(d, 0xFFFFFFFF);
    d.layers.addAll([
      _shape(ShapeKind.rect, 120, 300, 240, 600, g1: 0xFF0B3C6E, g2: 0xFF1E88E5, angle: 90),
      _shape(ShapeKind.circle, 120, 300, 110, 110, color: 0xFFFFFFFF),
      _text('ش', 120, 295, w: 100, size: 80, color: 0xFF0B3C6E),
      _text('الاسم الكامل', 650, 190, w: 640, size: 80, color: 0xFF0B3C6E),
      _text('المسمى الوظيفي', 650, 275, w: 640, size: 42, bold: false, color: 0xFF607D8B),
      _shape(ShapeKind.rect, 650, 330, 640, 3, color: 0xFFCFD8DC),
      _text('0500 000 000', 650, 400, w: 640, size: 42, color: 0xFF263238),
      _text('name@email.com', 650, 465, w: 640, size: 38, color: 0xFF263238, bold: false),
      _text('www.example.com', 650, 525, w: 640, size: 38, color: 0xFF1E88E5, bold: false),
    ]);
  }),
  TemplateDef('b_hire', 'نبحث عنك', 'أعمال', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFFFFD600);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 1130, 1080, 440, color: 0xFF111111),
      _text('نبحث', 540, 270, size: 250, color: 0xFF111111),
      _text('عنك!', 540, 520, size: 250, color: 0xFF111111),
      _text('مطلوب موظفين بدوام كامل', 540, 760, w: 900, size: 70, color: 0xFF111111, bold: false),
      _text('أرسل سيرتك الذاتية إلى', 540, 1020, size: 52, color: 0xFFFFD600, bold: false),
      _text('jobs@company.com', 540, 1140, size: 78, color: 0xFFFFFFFF),
      _text('التقديم مفتوح حتى نهاية الشهر', 540, 1260, size: 44, color: 0xFFBDBDBD, bold: false),
    ]);
  }),
  TemplateDef('b_price', 'قائمة خدمات', 'أعمال', 1080, 1350, const ['Cairo'], (d) {
    _bg(d, 0xFFF3F4F8);
    d.layers.addAll([
      _text('باقات الأسعار', 540, 150, size: 100, color: 0xFF1F2A44),
      _shape(ShapeKind.rect, 200, 700, 290, 800, color: 0xFFFFFFFF, radius: 28),
      _text('الأساسية', 200, 430, w: 250, size: 52, color: 0xFF1F2A44),
      _text('99', 200, 560, w: 250, size: 110, color: 0xFF3F51B5),
      _text('خدمة واحدة\nدعم بريد\nتقرير شهري', 200, 800, w: 250, size: 38, bold: false, color: 0xFF546E7A, lh: 1.8),
      _shape(ShapeKind.rect, 540, 700, 310, 860, g1: 0xFF3F51B5, g2: 0xFF1A237E, angle: 90, radius: 28),
      _text('المميزة', 540, 410, w: 270, size: 56),
      _text('199', 540, 550, w: 270, size: 120, color: 0xFFFFD54F),
      _text('3 خدمات\nدعم هاتفي\nتقارير أسبوعية', 540, 810, w: 270, size: 38, bold: false, lh: 1.8),
      _shape(ShapeKind.rect, 880, 700, 290, 800, color: 0xFFFFFFFF, radius: 28),
      _text('الاحترافية', 880, 430, w: 250, size: 52, color: 0xFF1F2A44),
      _text('399', 880, 560, w: 250, size: 110, color: 0xFF3F51B5),
      _text('خدمات مفتوحة\nمدير حساب\nتقارير يومية', 880, 800, w: 250, size: 38, bold: false, color: 0xFF546E7A, lh: 1.8),
      _text('الأسعار شهرية بالريال', 540, 1250, size: 44, bold: false, color: 0xFF78859B),
    ]);
  }),
  TemplateDef('b_thanks', 'شكراً لك', 'أعمال', 1080, 1080, const ['Amiri', 'Cairo'], (d) {
    _bg(d, 0xFFFFFFFF);
    d.layers.addAll([
      _shape(ShapeKind.circle, 540, 540, 900, 900, color: 0xFFFFF0E0),
      _shape(ShapeKind.circle, 540, 540, 640, 640, color: 0xFFFFE0BD),
      _text('شكراً', 540, 450, size: 260, color: 0xFFE65100, font: 'Amiri'),
      _text('لثقتكم بنا', 540, 690, size: 100, color: 0xFF5D2A00),
      _text('نعدكم بالأفضل دائماً', 540, 850, size: 48, bold: false, color: 0xFF8A5A2B),
    ]);
  }),
  // ───────── منشور / ستوري ─────────
  TemplateDef('p_type', 'خط كبير', 'منشور', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFFF8F8F8);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 560, 760, 190, color: 0xFFFFE066, rot: -0.03),
      _text('الفكرة', 540, 300, size: 300, color: 0xFF111111),
      _text('تغيّر', 540, 560, size: 300, color: 0xFF111111),
      _text('كل شيء', 540, 820, size: 300, color: 0xFF111111),
      _text('@حسابك', 540, 1010, size: 46, bold: false, color: 0xFF777777),
    ]);
  }),
  TemplateDef('p_contest', 'مسابقة وجائزة', 'منشور', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF6A1B9A, 0xFFAD1457, 135);
    d.layers.addAll([
      _shape(ShapeKind.circle, 160, 160, 40, 40, color: 0xFFFFD54F),
      _shape(ShapeKind.triangle, 900, 200, 60, 60, color: 0xFF69F0AE, rot: 0.5),
      _shape(ShapeKind.circle, 960, 640, 50, 50, color: 0xFF40C4FF),
      _shape(ShapeKind.triangle, 140, 700, 56, 56, color: 0xFFFF80AB, rot: 2.1),
      _shape(ShapeKind.rect, 540, 460, 400, 280, color: 0xFFFFD54F, radius: 24),
      _shape(ShapeKind.rect, 540, 460, 60, 280, color: 0xFFE53935),
      _shape(ShapeKind.rect, 540, 460, 400, 60, color: 0xFFE53935),
      _text('سحب على جائزة', 540, 770, w: 920, size: 120),
      _text('شارك المنشور وتابع الصفحة', 540, 940, size: 56, bold: false, color: 0xFFFFD54F),
    ]);
  }),
  TemplateDef('p_podcast', 'بودكاست', 'منشور', 1080, 1080, const ['Cairo'], (d) {
    _bg(d, 0xFF141414);
    d.layers.addAll([
      _shape(ShapeKind.circle, 700, 420, 700, 700, color: 0xFF222222),
      _shape(ShapeKind.circle, 700, 420, 560, 560, color: _clear, stroke: 3, strokeColor: 0xFF3A3A3A),
      _shape(ShapeKind.circle, 700, 420, 420, 420, color: _clear, stroke: 3, strokeColor: 0xFF3A3A3A),
      _shape(ShapeKind.circle, 700, 420, 200, 200, color: 0xFFFF5722),
      _shape(ShapeKind.circle, 700, 420, 30, 30, color: 0xFF141414),
      _text('بودكاست', 300, 820, w: 520, size: 130, color: 0xFFFF5722),
      _text('الحلقة الجديدة', 330, 960, w: 520, size: 56, bold: false),
    ]);
  }),
  TemplateDef('p_gaming', 'غلاف ألعاب', 'يوتيوب', 1280, 720, const ['Cairo'], (d) {
    _bg(d, 0xFF0B0221, 0xFF3A0CA3, 120);
    d.layers.addAll([
      _shape(ShapeKind.triangle, 1000, 200, 420, 420, color: 0xFF00E5FF, opacity: 0.25, rot: 0.3),
      _shape(ShapeKind.hexagon, 220, 560, 330, 330, color: _clear, stroke: 8, strokeColor: 0xFFFF2BD6),
      _text('تحدي', 640, 230, size: 220, color: 0xFF00E5FF, stroke: 10, strokeColor: 0xFF0B0221),
      _text('مستحيل', 640, 460, size: 220, color: 0xFFFF2BD6, stroke: 10, strokeColor: 0xFF0B0221),
      _text('الجزء الأخير', 640, 640, size: 70),
    ]);
  }),
  TemplateDef('st_ask', 'اسألني', 'ستوري', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFFFF9966, 0xFFFF5E62, 160);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 900, 860, 520, color: 0xFFFFFFFF, radius: 50),
      _shape(ShapeKind.rect, 540, 700, 860, 140, color: 0xFFFF5E62, radius: 50),
      _shape(ShapeKind.rect, 540, 770, 860, 70, color: 0xFFFF5E62),
      _text('اسألني أي شيء', 540, 700, w: 800, size: 74),
      _text('اكتب سؤالك هنا...', 540, 960, size: 60, bold: false, color: 0xFFB0B0B0),
      _text('سأجيب على أسئلتكم اليوم', 540, 1350, size: 60, bold: false),
    ]);
  }),
  TemplateDef('st_poll', 'تصويت', 'ستوري', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFF1A1A2E, 0xFF16213E, 160);
    d.layers.addAll([
      _text('رأيك يهمنا', 540, 520, size: 130),
      _text('ما الخيار الأفضل؟', 540, 700, size: 70, bold: false, color: 0xFFB0BEC5),
      _shape(ShapeKind.rect, 540, 1020, 800, 200, color: 0xFF2E7D32, radius: 100),
      _text('الخيار الأول', 540, 1020, size: 78),
      _shape(ShapeKind.rect, 540, 1300, 800, 200, color: 0xFFC62828, radius: 100),
      _text('الخيار الثاني', 540, 1300, size: 78),
    ]);
  }),
  TemplateDef('st_new', 'وصل حديثاً ستوري', 'ستوري', 1080, 1920, const ['Cairo'], (d) {
    _bg(d, 0xFFFFFFFF);
    d.layers.addAll([
      _shape(ShapeKind.rect, 540, 540, 1080, 1080, g1: 0xFFFF6F61, g2: 0xFFDE6262, angle: 135),
      _shape(ShapeKind.circle, 540, 1080, 520, 520, color: 0xFFFFFFFF),
      _text('جديد', 540, 380, size: 330),
      _text('ضع صورة المنتج', 540, 1080, w: 380, size: 52, color: 0xFFC8A0A0, bold: false),
      _text('وصل حديثاً', 540, 1500, size: 130, color: 0xFFDE4A4A),
      _text('اطلبه الآن من الرابط', 540, 1680, size: 56, bold: false, color: 0xFF666666),
    ]);
  }),
];
