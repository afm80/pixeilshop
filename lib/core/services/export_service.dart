import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

enum ExportFormat { png, jpg, webp }

extension ExportFormatInfo on ExportFormat {
  String get ext => name;
  String get label => name.toUpperCase();
}

class ExportService {
  static const int maxSide = 4096;

  /// يرسم التصميم إلى ui.Image بدقة [scale] (مع سقف 4096px للضلع الأطول).
  static Future<ui.Image> render(Doc doc, ImageStore images, {double scale = 1}) async {
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {}
    await images.ensureDoc(doc);
    final k = math.min(scale, maxSide / math.max(doc.w, doc.h));
    final w = math.max(1, (doc.w * k).round());
    final h = math.max(1, (doc.h * k).round());
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(w / doc.w, h / doc.h);
    paintDoc(c, doc, images);
    return rec.endRecording().toImage(w, h);
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
