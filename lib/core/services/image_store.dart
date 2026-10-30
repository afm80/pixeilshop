import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../features/poster_builder/model/doc.dart';
import '../../features/poster_builder/model/layer.dart';

/// كاش صور مفكوكة (ui.Image) تستخدمها لوحة الرسم والتصدير.
class ImageStore extends ChangeNotifier {
  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};

  ui.Image? get(String? path) => path == null ? null : _images[path];

  Future<void> ensure(String path) async {
    if (_images.containsKey(path) || _loading.contains(path)) return;
    _loading.add(path);
    try {
      final bytes = await File(path).readAsBytes();
      var codec = await ui.instantiateImageCodec(bytes);
      var img = (await codec.getNextFrame()).image;
      final m = math.max(img.width, img.height);
      if (m > 4096) {
        final k = 4096 / m;
        codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: (img.width * k).round(),
          targetHeight: (img.height * k).round(),
        );
        img = (await codec.getNextFrame()).image;
      }
      _images[path] = img;
      notifyListeners();
    } catch (e) {
      debugPrint('ImageStore: failed to load $path: $e');
    } finally {
      _loading.remove(path);
    }
  }

  /// يحمّل كل صور التصميم (الطبقات + الخلفية).
  Future<void> ensureDoc(Doc d) async {
    final paths = <String>{};
    if (d.bgKind == 2 && d.bgPath != null) paths.add(d.bgPath!);
    for (final l in d.layers) {
      if (l.type == LayerType.image && l.path != null) paths.add(l.path!);
    }
    await Future.wait(paths.map(ensure));
  }
}
