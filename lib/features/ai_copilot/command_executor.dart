import '../../core/services/tflite_service.dart';
import '../anime_morph/bloc/anime_bloc.dart';
import '../background_remover/bloc/subject_segmentation_bloc.dart';
import '../poster_builder/bloc/canvas_bloc.dart';
import '../poster_builder/model/adjust.dart';
import '../poster_builder/model/layer.dart';
import 'command_parser.dart';

/// ينفّذ الأمر المفهوم على الـ Blocs: CanvasBloc / SubjectSegmentationBloc / AnimeBloc.
class CommandExecutor {
  CommandExecutor({required this.canvas, required this.remover, required this.anime, required this.onExport});
  final CanvasBloc canvas;
  final SubjectSegmentationBloc remover;
  final AnimeBloc anime;
  final void Function() onExport;

  Layer? _imageTarget() {
    final s = canvas.state.selected;
    if (s != null && s.type == LayerType.image && s.path != null) return s;
    for (final l in canvas.state.doc.layers.reversed) {
      if (l.type == LayerType.image && !l.hidden && l.path != null) return l;
    }
    return null;
  }

  Layer? _anyTarget() {
    final s = canvas.state.selected;
    if (s != null) return s;
    final ls = canvas.state.doc.layers.where((l) => !l.hidden).toList();
    return ls.isEmpty ? null : ls.last;
  }

  /// يعيد رسالة للمستخدم.
  String execute(CopilotCommand c) {
    if (c is RemoveBackgroundCmd) {
      final t = _imageTarget();
      if (t == null) return 'أضف صورة أولاً ثم كرر الأمر';
      remover.removeBackground(t.id, t.path!);
      return 'جارٍ إزالة الخلفية…';
    }
    if (c is AddTextCmd) {
      canvas.add(TextLayerAdded(c.text));
      return 'تمت إضافة النص «${c.text}»';
    }
    if (c is AddShapeCmd) {
      canvas.add(ShapeLayerAdded(c.kind));
      return 'تمت إضافة الشكل';
    }
    if (c is StyleCmd) {
      final t = _imageTarget();
      if (t == null) return 'أضف صورة أولاً ثم كرر الأمر';
      anime.runAnimeModel(t.id, t.path!, kind: c.kind);
      return 'جارٍ التحويل إلى ${c.kind.label}…';
    }
    if (c is FilterCmd) {
      _withAdjust((a) {
        a.preset = c.preset;
        a.presetAmount = 1;
      });
      return c.preset == 0 ? 'تمت إزالة الفلتر' : 'تم تطبيق الفلتر';
    }
    if (c is AdjustCmd) {
      _withAdjust((a) {
        final isPositiveOnly = c.param == AdjustParam.vignette || c.param == AdjustParam.fade;
        final lo = isPositiveOnly ? 0.0 : -1.0;
        double cur;
        switch (c.param) {
          case AdjustParam.brightness:
            cur = a.brightness;
            break;
          case AdjustParam.contrast:
            cur = a.contrast;
            break;
          case AdjustParam.saturation:
            cur = a.saturation;
            break;
          case AdjustParam.temperature:
            cur = a.temperature;
            break;
          case AdjustParam.vignette:
            cur = a.vignette;
            break;
          case AdjustParam.fade:
            cur = a.fade;
            break;
        }
        final v = (c.relative ? cur + c.amount : c.amount).clamp(lo, 1.0).toDouble();
        switch (c.param) {
          case AdjustParam.brightness:
            a.brightness = v;
            break;
          case AdjustParam.contrast:
            a.contrast = v;
            break;
          case AdjustParam.saturation:
            a.saturation = v;
            break;
          case AdjustParam.temperature:
            a.temperature = v;
            break;
          case AdjustParam.vignette:
            a.vignette = v;
            break;
          case AdjustParam.fade:
            a.fade = v;
            break;
        }
      }, forceDoc: c.param == AdjustParam.vignette);
      return 'تم ضبط الألوان';
    }
    if (c is ShadowCmd) {
      final t = _anyTarget();
      if (t == null) return 'لا توجد طبقة لإضافة الظل';
      canvas.add(LayerMutated((l) => l.shOn = c.on, id: t.id, commit: true));
      return c.on ? 'تمت إضافة الظل' : 'تمت إزالة الظل';
    }
    if (c is UndoCmd) {
      canvas.add(const UndoRequested());
      return 'تم التراجع';
    }
    if (c is RedoCmd) {
      canvas.add(const RedoRequested());
      return 'تمت الإعادة';
    }
    if (c is DeleteLayerCmd) {
      if (canvas.state.selected == null) return 'حدد طبقة لحذفها';
      canvas.add(const LayerRemoved());
      return 'تم حذف الطبقة';
    }
    if (c is DuplicateCmd) {
      if (canvas.state.selected == null) return 'حدد طبقة لتكرارها';
      canvas.add(const LayerDuplicated());
      return 'تم تكرار الطبقة';
    }
    if (c is FlipCmd) {
      final t = _anyTarget();
      if (t == null) return 'لا توجد طبقة';
      canvas.add(LayerMutated((l) => l.flipX = !l.flipX, id: t.id, commit: true));
      return 'تم قلب الطبقة';
    }
    if (c is ZOrderCmd) {
      final t = canvas.state.selected;
      if (t == null) return 'حدد طبقة أولاً';
      canvas.add(LayerZMoved(t.id, toFront: c.front, toBack: !c.front));
      return c.front ? 'نُقلت للأمام' : 'نُقلت للخلف';
    }
    if (c is BgColorCmd) {
      canvas.add(DocMutated((d) {
        d.bgKind = 0;
        d.bgColor1 = c.color;
      }, commit: true));
      return 'تم تغيير لون الخلفية';
    }
    if (c is TextColorCmd) {
      Layer? t = canvas.state.selected;
      if (t == null || t.type != LayerType.text) {
        t = null;
        for (final l in canvas.state.doc.layers.reversed) {
          if (l.type == LayerType.text) {
            t = l;
            break;
          }
        }
      }
      if (t == null) return 'لا يوجد نص';
      canvas.add(LayerMutated((l) {
        l.color = c.color;
        l.gradOn = false;
      }, id: t.id, commit: true));
      return 'تم تغيير لون النص';
    }
    if (c is ExportCmd) {
      onExport();
      return 'فتح خيارات التصدير';
    }
    return 'لم أفهم الأمر. جرّب: «ازل الخلفية» أو «اضف نص "عرض خاص"» أو «حول الصورة إلى أنمي»';
  }

  void _withAdjust(void Function(Adjust a) f, {bool forceDoc = false}) {
    final s = canvas.state.selected;
    if (!forceDoc && s != null && s.type == LayerType.image) {
      canvas.add(LayerMutated((l) => f(l.adj), id: s.id, commit: true));
    } else {
      canvas.add(DocMutated((d) => f(d.adjust), commit: true));
    }
  }
}
