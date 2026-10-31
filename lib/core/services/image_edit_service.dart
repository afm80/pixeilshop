import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../features/poster_builder/model/layer.dart';
import 'media_service.dart';

/// قص وتدوير الصور: ينتج ملف PNG جديداً ("خَبز") تُستبدل به صورة الطبقة.
/// ضربات الممحاة اليدوية تُخبَز في الصورة أيضاً فلا تضيع.
class ImageEditService {
  static Future<ui.Image> _decode(String path) async {
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
    return img;
  }

  /// [crop]: مستطيل نسبي (0..1) من الصورة. [quarterTurns]: دورات 90° مع عقارب الساعة.
  static Future<MediaRef> bake(
    Layer l, {
    ui.Rect crop = const ui.Rect.fromLTWH(0, 0, 1, 1),
    int quarterTurns = 0,
  }) async {
    final src = await _decode(l.path!);
    final iw = src.width.toDouble(), ih = src.height.toDouble();
    final sx = crop.left * iw, sy = crop.top * ih;
    final sw = math.max(1.0, crop.width * iw), sh = math.max(1.0, crop.height * ih);
    final turns = quarterTurns % 4;
    final turned = turns.isOdd;
    final ow = (turned ? sh : sw).round().clamp(1, 8192).toInt();
    final oh = (turned ? sw : sh).round().clamp(1, 8192).toInt();

    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);

    // نقل المستطيل المقصوص إلى (0,0) ثم تدويره بحيث يبقى داخل الإطار الناتج
    switch (turns) {
      case 1:
        c.translate(sh, 0);
        break;
      case 2:
        c.translate(sw, sh);
        break;
      case 3:
        c.translate(0, sw);
        break;
      default:
        break;
    }
    c.rotate(turns * math.pi / 2);
    c.translate(-sx, -sy);

    // الصورة + الممحاة اليدوية داخل طبقة واحدة
    c.saveLayer(ui.Rect.fromLTWH(0, 0, iw, ih), ui.Paint());
    c.drawImage(src, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.high);
    for (final s in l.erase) {
      final r = s.r * iw;
      if (s.pts.length < 4) {
        if (s.pts.length >= 2) {
          c.drawCircle(
            ui.Offset(s.pts[0] * iw + iw / 2, s.pts[1] * iw + ih / 2),
            r,
            ui.Paint()
              ..blendMode = ui.BlendMode.clear
              ..isAntiAlias = true,
          );
        }
        continue;
      }
      final path = ui.Path()..moveTo(s.pts[0] * iw + iw / 2, s.pts[1] * iw + ih / 2);
      for (int i = 2; i + 1 < s.pts.length; i += 2) {
        path.lineTo(s.pts[i] * iw + iw / 2, s.pts[i + 1] * iw + ih / 2);
      }
      c.drawPath(
        path,
        ui.Paint()
          ..blendMode = ui.BlendMode.clear
          ..isAntiAlias = true
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = r * 2,
      );
    }
    c.restore();

    final out = await rec.endRecording().toImage(ow, oh);
    return MediaService.saveImage(out, prefix: 'edit');
  }
}
