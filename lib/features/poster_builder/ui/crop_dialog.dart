import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/image_edit_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../bloc/canvas_bloc.dart';
import '../model/layer.dart';

/// قص صورة طبقة: أربعة منزلقات للقص من كل جهة + نسب جاهزة + معاينة حية.
Future<void> showCropDialog(BuildContext context, Layer layer, ImageStore images) async {
  final bloc = context.read<CanvasBloc>();
  await showDialog<void>(
    context: context,
    builder: (ctx) => _CropDialog(layer: layer, images: images, bloc: bloc),
  );
}

class _CropDialog extends StatefulWidget {
  const _CropDialog({required this.layer, required this.images, required this.bloc});
  final Layer layer;
  final ImageStore images;
  final CanvasBloc bloc;

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  // نسبة القص من كل جهة (0..0.9)
  double _l = 0, _t = 0, _r = 0, _b = 0;
  bool _busy = false;

  static const _ratios = <(String, double)>[
    ('1:1', 1),
    ('4:5', 4 / 5),
    ('3:4', 3 / 4),
    ('16:9', 16 / 9),
    ('9:16', 9 / 16),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.layer.path;
    if (p != null) {
      widget.images.ensure(p).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Rect get _rect => Rect.fromLTWH(_l, _t, math.max(0.05, 1 - _l - _r), math.max(0.05, 1 - _t - _b));

  /// أكبر مستطيل بنسبة معينة (عرض/ارتفاع بالبكسل) في منتصف الصورة.
  void _applyRatio(double a) {
    final img = widget.images.get(widget.layer.path);
    if (img == null) return;
    final ia = img.width / img.height;
    double nw, nh;
    if (a / ia >= 1) {
      nw = 1;
      nh = ia / a;
    } else {
      nh = 1;
      nw = a / ia;
    }
    setState(() {
      _l = _r = (1 - nw) / 2;
      _t = _b = (1 - nh) / 2;
    });
  }

  Future<void> _apply() async {
    final l = widget.layer;
    final rect = _rect;
    if (rect.width > 0.999 && rect.height > 0.999) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ImageEditService.bake(l, crop: rect);
      await widget.images.ensure(r.path);
      widget.bloc.add(ImageBaked(
        l.id,
        r.path,
        l.w * rect.width,
        l.h * rect.height,
        shiftLocal: Offset((rect.center.dx - 0.5) * l.w, (rect.center.dy - 0.5) * l.h),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر القص: $e')));
      }
    }
  }

  Widget _slider(String label, double v, ValueChanged<double> on) =>
      SliderRow(label: label, value: v, min: 0, max: 0.9, onChanged: on, display: (x) => '${(x * 100).round()}%');

  @override
  Widget build(BuildContext context) {
    final l = widget.layer;
    final img = widget.images.get(l.path);
    final ar = l.w / math.max(1.0, l.h);
    return Dialog(
      backgroundColor: AppColors.panel,
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('قص الصورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: AspectRatio(
                    aspectRatio: ar,
                    child: img == null
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              RawImage(image: img, fit: BoxFit.fill),
                              CustomPaint(painter: _CropPainter(_rect)),
                            ],
                          ),
                  ),
                ),
              ),
              const SectionLabel('نسب جاهزة'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChipChoice(
                      label: 'الأصلية',
                      selected: false,
                      onTap: () => setState(() => _l = _t = _r = _b = 0),
                    ),
                    for (final r in _ratios) ChipChoice(label: r.$1, selected: false, onTap: () => _applyRatio(r.$2)),
                  ],
                ),
              ),
              _slider('من اليسار', _l, (v) => setState(() => _l = math.min(v, 0.95 - _r))),
              _slider('من اليمين', _r, (v) => setState(() => _r = math.min(v, 0.95 - _l))),
              _slider('من الأعلى', _t, (v) => setState(() => _t = math.min(v, 0.95 - _b))),
              _slider('من الأسفل', _b, (v) => setState(() => _b = math.min(v, 0.95 - _t))),
              const SizedBox(height: 8),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: img == null ? null : _apply, child: const Text('تطبيق'))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يظلّل خارج مستطيل القص ويرسم إطاره.
class _CropPainter extends CustomPainter {
  _CropPainter(this.r);
  final Rect r;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(r.left * size.width, r.top * size.height, r.width * size.width, r.height * size.height);
    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRect(box)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = const Color(0x99000000));
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) => old.r != r;
}
