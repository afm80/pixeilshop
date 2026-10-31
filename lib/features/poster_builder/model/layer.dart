import 'dart:math' as math;
import 'dart:ui';

import 'adjust.dart';

/// draw = طبقة رسم حر (فرشاة). يُضاف في النهاية للحفاظ على فهارس المشاريع المحفوظة.
enum LayerType { text, image, shape, draw }

enum ShapeKind { rect, circle, triangle, star, diamond, line, cone, pentagon, hexagon, heptagon, octagon, nonagon, decagon }

/// ضربة ممحاة (BlendMode.clear) بإحداثيات نسبية لعرض الطبقة.
class EraseStroke {
  EraseStroke(this.r, [List<double>? pts]) : pts = pts ?? <double>[];
  final double r; // نصف القطر نسبةً إلى عرض الطبقة
  final List<double> pts; // x0,y0,x1,y1... (مقسومة على عرض الطبقة)

  Map<String, dynamic> toJson() => {'r': r, 'p': pts};
  factory EraseStroke.fromJson(Map<String, dynamic> m) => EraseStroke(
        (m['r'] as num).toDouble(),
        (m['p'] as List).map((e) => (e as num).toDouble()).toList(),
      );
}

/// ضربة فرشاة. النقاط x0,y0,x1,y1... بإحداثيات محلية (مركز الطبقة = صفر).
class BrushStroke {
  BrushStroke({required this.color, required this.width, this.erase = false, this.dashed = false, List<double>? pts})
      : pts = pts ?? <double>[];
  final int color;
  final double width;
  final bool erase; // ممحاة (BlendMode.clear) داخل طبقة الرسم
  final bool dashed;
  final List<double> pts;

  Map<String, dynamic> toJson() => {'c': color, 'w': width, 'e': erase, 'd': dashed, 'p': pts};
  factory BrushStroke.fromJson(Map<String, dynamic> m) => BrushStroke(
        color: (m['c'] as num).toInt(),
        width: (m['w'] as num).toDouble(),
        erase: (m['e'] as bool?) ?? false,
        dashed: (m['d'] as bool?) ?? false,
        pts: ((m['p'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
      );
}

int _idCounter = 0;

class Layer {
  Layer({required this.id, required this.type, this.name = ''});

  factory Layer.create(LayerType type, {String name = ''}) =>
      Layer(id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}', type: type, name: name);

  final String id;
  final LayerType type;
  String name;

  // التحويل: (x,y) مركز الطبقة بإحداثيات التصميم
  double x = 0, y = 0, scale = 1, rotation = 0, opacity = 1;
  bool flipX = false, hidden = false, locked = false;
  int blend = 0;

  // الظل
  bool shOn = false;
  int shColor = 0xFF000000;
  double shBlur = 14, shDx = 8, shDy = 12, shOpacity = 0.5;
  bool shGround = false;

  Adjust adj = Adjust();

  // الحجم (نص: w هو عرض صندوق النص)
  double w = 300, h = 300;

  // نص
  String text = '';
  String font = 'Cairo';
  double fontSize = 96;
  int color = 0xFFFFFFFF;
  bool bold = true, italic = false;
  int align = 1; // 0 يسار، 1 وسط، 2 يمين
  double letterSpacing = 0, lineHeight = 1.2;
  double strokeW = 0;
  int strokeColor = 0xFF000000;
  bool boxOn = false;
  int boxColor = 0xFF000000;
  double boxRadius = 24;
  /// نوع التعبئة: 0 لون، 1 تدرج خطي، 2 تدرج دائري، 3 نقشة، 4 صورة.
  int fillKind = 0;
  bool get gradOn => fillKind == 1 || fillKind == 2;
  set gradOn(bool v) {
    if (v) {
      if (!gradOn) fillKind = 1;
    } else {
      fillKind = 0;
    }
  }

  int grad1 = 0xFFFFD54F, grad2 = 0xFFFF5252; // ألوان التدرج، وهي ألوان النقشة أيضاً
  double gradAngle = 90;
  int fillPattern = 0; // 0 خطوط، 1 نقاط، 2 شبكة، 3 رقعة شطرنج، 4 مائل
  double patSize = 40;
  String? fillPath; // صورة التعبئة

  // خط متقطع (حدود الأشكال والصور)
  bool dashed = false;
  double dashLen = 18;

  // تظليل النص (highlight) وانعكاسه
  bool hlOn = false;
  int hlColor = 0xFFFFEB3B;
  // عمق النص (extrude) وانحناؤه (skew)
  bool depthOn = false;
  int depthColor = 0xFF000000;
  double depthLen = 20, depthAngle = 45;
  double skewX = 0, skewY = 0; // بالدرجات
  bool reflOn = false;
  double reflOpacity = 0.4, reflGap = 6;

  /// طبقات تحمل نفس المعرّف تتحرك وتتحول معاً.
  String? groupId;

  // رسم حر
  List<BrushStroke> strokes = [];

  // صورة
  String? path;
  List<EraseStroke> erase = [];

  // شكل
  ShapeKind shape = ShapeKind.rect;
  double cornerRadius = 0;

  /// نقطة محلية (مركزها صفر) -> إحداثيات التصميم.
  Offset localToDoc(Offset l) {
    final dx = (flipX ? -l.dx : l.dx) * scale;
    final dy = l.dy * scale;
    final c = math.cos(rotation), s = math.sin(rotation);
    return Offset(x + dx * c - dy * s, y + dx * s + dy * c);
  }

  /// إحداثيات التصميم -> نقطة محلية.
  Offset docToLocal(Offset p) {
    final dx = p.dx - x, dy = p.dy - y;
    final c = math.cos(-rotation), s = math.sin(-rotation);
    var lx = (dx * c - dy * s) / scale;
    final ly = (dx * s + dy * c) / scale;
    if (flipX) lx = -lx;
    return Offset(lx, ly);
  }

  Layer clone({bool newId = false}) {
    final j = toJson();
    final l = Layer.fromJson(j);
    if (!newId) return l;
    final n = Layer.create(type, name: name);
    final jj = l.toJson()..['id'] = n.id;
    return Layer.fromJson(jj);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        't': type.index,
        'n': name,
        'x': x,
        'y': y,
        'sc': scale,
        'r': rotation,
        'o': opacity,
        'fx': flipX,
        'hd': hidden,
        'lk': locked,
        'bm': blend,
        'so': shOn,
        'sc2': shColor,
        'sb': shBlur,
        'sdx': shDx,
        'sdy': shDy,
        'sop': shOpacity,
        'sg': shGround,
        'adj': adj.toJson(),
        'w': w,
        'h': h,
        'tx': text,
        'f': font,
        'fs': fontSize,
        'c': color,
        'b': bold,
        'i': italic,
        'al': align,
        'ls': letterSpacing,
        'lh': lineHeight,
        'sw': strokeW,
        'scol': strokeColor,
        'bo': boxOn,
        'bc': boxColor,
        'br': boxRadius,
        'go': gradOn,
        'fk': fillKind,
        'ga': gradAngle,
        'fp': fillPattern,
        'ps': patSize,
        'fpath': fillPath,
        'ds': dashed,
        'dl': dashLen,
        'hl': hlOn,
        'hc': hlColor,
        'dpo': depthOn,
        'dpc': depthColor,
        'dpl': depthLen,
        'dpa': depthAngle,
        'skx': skewX,
        'sky': skewY,
        'rf': reflOn,
        'ro': reflOpacity,
        'rg': reflGap,
        'gid': groupId,
        'bs': strokes.map((e) => e.toJson()).toList(),
        'g1': grad1,
        'g2': grad2,
        'p': path,
        'er': erase.map((e) => e.toJson()).toList(),
        'sh': shape.index,
        'cr': cornerRadius,
      };

  factory Layer.fromJson(Map<String, dynamic> m) {
    double d(String k, double def) => (m[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (m[k] as num?)?.toInt() ?? def;
    bool b(String k, bool def) => (m[k] as bool?) ?? def;
    final l = Layer(
      id: m['id'] as String,
      type: LayerType.values[i('t', 0)],
      name: (m['n'] as String?) ?? '',
    );
    l.x = d('x', 0);
    l.y = d('y', 0);
    l.scale = d('sc', 1);
    l.rotation = d('r', 0);
    l.opacity = d('o', 1);
    l.flipX = b('fx', false);
    l.hidden = b('hd', false);
    l.locked = b('lk', false);
    l.blend = i('bm', 0);
    l.shOn = b('so', false);
    l.shColor = i('sc2', 0xFF000000);
    l.shBlur = d('sb', 14);
    l.shDx = d('sdx', 8);
    l.shDy = d('sdy', 12);
    l.shOpacity = d('sop', 0.5);
    l.shGround = b('sg', false);
    l.adj = Adjust.fromJson(m['adj'] == null ? null : Map<String, dynamic>.from(m['adj'] as Map));
    l.w = d('w', 300);
    l.h = d('h', 300);
    l.text = (m['tx'] as String?) ?? '';
    l.font = (m['f'] as String?) ?? 'Cairo';
    l.fontSize = d('fs', 96);
    l.color = i('c', 0xFFFFFFFF);
    l.bold = b('b', true);
    l.italic = b('i', false);
    l.align = i('al', 1);
    l.letterSpacing = d('ls', 0);
    l.lineHeight = d('lh', 1.2);
    l.strokeW = d('sw', 0);
    l.strokeColor = i('scol', 0xFF000000);
    l.boxOn = b('bo', false);
    l.boxColor = i('bc', 0xFF000000);
    l.boxRadius = d('br', 24);
    l.fillKind = i('fk', b('go', false) ? 1 : 0);
    l.gradAngle = d('ga', l.type == LayerType.shape ? 45 : 90);
    l.fillPattern = i('fp', 0);
    l.patSize = d('ps', 40);
    l.fillPath = m['fpath'] as String?;
    l.dashed = b('ds', false);
    l.dashLen = d('dl', 18);
    l.hlOn = b('hl', false);
    l.hlColor = i('hc', 0xFFFFEB3B);
    l.depthOn = b('dpo', false);
    l.depthColor = i('dpc', 0xFF000000);
    l.depthLen = d('dpl', 20);
    l.depthAngle = d('dpa', 45);
    l.skewX = d('skx', 0);
    l.skewY = d('sky', 0);
    l.reflOn = b('rf', false);
    l.reflOpacity = d('ro', 0.4);
    l.reflGap = d('rg', 6);
    l.groupId = m['gid'] as String?;
    l.strokes = ((m['bs'] as List?) ?? const [])
        .map((e) => BrushStroke.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    l.grad1 = i('g1', 0xFFFFD54F);
    l.grad2 = i('g2', 0xFFFF5252);
    l.path = m['p'] as String?;
    l.erase = ((m['er'] as List?) ?? const [])
        .map((e) => EraseStroke.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    l.shape = ShapeKind.values[i('sh', 0)];
    l.cornerRadius = d('cr', 0);
    return l;
  }
}
