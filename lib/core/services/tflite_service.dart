import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../features/poster_builder/model/doc.dart';
import '../utils/pixel_ops.dart';
import 'media_service.dart';

enum StyleKind { anime, cartoon, comic, sketch }

extension StyleKindInfo on StyleKind {
  String get label => const {
        StyleKind.anime: 'أنمي',
        StyleKind.cartoon: 'كرتون',
        StyleKind.comic: 'كوميك',
        StyleKind.sketch: 'رسم رصاص',
      }[this]!;

  /// ملف النموذج (null = فلتر Dart محلي بدون نموذج)
  String? get asset => const {
        StyleKind.anime: 'assets/models/animeganv2.tflite',
        StyleKind.cartoon: 'assets/models/cartoongan.tflite',
      }[this];
}

class StyleResult {
  const StyleResult(this.image, this.usedModel);
  final ImageResult image;
  final bool usedModel;
}

/// تشغيل نماذج TFLite محلياً (AnimeGANv2 / CartoonGAN) مع بديل Dart إن غاب النموذج.
class TfliteService {
  Interpreter? _interp;
  String? _loadedAsset;

  Future<bool> hasModel(StyleKind k) async {
    final a = k.asset;
    if (a == null) return false;
    try {
      await rootBundle.load(a);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<StyleResult> stylize(String path, StyleKind kind, {double strength = 1.0}) async {
    if (await hasModel(kind)) {
      try {
        final r = await _runModel(path, kind, strength);
        return StyleResult(r, true);
      } catch (e) {
        debugPrint('TFLite failed, falling back to Dart filter: $e');
      }
    }
    final fallbackStyle = kind == StyleKind.sketch ? 1 : 0;
    final r = await _runFallback(path, fallbackStyle, strength);
    return StyleResult(r, false);
  }

  Future<ImageResult> _runFallback(String path, int style, double strength) async {
    final px = await MediaService.decodePixels(path, maxSide: 1280);
    final out = await compute(cartoonize, CartoonJob(px.rgba, px.w, px.h, style, strength));
    final ref = await MediaService.savePixels(out, px.w, px.h, prefix: 'style');
    return ImageResult(path: ref.path, width: px.w, height: px.h, note: 'dart');
  }

  Future<Interpreter> _load(String asset) async {
    if (_interp != null && _loadedAsset == asset) return _interp!;
    _interp?.close();
    final opts = InterpreterOptions()..threads = 4;
    _interp = await Interpreter.fromAsset(asset, options: opts);
    _loadedAsset = asset;
    return _interp!;
  }

  Future<ImageResult> _runModel(String path, StyleKind kind, double strength) async {
    final interp = await _load(kind.asset!);
    var shape = List<int>.from(interp.getInputTensor(0).shape);
    if (shape.length != 4) throw Exception('unsupported input rank ${shape.length}');
    if (shape[3] != 3) throw Exception('only NHWC float models are supported: $shape');
    int ih = shape[1], iw = shape[2];
    if (ih <= 0 || iw <= 0) {
      ih = 512;
      iw = 512;
      interp.resizeInputTensor(0, [1, ih, iw, 3]);
      interp.allocateTensors();
    }
    final outShape = List<int>.from(interp.getOutputTensor(0).shape);
    if (outShape.length != 4 || outShape[3] != 3) throw Exception('unexpected output shape $outShape');
    final oh = outShape[1], ow = outShape[2];

    final src = await MediaService.decodePixels(path, maxSide: 1536);
    final inPx = await MediaService.decodePixelsExact(path, iw, ih);

    // NHWC float32 في المجال [-1, 1]
    final input = List.generate(
      1,
      (_) => List.generate(
        ih,
        (y) => List.generate(iw, (x) {
          final i = (y * iw + x) * 4;
          return [inPx.rgba[i] / 127.5 - 1.0, inPx.rgba[i + 1] / 127.5 - 1.0, inPx.rgba[i + 2] / 127.5 - 1.0];
        }),
      ),
    );
    final output = List.generate(
      1,
      (_) => List.generate(oh, (_) => List.generate(ow, (_) => List<double>.filled(3, 0.0))),
    );
    interp.run(input, output);

    // اكتشاف مجال القيم
    double mn = double.infinity, mx = -double.infinity;
    for (final row in output[0]) {
      for (final px in row) {
        for (final v in px) {
          if (v < mn) mn = v;
          if (v > mx) mx = v;
        }
      }
    }
    double scale, bias;
    if (mn < -0.05) {
      scale = 127.5;
      bias = 127.5; // [-1,1]
    } else if (mx <= 1.5) {
      scale = 255;
      bias = 0; // [0,1]
    } else {
      scale = 1;
      bias = 0; // [0,255]
    }
    final rgba = Uint8List(ow * oh * 4);
    for (int y = 0; y < oh; y++) {
      for (int x = 0; x < ow; x++) {
        final px = output[0][y][x];
        final o = (y * ow + x) * 4;
        rgba[o] = (px[0] * scale + bias).round().clamp(0, 255).toInt();
        rgba[o + 1] = (px[1] * scale + bias).round().clamp(0, 255).toInt();
        rgba[o + 2] = (px[2] * scale + bias).round().clamp(0, 255).toInt();
        rgba[o + 3] = 255;
      }
    }
    final styled = await MediaService.imageFromPixels(rgba, ow, oh);
    final orig = await MediaService.imageFromPixels(src.rgba, src.w, src.h);

    // نعيد تكبير النتيجة لأبعاد الأصل ونمزجها بحسب الشدة
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final dst = ui.Rect.fromLTWH(0, 0, src.w.toDouble(), src.h.toDouble());
    canvas.drawImageRect(
      orig,
      ui.Rect.fromLTWH(0, 0, src.w.toDouble(), src.h.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.drawImageRect(
      styled,
      ui.Rect.fromLTWH(0, 0, ow.toDouble(), oh.toDouble()),
      dst,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..color = ui.Color.fromRGBO(255, 255, 255, strength.clamp(0.0, 1.0).toDouble()),
    );
    final result = await rec.endRecording().toImage(src.w, src.h);
    final ref = await MediaService.saveImage(result, prefix: 'anime');
    return ImageResult(path: ref.path, width: ref.w, height: ref.h, note: 'tflite:${math.min(iw, ih)}');
  }

  void dispose() {
    _interp?.close();
    _interp = null;
  }
}
