import 'dart:math' as math;
import 'package:flutter/material.dart';
double _cos(double a) => math.cos(a);
double _sin(double a) => math.sin(a);

enum LT { text, image, shape }
double _d(dynamic v, [double def = 0]) => v == null ? def : (v as num).toDouble();

class Layer {
  Layer(this.type, {String? id}) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  LT type;
  double x = 0, y = 0, scale = 1, rot = 0, opacity = 1;
  double size = 120, spacing = 0, strokeW = 0, shadowBlur = 0, depth = 0;
  double lh = 1.25, curve = 0;
  int align = 1;
  double w = 400, h = 400, radius = 0, bright = 0, contrast = 1, sat = 1, blur = 0;
  bool hidden = false, locked = false, flip = false, bold = true;
  String text = 'اكتب هنا', font = 'Cairo', shape = 'rect';
  String? path;
  Color color = Colors.white, stroke = Colors.black, shadow = Colors.black;
  bool grad = false, radial = false;
  Color g1 = const Color(0xFFD01515), g2 = const Color(0xFF333333);
  double gAngle = 0, skew = 0;
  int blend = 0;
  bool tbg = false;
  Color tbgColor = Colors.black;
  double tbgR = 20;

  Map<String, dynamic> toJson() => {
        'id': id, 't': type.index, 'x': x, 'y': y, 'sc': scale, 'r': rot, 'o': opacity,
        'sz': size, 'sp': spacing, 'sw': strokeW, 'sb': shadowBlur, 'dp': depth, 'lh': lh, 'cv': curve, 'al': align,
        'w': w, 'h': h, 'rd': radius, 'br': bright, 'ct': contrast, 'sa': sat, 'bl': blur,
        'hd': hidden, 'lk': locked, 'fl': flip, 'b': bold, 'tx': text, 'f': font, 'sh': shape,
        'p': path, 'c': color.value, 's': stroke.value, 'sd': shadow.value,
        'gr': grad, 'gz': radial, 'g1': g1.value, 'g2': g2.value, 'ga': gAngle, 'sk': skew, 'bm': blend, 'tb': tbg, 'tc': tbgColor.value, 'tr': tbgR,
      };

  factory Layer.fromJson(Map<String, dynamic> m, {bool fresh = false}) {
    final l = Layer(LT.values[m['t'] as int], id: fresh ? null : m['id'] as String?);
    l.x = _d(m['x']); l.y = _d(m['y']); l.scale = _d(m['sc'], 1); l.rot = _d(m['r']); l.opacity = _d(m['o'], 1);
    l.size = _d(m['sz'], 120); l.spacing = _d(m['sp']); l.strokeW = _d(m['sw']);
    l.shadowBlur = _d(m['sb']); l.depth = _d(m['dp']); l.lh = _d(m['lh'], 1.25); l.curve = _d(m['cv']); l.align = (m['al'] ?? 1) as int; l.w = _d(m['w'], 400); l.h = _d(m['h'], 400);
    l.radius = _d(m['rd']); l.bright = _d(m['br']); l.contrast = _d(m['ct'], 1); l.sat = _d(m['sa'], 1); l.blur = _d(m['bl']);
    l.hidden = m['hd'] ?? false; l.locked = m['lk'] ?? false; l.flip = m['fl'] ?? false; l.bold = m['b'] ?? true;
    l.text = m['tx'] ?? ''; l.font = m['f'] ?? 'Cairo'; l.shape = m['sh'] ?? 'rect'; l.path = m['p'];
    l.color = Color(m['c'] as int); l.stroke = Color(m['s'] as int); l.shadow = Color(m['sd'] as int);
    l.grad = m['gr'] ?? false; l.radial = m['gz'] ?? false; l.gAngle = _d(m['ga']); l.skew = _d(m['sk']); l.blend = (m['bm'] ?? 0) as int;
    l.tbg = m['tb'] ?? false; l.tbgR = _d(m['tr'], 20);
    if (m['tc'] != null) l.tbgColor = Color(m['tc'] as int);
    if (m['g1'] != null) l.g1 = Color(m['g1'] as int);
    if (m['g2'] != null) l.g2 = Color(m['g2'] as int);
    return l;
  }
}

/// تدرج الطبقة (خطي بزاوية أو دائري)
Gradient layerGradient(Layer l) {
  if (l.radial) return RadialGradient(colors: [l.g1, l.g2]);
  final a = l.gAngle * 3.141592653589793 / 180;
  return LinearGradient(begin: Alignment(-_cos(a), -_sin(a)), end: Alignment(_cos(a), _sin(a)), colors: [l.g1, l.g2]);
}

class Bg {
  Bg({this.kind = 0, this.c1 = Colors.white, this.c2 = Colors.black, this.angle = 90, this.path});
  int kind; // 0 لون، 1 تدرج، 2 صورة
  Color c1, c2;
  double angle;
  String? path;
  Map<String, dynamic> toJson() => {'k': kind, 'a': c1.value, 'b': c2.value, 'g': angle, 'p': path};
  factory Bg.fromJson(Map<String, dynamic> m) =>
      Bg(kind: m['k'], c1: Color(m['a'] as int), c2: Color(m['b'] as int), angle: _d(m['g'], 90), path: m['p']);
}

class Doc {
  Doc(this.w, this.h, this.bg, this.layers);
  double w, h;
  Bg bg;
  List<Layer> layers;
  // تأثيرات على التصميم كله
  double radius = 0, frameW = 0, opacity = 1, bright = 0, contrast = 1, sat = 1, blur = 0;
  bool flip = false;
  Color frameColor = Colors.black;

  Map<String, dynamic> toJson() => {
        'w': w, 'h': h, 'bg': bg.toJson(), 'ls': layers.map((l) => l.toJson()).toList(),
        'fx': {'r': radius, 'fw': frameW, 'o': opacity, 'br': bright, 'ct': contrast, 'sa': sat, 'bl': blur, 'fl': flip, 'fc': frameColor.value},
      };

  factory Doc.fromJson(Map<String, dynamic> m) {
    final d = Doc(_d(m['w']), _d(m['h']), Bg.fromJson(Map<String, dynamic>.from(m['bg'])),
        (m['ls'] as List).map((e) => Layer.fromJson(Map<String, dynamic>.from(e))).toList());
    final f = m['fx'];
    if (f != null) {
      final x = Map<String, dynamic>.from(f);
      d.radius = _d(x['r']); d.frameW = _d(x['fw']); d.opacity = _d(x['o'], 1); d.bright = _d(x['br']);
      d.contrast = _d(x['ct'], 1); d.sat = _d(x['sa'], 1); d.blur = _d(x['bl']); d.flip = x['fl'] ?? false;
      if (x['fc'] != null) d.frameColor = Color(x['fc'] as int);
    }
    return d;
  }
}
