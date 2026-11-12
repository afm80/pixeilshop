import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color, FontWeight, Shadow, TextAlign, TextDirection, TextPainter, TextSpan, TextStyle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/poster_builder/model/doc.dart';
import '../utils/poster_painter.dart';
import 'image_store.dart';
import 'media_service.dart';
import 'storage_service.dart';

enum ExportFormat { png, jpg, webp }

extension ExportFormatInfo on ExportFormat {
  String get ext => name;
  String get label => name.toUpperCase();
}

class ExportService {
  static const int maxSide = 4096;

  /// يرسم التصميم إلى ui.Image بدقة [scale] (مع سقف 4096px للضلع الأطول).
  static Future<ui.Image> render(Doc doc, ImageStore images, {double scale = 1, bool watermark = false}) async {
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {}
    await images.ensureDoc(doc);
    final useWm = watermark && StorageService.wmOn && (StorageService.wmText.trim().isNotEmpty || StorageService.wmLogo != null);
    final logoPath = useWm ? StorageService.wmLogo : null;
    if (logoPath != null) await images.ensure(logoPath);
    final k = math.min(scale, maxSide / math.max(doc.w, doc.h));
    final w = math.max(1, (doc.w * k).round());
    final h = math.max(1, (doc.h * k).round());
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(w / doc.w, h / doc.h);
    paintDoc(c, doc, images);
    if (useWm) _paintWatermark(c, doc, images.get(logoPath), StorageService.wmText.trim());
    return rec.endRecording().toImage(w, h);
  }

  /// نص و/أو شعار صغير في الزاوية السفلية اليمنى.
  static void _paintWatermark(ui.Canvas c, Doc doc, ui.Image? logo, String text) {
    final m = math.min(doc.w, doc.h);
    final margin = m * 0.03;
    final fs = math.max(14.0, m * 0.035);
    final alpha = 0.78;
    var x = doc.w - margin;
    final base = doc.h - margin;
    if (text.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w600,
            color: Color.fromRGBO(255, 255, 255, alpha),
            shadows: [Shadow(color: Color.fromRGBO(0, 0, 0, 0.7), blurRadius: fs * 0.25, offset: ui.Offset(0, fs * 0.05))],
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
      )..layout();
      x -= tp.width;
      tp.paint(c, ui.Offset(x, base - tp.height));
      x -= fs * 0.5;
    }
    if (logo != null) {
      final lh = fs * 2.0;
      final lw = lh * logo.width / logo.height;
      x -= lw;
      c.drawImageRect(
        logo,
        ui.Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        ui.Rect.fromLTWH(x, base - lh, lw, lh),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.high
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
    }
  }

  static Future<Uint8List> encode(ui.Image img, ExportFormat f, {int quality = 95}) async {
    final png = await MediaService.encodePng(img);
    if (f == ExportFormat.png) return png;
    final r = await FlutterImageCompress.compressWithList(
      png,
      minWidth: img.width,
      minHeight: img.height,
      quality: quality,
      format: f == ExportFormat.jpg ? CompressFormat.jpeg : CompressFormat.webp,
    );
    return Uint8List.fromList(r);
  }

  static Future<String> _writeTemp(Uint8List bytes, String ext) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'pixeilshop_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// يحفظ في معرض الهاتف. يعيد المسار المؤقت المستخدم.
  static Future<String> saveToGallery(Uint8List bytes, ExportFormat f) async {
    final path = await _writeTemp(bytes, f.ext);
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putImage(path, album: 'PixeilShop');
    return path;
  }

  static Future<void> share(Uint8List bytes, ExportFormat f) async {
    final path = await _writeTemp(bytes, f.ext);
    await Share.shareXFiles([XFile(path)]);
  }

  /// صورة مصغّرة للمشروع (PNG) تُحفظ بجوار المشروع.
  static Future<String?> thumbnail(Doc doc, ImageStore images, String id) async {
    try {
      final img = await render(doc, images, scale: 360 / math.max(doc.w, doc.h));
      final png = await MediaService.encodePng(img);
      final dir = await getApplicationDocumentsDirectory();
      final t = Directory(p.join(dir.path, 'thumbs'));
      if (!await t.exists()) await t.create(recursive: true);
      final path = p.join(t.path, '$id.png');
      await File(path).writeAsBytes(png, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }
}
