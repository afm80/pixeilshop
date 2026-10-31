
import 'package:flutter/foundation.dart';

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

}

class StyleResult {
  const StyleResult(this.image, this.usedModel);
  final ImageResult image;
  final bool usedModel;
}

/// تحويل الصور لأنمي/كرتون/كوميك/رسم محلياً بفلتر Dart (بدون إنترنت وبدون نماذج).
class TfliteService {
  Future<bool> hasModel(StyleKind k) async => false;

  Future<StyleResult> stylize(String path, StyleKind kind, {double strength = 1.0}) async {
    final style = kind == StyleKind.sketch ? 1 : 0;
    final px = await MediaService.decodePixels(path, maxSide: 1280);
    final out = await compute(cartoonize, CartoonJob(px.rgba, px.w, px.h, style, strength));
    final ref = await MediaService.savePixels(out, px.w, px.h, prefix: 'style');
    return StyleResult(ImageResult(path: ref.path, width: px.w, height: px.h, note: 'dart'), false);
  }

  void dispose() {}
}
