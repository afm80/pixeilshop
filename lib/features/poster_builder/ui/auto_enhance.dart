import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/export_service.dart';
import 'tool_screens.dart';

/// يحلل صورة مصغّرة ويقترح لمعاناً وتبايناً وتشبعاً مناسبة (بدون أي خدمة خارجية).
Future<({double b, double c, double s})?> analyzeAuto(ui.Image img) async {
  final k = 64 / math.max(img.width, img.height);
  final tw = math.max(1, (img.width * k).round()), th = math.max(1, (img.height * k).round());
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final small = await rec.endRecording().toImage(tw, th);
  final bd = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) return null;
  final px = bd.buffer.asUint8List();
  var n = 0;
  var sum = 0.0, sum2 = 0.0, sat = 0.0;
  for (var i = 0; i + 3 < px.length; i += 4) {
    if (px[i + 3] < 16) continue;
    final r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255;
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    sum += y;
    sum2 += y * y;
    sat += mx <= 0 ? 0 : (mx - mn) / mx;
    n++;
  }
  if (n < 20) return null;
  final mean = sum / n;
  final std = math.sqrt(math.max(0.0, sum2 / n - mean * mean));
  final meanSat = sat / n;
  double cl(double v, double a, double b) => v < a ? a : (v > b ? b : v);
  return (
    b: cl((0.48 - mean) * 0.9, -0.25, 0.3),
    c: cl((0.25 - std) * 1.4, -0.1, 0.35),
    s: cl(0.1 + (0.3 - meanSat) * 0.5, 0.0, 0.3),
  );
}

/// تحسين تلقائي للطبقة الصورة المحددة ([layer] = true) أو للتصميم كله.
Future<void> autoEnhance(ToolCtx c, {required bool layer}) async {
  final ctx = c.context;
  void toast(String m) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));
    }
  }

  try {
    ui.Image? img;
    final l = c.layer;
    if (layer && l != null && l.path != null) img = c.images.get(l.path);
    if (img == null) {
      // نحلل التصميم كما يظهر بدون تعديلاته اللونية الحالية كي لا يتراكم التحسين
      final d = c.doc.clone()..adjust.reset();
      img = await ExportService.render(d, c.images, scale: 128 / math.max(d.w, d.h));
    }
    final r = await analyzeAuto(img);
    if (r == null) {
      toast('تعذر تحليل الصورة');
      return;
    }
    void apply(dynamic a) {
      a.brightness = r.b;
      a.contrast = r.c;
      a.saturation = r.s;
    }

    if (layer && l != null) {
      c.mut((x) => apply(x.adj));
    } else {
      c.mutDoc((d) => apply(d.adjust));
    }
    toast('تم التحسين التلقائي');
  } catch (_) {
    toast('تعذر التحسين التلقائي');
  }
}
