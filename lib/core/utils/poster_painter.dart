import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextSelection;

import '../../features/poster_builder/model/doc.dart';
import '../../features/poster_builder/model/layer.dart';
import '../services/image_store.dart';
import 'blend_modes.dart';
import 'color_matrices.dart';
import 'text_metrics.dart';

/// يرسم التصميم كاملاً بإحداثيات التصميم (0..doc.w, 0..doc.h).
/// يُستخدم للعرض الحي وللتصدير بنفس الكود (ما تراه هو ما يُصدَّر).
void paintDoc(Canvas c, Doc doc, ImageStore images, {bool checker = false}) {
  final rect = Rect.fromLTWH(0, 0, doc.w, doc.h);
  c.save();
  c.clipRect(rect);
  if (checker && doc.bgKind == 3) _checker(c, rect);

  final useGlobal = doc.adjust.hasMatrix;
  if (useGlobal) {
    c.saveLayer(rect, Paint()..colorFilter = ColorFilter.matrix(ColorMatrices.forAdjust(doc.adjust)));
  }
  _paintBackground(c, doc, images, rect);
  for (final l in doc.layers) {
    if (!l.hidden) _paintLayer(c, l, images);
  }
  if (useGlobal) c.restore();

  if (doc.adjust.vignette > 0) {
    final v = doc.adjust.vignette.clamp(0.0, 1.0).toDouble();
    final center = rect.center;
    final radius = math.sqrt(doc.w * doc.w + doc.h * doc.h) / 2;
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [const Color(0x00000000), Color.fromRGBO(0, 0, 0, v * 0.8)],
          [0.5, 1.0],
        ),
    );
  }
  c.restore();
}

void _checker(Canvas c, Rect r) {
  final size = math.max(r.width, r.height) / 40;
  final p1 = Paint()..color = const Color(0xFFFFFFFF);
  final p2 = Paint()..color = const Color(0xFFD6D6D6);
  c.drawRect(r, p1);
  for (double y = 0; y < r.height; y += size) {
    for (double x = 0; x < r.width; x += size) {
      if (((x / size).floor() + (y / size).floor()) % 2 == 1) {
        c.drawRect(Rect.fromLTWH(x, y, size, size), p2);
      }
    }
  }
}

Rect coverSrc(double iw, double ih, double bw, double bh) {
  final ia = iw / ih, ba = bw / bh;
  if ((ia - ba).abs() < 0.001) return Rect.fromLTWH(0, 0, iw, ih);
  if (ia > ba) {
    final sw = ih * ba;
    return Rect.fromLTWH((iw - sw) / 2, 0, sw, ih);
  }
  final sh = iw / ba;
  return Rect.fromLTWH(0, (ih - sh) / 2, iw, sh);
}

void _paintBackground(Canvas c, Doc d, ImageStore images, Rect rect) {
  switch (d.bgKind) {
    case 0:
      c.drawRect(rect, Paint()..color = Color(d.bgColor1));
      break;
    case 1:
      final a = d.bgAngle * math.pi / 180;
      final half = Offset(math.cos(a) * d.w / 2, math.sin(a) * d.h / 2);
      c.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.center - half,
            rect.center + half,
            [Color(d.bgColor1), Color(d.bgColor2)],
          ),
      );
      break;
    case 4:
      c.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            math.max(d.w, d.h) / 2,
            [Color(d.bgColor1), Color(d.bgColor2)],
          ),
      );
      break;
    case 2:
      final img = images.get(d.bgPath);
      if (img != null) {
        c.drawImageRect(
          img,
          coverSrc(img.width.toDouble(), img.height.toDouble(), d.w, d.h),
          rect,
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        c.drawRect(rect, Paint()..color = const Color(0xFF222222));
      }
      break;
    default:
      break; // شفافة
  }
}

void _paintLayer(Canvas c, Layer l, ImageStore images) {
  final size = TextMetrics.size(l);
  final bounds = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
  c.save();
  c.translate(l.x, l.y);
  c.rotate(l.rotation);
  c.scale(l.flipX ? -l.scale : l.scale, l.scale);

  final hasAdj = l.adj.hasMatrix;
  final needsLayer = l.opacity < 0.999 || l.blend != 0 || hasAdj;
  if (needsLayer) {
    final p = Paint()
      ..blendMode = kBlends[l.blend.clamp(0, kBlends.length - 1).toInt()].mode
      ..color = Color.fromRGBO(255, 255, 255, l.opacity.clamp(0.0, 1.0).toDouble());
    if (hasAdj) p.colorFilter = ColorFilter.matrix(ColorMatrices.forAdjust(l.adj));
    var extra = l.shOn ? l.shBlur * 3 + math.max(l.shDx.abs(), l.shDy.abs()) + 24 : 6.0;
    if (l.type == LayerType.text) {
      if (l.boxOn) extra += l.fontSize;
      if (l.reflOn) extra += bounds.height + l.reflGap + l.fontSize;
    }
    c.saveLayer(bounds.inflate(extra), p);
  }

  switch (l.type) {
    case LayerType.text:
      _drawText(c, l, images, bounds);
      break;
    case LayerType.image:
      _drawImageLayer(c, l, images, bounds);
      break;
    case LayerType.shape:
      _withShadow(c, l, bounds, () => _drawShape(c, l, images, bounds));
      break;
    case LayerType.draw:
      _withShadow(c, l, bounds, () => _drawBrush(c, l, bounds));
      break;
  }

  if (needsLayer) c.restore();
  c.restore();
}

/// ظل يتبع شكل المحتوى (قناع الشفافية) بدل مستطيل: نرسم المحتوى في طبقة مؤقتة
/// ملوّنة بلون الظل ومموّهة.
void _withShadow(Canvas c, Layer l, Rect bounds, void Function() draw) {
  if (l.shOn) {
    final sigma = math.max(l.shBlur, 0.01);
    final sh = Paint()
      ..colorFilter = ColorFilter.mode(
        Color(l.shColor).withValues(alpha: l.shOpacity.clamp(0.0, 1.0).toDouble()),
        BlendMode.srcIn,
      )
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
    c.save();
    if (l.shGround) {
      // ظل أرضي: مسطّح ومائل عند الحافة السفلية
      // مصفوفة (عمودية): x' = x - 0.55*y ، y' = 0.28*y
      final m = Float64List.fromList([1, 0, 0, 0, -0.55, 0.28, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
      c.translate(l.shDx, bounds.height / 2 + l.shDy * 0.3);
      c.transform(m);
      c.translate(0, -bounds.height / 2);
    } else {
      c.translate(l.shDx, l.shDy);
    }
    c.saveLayer(bounds.inflate(l.shBlur * 3 + 12), sh);
    draw();
    c.restore();
    c.restore();
  }
  draw();
}

// ───────────────────────── التعبئات (لون / تدرج / نقشة / صورة) ─────────────────────────

final Map<String, ui.Image> _tiles = {};

/// بلاطة نقشة صغيرة تُرسم مرة واحدة وتُكرَّر (rasterize متزامن).
ui.Image _patternTile(int kind, double size, int c1, int c2) {
  final px = math.max(8, size.round());
  final key = '$kind|$px|$c1|$c2';
  final cached = _tiles[key];
  if (cached != null) return cached;
  final t = px.toDouble();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final fg = Paint()
    ..color = Color(c1)
    ..isAntiAlias = true;
  c.drawRect(Rect.fromLTWH(0, 0, t, t), Paint()..color = Color(c2));
  switch (kind) {
    case 0: // خطوط أفقية
      c.drawRect(Rect.fromLTWH(0, 0, t, t / 2), fg);
      break;
    case 1: // نقاط
      c.drawCircle(Offset(t / 2, t / 2), t * 0.28, fg);
      break;
    case 2: // شبكة
      c.drawRect(Rect.fromLTWH(0, 0, t, t * 0.12), fg);
      c.drawRect(Rect.fromLTWH(0, 0, t * 0.12, t), fg);
      break;
    case 3: // رقعة شطرنج
      c.drawRect(Rect.fromLTWH(0, 0, t / 2, t / 2), fg);
      c.drawRect(Rect.fromLTWH(t / 2, t / 2, t / 2, t / 2), fg);
      break;
    default: // خطوط مائلة
      final lp = Paint()
        ..color = Color(c1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = t * 0.22
        ..isAntiAlias = true;
      c.drawLine(Offset(-t * 0.1, t * 1.1), Offset(t * 1.1, -t * 0.1), lp);
      c.drawLine(Offset(-t * 0.6, t * 0.6), Offset(t * 0.6, -t * 0.6), lp);
      c.drawLine(Offset(t * 0.4, t * 1.6), Offset(t * 1.6, t * 0.4), lp);
      break;
  }
  final img = rec.endRecording().toImageSync(px, px);
  if (_tiles.length > 40) _tiles.clear();
  _tiles[key] = img;
  return img;
}

Float64List _mat(double sx, double sy, double tx, double ty) =>
    Float64List.fromList([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]);

/// شيدر تعبئة الطبقة داخل [b] (null = لون صلب أو صورة التعبئة لم تُحمَّل بعد).
ui.Shader? fillShader(Layer l, Rect b, ImageStore images) {
  switch (l.fillKind) {
    case 1:
      final a = l.gradAngle * math.pi / 180;
      final half = Offset(math.cos(a) * b.width / 2, math.sin(a) * b.height / 2);
      return ui.Gradient.linear(b.center - half, b.center + half, [Color(l.grad1), Color(l.grad2)]);
    case 2:
      return ui.Gradient.radial(b.center, math.max(b.width, b.height) / 2, [Color(l.grad1), Color(l.grad2)]);
    case 3:
      final tile = _patternTile(l.fillPattern, l.patSize, l.grad1, l.grad2);
      final k = math.max(8.0, l.patSize) / tile.width;
      return ui.ImageShader(tile, TileMode.repeated, TileMode.repeated, _mat(k, k, b.left, b.top));
    case 4:
      final img = images.get(l.fillPath);
      if (img == null) return null;
      final k = math.max(b.width / img.width, b.height / img.height);
      return ui.ImageShader(
        img,
        TileMode.clamp,
        TileMode.clamp,
        _mat(k, k, b.left + (b.width - img.width * k) / 2, b.top + (b.height - img.height * k) / 2),
        filterQuality: FilterQuality.high,
      );
    default:
      return null;
  }
}

/// يرسم مساراً بخط عادي أو متقطع.
void _strokePath(Canvas c, Path path, Paint paint, bool dashed, double dash) {
  if (!dashed) {
    c.drawPath(path, paint);
    return;
  }
  final d = math.max(2.0, dash);
  final gap = d * 0.6;
  for (final m in path.computeMetrics()) {
    double at = 0;
    while (at < m.length) {
      c.drawPath(m.extractPath(at, math.min(at + d, m.length)), paint);
      at += d + gap;
    }
  }
}

// ───────────────────────── النص ─────────────────────────

void _drawText(Canvas c, Layer l, ImageStore images, Rect bounds) {
  void body() {
    if (l.boxOn) {
      final pad = l.fontSize * 0.3;
      c.drawRRect(
        RRect.fromRectAndRadius(bounds.inflate(pad), Radius.circular(l.boxRadius)),
        Paint()..color = Color(l.boxColor),
      );
    }
    final topLeft = Offset(-bounds.width / 2, -bounds.height / 2);
    if (l.hlOn) _highlightText(c, l, topLeft);
    if (l.strokeW > 0) {
      TextMetrics.build(l, stroke: true).paint(c, topLeft);
    }
    final shader = l.fillKind == 0 ? null : fillShader(l, bounds, images);
    if (shader != null) {
      c.saveLayer(bounds.inflate(4), Paint());
      TextMetrics.build(l, stroke: false, whiteFill: true).paint(c, topLeft);
      c.drawRect(
        bounds.inflate(4),
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = shader,
      );
      c.restore();
    } else {
      TextMetrics.build(l, stroke: false).paint(c, topLeft);
    }
  }

  void withReflection() {
    body();
    if (!l.reflOn) return;
    final b = bounds.bottom;
    final area = bounds.inflate(l.fontSize * 0.5);
    c.save();
    c.translate(0, l.reflGap);
    c.translate(0, b);
    c.scale(1, -1);
    c.translate(0, -b);
    c.saveLayer(area, Paint());
    body();
    c.drawRect(
      area,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, bounds.bottom),
          Offset(0, bounds.top),
          [Color.fromRGBO(255, 255, 255, l.reflOpacity.clamp(0.0, 1.0).toDouble()), const Color(0x00FFFFFF)],
        ),
    );
    c.restore();
    c.restore();
  }

  _withShadow(c, l, bounds, withReflection);
}

/// تظليل النص (highlight): مستطيل مستدير خلف كل سطر.
void _highlightText(Canvas c, Layer l, Offset topLeft) {
  final tp = TextMetrics.build(l, stroke: false);
  final len = tp.text?.toPlainText().length ?? 0;
  if (len == 0) return;
  final boxes = tp.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: len));
  final paint = Paint()
    ..color = Color(l.hlColor)
    ..isAntiAlias = true;
  final grow = l.fontSize * 0.06;
  for (final b in boxes) {
    c.drawRRect(
      RRect.fromRectAndRadius(b.toRect().shift(topLeft).inflate(grow), Radius.circular(l.fontSize * 0.12)),
      paint,
    );
  }
}

// ───────────────────────── الصور ─────────────────────────

void _drawImageLayer(Canvas c, Layer l, ImageStore images, Rect bounds) {
  final img = images.get(l.path);
  if (img == null) {
    c.drawRect(bounds, Paint()..color = const Color(0x33FFFFFF));
    return;
  }
  final radius = l.cornerRadius.clamp(0.0, math.min(bounds.width, bounds.height) / 2).toDouble();
  final rr = RRect.fromRectAndRadius(bounds, Radius.circular(radius));

  void body() {
    c.saveLayer(bounds, Paint());
    if (radius > 0) c.clipRRect(rr, doAntiAlias: true);
    c.drawImageRect(
      img,
      coverSrc(img.width.toDouble(), img.height.toDouble(), l.w, l.h),
      bounds,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
    for (final s in l.erase) {
      final p = Paint()
        ..blendMode = BlendMode.clear
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.r * 2 * l.w
        ..style = PaintingStyle.stroke;
      if (s.pts.length < 4) {
        if (s.pts.length >= 2) {
          c.drawCircle(
            Offset(s.pts[0] * l.w, s.pts[1] * l.w),
            s.r * l.w,
            Paint()
              ..blendMode = BlendMode.clear
              ..isAntiAlias = true,
          );
        }
        continue;
      }
      final path = Path()..moveTo(s.pts[0] * l.w, s.pts[1] * l.w);
      for (int i = 2; i + 1 < s.pts.length; i += 2) {
        path.lineTo(s.pts[i] * l.w, s.pts[i + 1] * l.w);
      }
      c.drawPath(path, p);
    }
    c.restore();
    // إطار الصورة (متصل أو متقطع) داخل حافتها
    if (l.strokeW > 0) {
      final inset = rr.deflate(l.strokeW / 2);
      _strokePath(
        c,
        Path()..addRRect(inset),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = l.strokeW
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..color = Color(l.strokeColor),
        l.dashed,
        l.dashLen,
      );
    }
  }

  _withShadow(c, l, bounds, body);
}

// ───────────────────────── الرسم الحر (فرشاة) ─────────────────────────

Path _smoothPath(List<double> pts) {
  final n = pts.length ~/ 2;
  final path = Path()..moveTo(pts[0], pts[1]);
  for (int i = 1; i < n - 1; i++) {
    final mx = (pts[2 * i] + pts[2 * i + 2]) / 2, my = (pts[2 * i + 1] + pts[2 * i + 3]) / 2;
    path.quadraticBezierTo(pts[2 * i], pts[2 * i + 1], mx, my);
  }
  path.lineTo(pts[2 * (n - 1)], pts[2 * (n - 1) + 1]);
  return path;
}

void _drawBrush(Canvas c, Layer l, Rect bounds) {
  c.saveLayer(bounds, Paint());
  for (final s in l.strokes) {
    if (s.pts.length < 2) continue;
    if (s.pts.length < 4) {
      final dot = Paint()
        ..isAntiAlias = true
        ..color = Color(s.color);
      if (s.erase) dot.blendMode = BlendMode.clear;
      c.drawCircle(Offset(s.pts[0], s.pts[1]), s.width / 2, dot);
      continue;
    }
    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s.width
      ..color = Color(s.color);
    if (s.erase) p.blendMode = BlendMode.clear;
    _strokePath(c, _smoothPath(s.pts), p, s.dashed, s.width * 2.5);
  }
  c.restore();
}

Path shapePath(Layer l, Rect b) {
  final p = Path();
  switch (l.shape) {
    case ShapeKind.rect:
      p.addRRect(RRect.fromRectAndRadius(b, Radius.circular(l.cornerRadius)));
      break;
    case ShapeKind.circle:
      p.addOval(b);
      break;
    case ShapeKind.triangle:
      p.moveTo(b.center.dx, b.top);
      p.lineTo(b.right, b.bottom);
      p.lineTo(b.left, b.bottom);
      p.close();
      break;
    case ShapeKind.diamond:
      p.moveTo(b.center.dx, b.top);
      p.lineTo(b.right, b.center.dy);
      p.lineTo(b.center.dx, b.bottom);
      p.lineTo(b.left, b.center.dy);
      p.close();
      break;
    case ShapeKind.star:
      final cx = b.center.dx, cy = b.center.dy;
      final ro = b.width / 2, rv = b.height / 2;
      for (int i = 0; i < 10; i++) {
        final k = i.isEven ? 1.0 : 0.42;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = Offset(cx + math.cos(a) * ro * k, cy + math.sin(a) * rv * k);
        if (i == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      p.close();
      break;
    case ShapeKind.line:
      final t = math.max(4.0, b.height * 0.06);
      p.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: b.center, width: b.width, height: t),
        Radius.circular(t / 2),
      ));
      break;
  }
  return p;
}

void _drawShape(Canvas c, Layer l, ImageStore images, Rect bounds) {
  final path = shapePath(l, bounds);
  final fill = Paint()..isAntiAlias = true;
  final shader = l.fillKind == 0 ? null : fillShader(l, bounds, images);
  if (shader != null) {
    fill.shader = shader;
  } else {
    fill.color = Color(l.color);
  }
  c.drawPath(path, fill);
  if (l.strokeW > 0) {
    _strokePath(
      c,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.strokeW
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = Color(l.strokeColor),
      l.dashed,
      l.dashLen,
    );
  }
}

/// يرسم التصميم على الشاشة بمقياس معين.
class PosterPainter extends CustomPainter {
  PosterPainter({required this.doc, required this.images, required this.revision}) : super(repaint: images);
  final Doc doc;
  final ImageStore images;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / doc.w, size.height / doc.h);
    paintDoc(canvas, doc, images, checker: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PosterPainter old) => true;
}
