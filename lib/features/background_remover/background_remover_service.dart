import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/services/media_service.dart';
import '../../core/services/mlkit_service.dart';
import '../../core/utils/pixel_ops.dart';
import '../poster_builder/model/doc.dart';

class CutoutResult {
  const CutoutResult(this.image, this.method);
  final ImageResult image;
  final String method; // subject | selfie | color
}

class BackgroundRemoverService {
  BackgroundRemoverService(this._mlkit);
  final MlKitService _mlkit;

  /// سلسلة المحاولات: ML Kit (عناصر) ← ML Kit (أشخاص) ← ملء ألوان الحواف.
  Future<CutoutResult> remove(String path, {double tolerance = 42, bool colorOnly = false}) async {
    final px = await MediaService.decodePixels(path, maxSide: 2048);
    Float32List? conf;
    int mw = px.w, mh = px.h;
    String method = 'color';

    if (!colorOnly) {
      final tmp = await MediaService.tempPng(px);
      var mask = await _mlkit.segmentSubject(tmp, px.w, px.h);
      method = 'subject';
      if (mask == null || !_plausible(mask.conf)) {
        mask = await _mlkit.segmentSelfie(tmp, px.w, px.h);
        method = 'selfie';
      }
      if (mask != null && _plausible(mask.conf)) {
        conf = mask.conf;
        mw = mask.w;
        mh = mask.h;
      }
    }
    if (conf == null) {
      method = 'color';
      conf = await compute(floodMask, FloodJob(px.rgba, px.w, px.h, tolerance));
      mw = px.w;
      mh = px.h;
    }

    final out = await compute(applyMask, MaskJob(px.rgba, px.w, px.h, conf!, mw, mh));
    final ref = await MediaService.savePixels(out.rgba, out.w, out.h, prefix: 'cutout');
    return CutoutResult(
      ImageResult(
        path: ref.path,
        width: out.w,
        height: out.h,
        normLeft: out.left / out.srcW,
        normTop: out.top / out.srcH,
        normWidth: out.w / out.srcW,
        normHeight: out.h / out.srcH,
        note: method,
      ),
      method,
    );
  }

  bool _plausible(Float32List conf) {
    final c = maskCoverage(conf);
    return c > 0.01 && c < 0.97;
  }
}
