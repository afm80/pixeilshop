import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
    final extra = l.shOn ? l.shBlur * 3 + math.max(l.shDx.abs(), l.shDy.abs()) + 24 : 6.0;
    c.saveLayer(bounds.inflate(extra + (l.type == LayerType.text && l.boxOn ? l.fontSize : 0)), p);
  }

  switch (l.type) {
    case LayerType.text:
      _drawText(c, l, bounds);
      break;
    case LayerType.image:
      _drawImageLayer(c, l, images, bounds);
      break;
    case LayerType.shape:
      _withShadow(c, l, bounds, () => _drawShape(c, l, bounds));
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

void _drawText(Canvas c, Layer l, Rect bounds) {
  void body() {
    if (l.boxOn) {
      final pad = l.fontSize * 0.3;
      c.drawRRect(
        RRect.fromRectAndRadius(bounds.inflate(pad), Radius.circular(l.boxRadius)),
        Paint()..color = Color(l.boxColor),
      );
    }
    final topLeft = Offset(-bounds.width / 2, -bounds.height / 2);
    if (l.strokeW > 0) {
      TextMetrics.build(l, stroke: true).paint(c, topLeft);
    }
    if (l.gradOn) {
      c.saveLayer(bounds.inflate(4), Paint());
      TextMetrics.build(l, stroke: false, whiteFill: true).paint(c, topLeft);
      c.drawRect(
        bounds.inflate(4),
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = ui.Gradient.linear(bounds.topCenter, bounds.bottomCenter, [Color(l.grad1), Color(l.grad2)]),
      );
      c.restore();
    } else {
      TextMetrics.build(l, stroke: false).paint(c, topLeft);
    }
  }

  _withShadow(c, l, bounds, body);
}

void _drawImageLayer(Canvas c, Layer l, ImageStore images, Rect bounds) {
  final img = images.get(l.path);
  if (img == null) {
    c.drawRect(bounds, Paint()..color = const Color(0x33FFFFFF));
    return;
  }
  void body() {
    c.saveLayer(bounds, Paint());
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
  }

  _withShadow(c, l, bounds, body);
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

void _drawShape(Canvas c, Layer l, Rect bounds) {
  final path = shapePath(l, bounds);
  final fill = Paint()..isAntiAlias = true;
  if (l.gradOn) {
    fill.shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [Color(l.grad1), Color(l.grad2)]);
  } else {
    fill.color = Color(l.color);
  }
  c.drawPath(path, fill);
  if (l.strokeW > 0) {
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.strokeW
        ..strokeJoin = StrokeJoin.round
        ..color = Color(l.strokeColor),
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
