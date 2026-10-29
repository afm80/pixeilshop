import 'dart:math';
import 'package:flutter/material.dart';
import 'model.dart';

typedef StyleFn = TextStyle Function({Paint? fg, Color? col, List<Shadow>? sh});

/// نص مقوّس: نرسم النص كاملاً (ليبقى تشكيل الحروف العربية سليماً) ثم نقص
/// شريحة كل حرف وندوّرها ونضعها على القوس.
class CurvePainter extends CustomPainter {
  CurvePainter(this.l, this.st);
  final Layer l;
  final StyleFn st;

  static bool _rtl(String s) => RegExp(r'[\u0590-\u08FF\uFB1D-\uFEFF]').hasMatch(s);
  static String _s(Layer l) => l.text.replaceAll('\n', ' ');

  static TextPainter _tp(Layer l, TextStyle s) => TextPainter(
        text: TextSpan(text: _s(l), style: s),
        textDirection: _rtl(l.text) ? TextDirection.rtl : TextDirection.ltr,
      )..layout();

  static double _pad(Layer l) => 20 + l.depth + l.shadowBlur + l.strokeW + l.size * .15;

  static Size sizeOf(Layer l, StyleFn st) {
    final p = _tp(l, st(col: Colors.black));
    final w = p.width, h = p.height;
    final ath = max(l.curve.abs() * 1.6 * pi, .01);
    final r = w / ath, half = min(ath / 2, pi);
    final sag = r * (1 - cos(half));
    final halfW = max(w / 2, r * sin(min(half, pi / 2))) + h * .6;
    final pad = _pad(l);
    return Size(2 * halfW + 2 * pad, h + sag + 2 * pad);
  }

  @override
  void paint(Canvas c, Size size) {
    final base = _tp(l, st(col: Colors.black));
    final w = base.width, h = base.height;
    final ath = max((l.curve * 1.6 * pi).abs(), .01);
    final r = w / ath;
    final up = l.curve > 0;
    final pad = _pad(l);
    final origin = Offset(size.width / 2, up ? pad + h / 2 : size.height - pad - h / 2);
    final n = _s(l).length;

    void pass(TextPainter Function(double cx) mk, Offset shift) {
      for (var i = 0; i < n; i++) {
        final bs = base.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1));
        if (bs.isEmpty) continue;
        final b = bs.first;
        final cx = (b.left + b.right) / 2;
        final phi = (cx - w / 2) / r;
        final pos = Offset(r * sin(phi), (up ? 1 : -1) * r * (1 - cos(phi)));
        c.save();
        c.translate(origin.dx + pos.dx + shift.dx, origin.dy + pos.dy + shift.dy);
        c.rotate(up ? phi : -phi);
        c.clipRect(Rect.fromLTRB(b.left - cx - .5, -4000, b.right - cx + .5, 4000));
        mk(cx).paint(c, Offset(-cx, -h / 2));
        c.restore();
      }
    }

    TextPainter one(TextStyle s) => _tp(l, s);
    if (l.depth > 0) {
      final p = one(st(col: l.shadow));
      for (double i = l.depth; i > 0; i -= 3) { pass((_) => p, Offset(i, i)); }
    }
    if (l.strokeW > 0) {
      final p = one(st(fg: Paint()..style = PaintingStyle.stroke..strokeWidth = l.strokeW..strokeJoin = StrokeJoin.round..color = l.stroke));
      pass((_) => p, Offset.zero);
    }
    final shadows = l.shadowBlur > 0 ? [Shadow(color: l.shadow, blurRadius: l.shadowBlur)] : null;
    if (l.grad) {
      if (shadows != null) {
        final p = one(st(col: Colors.transparent, sh: shadows));
        pass((_) => p, Offset.zero);
      }
      pass((cx) => one(st(fg: Paint()..shader = layerGradient(l).createShader(Rect.fromLTWH(-cx, -h / 2, w, h)))), Offset.zero);
    } else {
      final p = one(st(col: l.color, sh: shadows));
      pass((_) => p, Offset.zero);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
