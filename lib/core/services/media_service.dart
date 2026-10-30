import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaRef {
  const MediaRef(this.path, this.w, this.h);
  final String path;
  final int w, h;
}

class Pixels {
  const Pixels(this.rgba, this.w, this.h);
  final Uint8List rgba; // RGBA غير مضروب مسبقاً
  final int w, h;
}

/// استيراد الصور من المعرض/الكاميرا وحفظ النتائج داخل مجلد التطبيق.
class MediaService {
  static final ImagePicker _picker = ImagePicker();
  static int _n = 0;

  static Future<Directory> mediaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'media'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<String> _newPath(String ext, [String prefix = 'img']) async {
    final d = await mediaDir();
    return p.join(d.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_n++}.$ext');
  }

  static Future<MediaRef?> pick({ImageSource source = ImageSource.gallery}) async {
    final x = await _picker.pickImage(source: source);
    if (x == null) return null;
    return importFile(x.path);
  }

  static Future<List<MediaRef>> pickMany() async {
    final xs = await _picker.pickMultiImage();
    final out = <MediaRef>[];
    for (final x in xs) {
      out.add(await importFile(x.path));
    }
    return out;
  }

  /// ينسخ الملف إلى مجلد التطبيق (ليبقى بعد حذف الملف الأصلي) ويقرأ أبعاده.
  static Future<MediaRef> importFile(String src) async {
    final ext = p.extension(src).replaceFirst('.', '').toLowerCase();
    final dst = await _newPath(ext.isEmpty ? 'jpg' : ext);
    await File(src).copy(dst);
    final bytes = await File(dst).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final img = (await codec.getNextFrame()).image;
    return MediaRef(dst, img.width, img.height);
  }

  static Future<Pixels> decodePixels(String path, {int? maxSide}) async {
    final bytes = await File(path).readAsBytes();
    var codec = await ui.instantiateImageCodec(bytes);
    var img = (await codec.getNextFrame()).image;
    if (maxSide != null && math.max(img.width, img.height) > maxSide) {
      final k = maxSide / math.max(img.width, img.height);
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: math.max(1, (img.width * k).round()),
        targetHeight: math.max(1, (img.height * k).round()),
      );
      img = (await codec.getNextFrame()).image;
    }
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Pixels(bd!.buffer.asUint8List(), img.width, img.height);
  }

  /// يفك الصورة بحجم محدد بالضبط (تمطيط) — يُستخدم لمدخلات نماذج TFLite.
  static Future<Pixels> decodePixelsExact(String path, int w, int h) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: w, targetHeight: h);
    final img = (await codec.getNextFrame()).image;
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Pixels(bd!.buffer.asUint8List(), img.width, img.height);
  }

  static Future<ui.Image> imageFromPixels(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  static Future<Uint8List> encodePng(ui.Image img) async {
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  /// يحفظ بكسلات RGBA كملف PNG داخل مجلد الوسائط.
  static Future<MediaRef> savePixels(Uint8List rgba, int w, int h, {String prefix = 'out'}) async {
    final img = await imageFromPixels(rgba, w, h);
    final png = await encodePng(img);
    final path = await _newPath('png', prefix);
    await File(path).writeAsBytes(png, flush: true);
    return MediaRef(path, w, h);
  }

  static Future<MediaRef> saveImage(ui.Image img, {String prefix = 'out'}) async {
    final png = await encodePng(img);
    final path = await _newPath('png', prefix);
    await File(path).writeAsBytes(png, flush: true);
    return MediaRef(path, img.width, img.height);
  }

  /// ملف PNG مؤقت لإدخاله إلى ML Kit.
  static Future<String> tempPng(Pixels px) async {
    final ref = await savePixels(px.rgba, px.w, px.h, prefix: 'tmp');
    return ref.path;
  }
}
