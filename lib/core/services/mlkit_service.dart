import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

class SegMask {
  const SegMask(this.w, this.h, this.conf);
  final int w, h;
  final Float32List conf; // 0..1 احتمال أن البكسل عنصر أمامي
}

/// عزل العناصر والأشخاص محلياً عبر ML Kit (مجاني وبدون إنترنت بعد تنزيل النموذج).
/// يُستخدم الوصول الديناميكي لحقول النتيجة لتفادي كسر التوافق بين إصدارات الحزم.
class MlKitService {
  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Float32List? _toFloat(dynamic list) {
    if (list == null) return null;
    if (list is Float32List) return list;
    if (list is List) {
      final out = Float32List(list.length);
      for (int i = 0; i < list.length; i++) {
        out[i] = (list[i] as num).toDouble();
      }
      return out;
    }
    return null;
  }

  /// قناع العناصر/المنتجات/الأشخاص (Android فقط).
  Future<SegMask?> segmentSubject(String pngPath, int w, int h) async {
    if (!_supported || !Platform.isAndroid) return null;
    SubjectSegmenter? seg;
    try {
      seg = SubjectSegmenter(options: SubjectSegmenterOptions());
      final dynamic res = await seg.processImage(InputImage.fromFilePath(pngPath));
      final conf = _toFloat(res?.foregroundConfidenceMask);
      if (conf == null || conf.isEmpty) return null;
      if (conf.length == w * h) return SegMask(w, h, conf);
      try {
        final int mw = res.width as int, mh = res.height as int;
        if (mw * mh == conf.length) return SegMask(mw, mh, conf);
      } catch (_) {}
      return null;
    } catch (e) {
      debugPrint('subject segmentation failed: $e');
      return null;
    } finally {
      try {
        seg?.close();
      } catch (_) {}
    }
  }

  /// قناع الأشخاص (Android + iOS).
  Future<SegMask?> segmentSelfie(String pngPath, int w, int h) async {
    if (!_supported) return null;
    SelfieSegmenter? seg;
    try {
      seg = SelfieSegmenter(mode: SegmenterMode.single, enableRawSizeMask: false);
      final dynamic mask = await seg.processImage(InputImage.fromFilePath(pngPath));
      if (mask == null) return null;
      final conf = _toFloat(mask.confidences);
      if (conf == null || conf.isEmpty) return null;
      final int mw = mask.width as int, mh = mask.height as int;
      if (mw * mh != conf.length) return null;
      return SegMask(mw, mh, conf);
    } catch (e) {
      debugPrint('selfie segmentation failed: $e');
      return null;
    } finally {
      try {
        seg?.close();
      } catch (_) {}
    }
  }
}
