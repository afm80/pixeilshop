import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'mlkit_service.dart';

/// تجميل حقيقي: تنعيم البشرة داخل منطقة الشخص فقط + تمويه الخلفية خارجها،
/// بالاعتماد على قناع الأشخاص من ML Kit. النتيجة صورة جديدة (PNG).
class BeautyService {
  BeautyService(this.path);
  final String path;

  final MlKitService _ml = MlKitService();
  ui.Image? _src;
  ui.Image? _mask;
  bool _maskTried = false;
  List<Rect> _faces = const [];

  /// هل وُجد وجه واحد على الأقل (بعد [prepare]).
  bool get hasFace => _faces.isNotEmpty;

  /// هل وُجد شخص في الصورة (بعد استدعاء [prepare]).
  bool get hasPerson => _mask != null;

  Future<void> prepare() async {
    if (_src != null && _maskTried) return;
    final bytes = await File(path).readAsBytes();
    var codec = await ui.instantiateImageCodec(bytes);
    var img = (await codec.getNextFrame()).image;
    final origW = img.width;
    final m = math.max(img.width, img.height);
    if (m > 2048) {
      final k = 2048 / m;
      codec = await ui.instantiateImageCodec(bytes, targetWidth: (img.width * k).round(), targetHeight: (img.height * k).round());
      img = (await codec.getNextFrame()).image;
    }
    _src = img;
    _maskTried = true;
    final k = img.width / origW;
    _faces = [for (final r in await _ml.faceBoxes(path)) Rect.fromLTRB(r.left * k, r.top * k, r.right * k, r.bottom * k)];
    final seg = await _ml.segmentSelfie(path, img.width, img.height);
    if (seg == null) return;
    // نحتفظ بالقناع فقط إذا كان فيه شخص فعلاً (نسبة معقولة من البكسلات)
    var sum = 0.0;
    for (final v in seg.conf) {
      sum += v;
    }
    if (sum / seg.conf.length < 0.02) return;
    final px = Uint8List(seg.w * seg.h * 4);
    for (var i = 0; i < seg.conf.length; i++) {
      final a = (seg.conf[i].clamp(0.0, 1.0) * 255).round();
      px[i * 4] = 255;
      px[i * 4 + 1] = 255;
      px[i * 4 + 2] = 255;
      px[i * 4 + 3] = a;
    }
    final comp = await _decode(px, seg.w, seg.h);
    _mask = comp;
  }

  Future<ui.Image> _decode(Uint8List px, int w, int h) async {
    final c = await ui.ImmutableBuffer.fromUint8List(px);
    final d = ui.ImageDescriptor.raw(c, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final codec = await d.instantiateCodec();
    return (await codec.getNextFrame()).image;
  }

  /// يبني الصورة المجمَّلة ويحفظها، ويرجع مسارها (null إن لم يوجد شخص).
  Future<String?> bake({required double smooth, required double bgBlur}) async {
    await prepare();
    final src = _src, mask = _mask;
    if (src == null || mask == null) return null;
    final w = src.width.toDouble(), h = src.height.toDouble();
    final rect = Rect.fromLTWH(0, 0, w, h);
    final big = math.max(w, h);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, rect);
    final maskSrc = Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble());
    // حواف القناع ناعمة قليلاً كي لا يظهر حدّ حاد بين الشخص والخلفية
    final maskPaint = Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: big / 700, sigmaY: big / 700, tileMode: TileMode.clamp);

    // 1) الصورة الأصلية
    c.drawImage(src, Offset.zero, Paint());

    // 2) خلفية مموّهة خارج الشخص
    if (bgBlur > 0.01) {
      final s = big / 90 * bgBlur + 1;
      c.saveLayer(rect, Paint());
      c.drawImage(src, Offset.zero, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: TileMode.clamp));
      c.drawImageRect(mask, maskSrc, rect, Paint()..blendMode = BlendMode.dstOut..imageFilter = maskPaint.imageFilter);
      c.restore();
    }

    // 3) تنعيم البشرة داخل الوجه فقط (ومن ضمن الشخص)
    if (smooth > 0.01 && _faces.isNotEmpty) {
      final s = big / 200 * smooth + 1;
      c.saveLayer(rect, Paint()..color = Color.fromRGBO(255, 255, 255, (0.6 * smooth).clamp(0.0, 0.9).toDouble()));
      c.drawImage(src, Offset.zero, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: TileMode.clamp));
      // مناطق الوجوه: بيضاوي أوسع قليلاً من مستطيل الوجه بحواف ناعمة
      c.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
      for (final f in _faces) {
        final oval = Rect.fromCenter(center: f.center.translate(0, f.height * 0.04), width: f.width * 1.22, height: f.height * 1.3);
        c.drawOval(oval, Paint()..color = const Color(0xFFFFFFFF)..maskFilter = MaskFilter.blur(BlurStyle.normal, f.width / 10));
      }
      c.restore();
      c.drawImageRect(mask, maskSrc, rect, Paint()..blendMode = BlendMode.dstIn..imageFilter = maskPaint.imageFilter);
      c.restore();
    }

    final out = await rec.endRecording().toImage(src.width, src.height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (data == null) return null;
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'beauty_${DateTime.now().microsecondsSinceEpoch}.png'));
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  }

  void dispose() {
    try {
      _src?.dispose();
      _mask?.dispose();
    } catch (e) {
      debugPrint('beauty dispose: $e');
    }
  }
}
