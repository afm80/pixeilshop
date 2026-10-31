import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/font_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../bloc/canvas_bloc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';
import 'editor_panel.dart';
import '../../../core/services/image_store.dart';

typedef _Item = ({String id, IconData icon, String label, VoidCallback? tap});

/// الشريط السفلي السياقي + النافذة المنبثقة فوقه (على نمط بوستر شوب).
class EditorBottom extends StatelessWidget {
  const EditorBottom({
    super.key,
    required this.controller,
    required this.images,
    required this.popup,
    required this.onEditNewText,
    required this.onEditText,
  });
  final EditorController controller;
  final ImageStore images;
  final ValueNotifier<String?> popup;
  final VoidCallback onEditNewText;
  final VoidCallback onEditText;

  static const _titles = {
    'add': 'إضافة',
    'layer': 'خصائص العنصر',
    'bg': 'الخلفية والمقاس',
    'layers': 'الطبقات',
    'color': 'فلاتر وألوان التصميم',
    'opacity': 'الشفافية',
    'size': 'الحجم',
    'rotate': 'الدوران',
    'p:color': 'اللون',
    'p:border': 'الإطار',
    'p:shadow': 'الظل',
    'p:corners': 'الزوايا',
    'p:blend': 'وضع الدمج',
    'p:font': 'الخطوط',
    'p:effects': 'الانعكاس والتظليل',
    'p:pos': 'الموقع',
    'p:depth': 'العمق',
    'p:skew': 'الانحناء',
    'p:image': 'قص وتدوير',
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, st) {
        final bloc = context.read<CanvasBloc>();
        final l = st.selected;
        void flip() {
          if (l != null) bloc.add(LayerMutated((x) => x.flipX = !x.flipX, id: l.id, commit: true));
        }

        _Item it(String id, IconData icon, String label, [VoidCallback? tap]) => (id: id, icon: icon, label: label, tap: tap);

        final List<_Item> items;
        if (l == null) {
          items = [
            it('add', Icons.add_circle_outline, 'إضافة'),
            it('bg', Icons.wallpaper, 'الخلفية'),
            it('layers', Icons.layers_outlined, 'الطبقات'),
            it('color', Icons.filter_vintage_outlined, 'فلاتر'),
          ];
        } else if (l.type == LayerType.text) {
          items = [
            it('add', Icons.add_circle_outline, 'إضافة'),
            it('edit', Icons.edit_outlined, 'تحرير', onEditText),
            it('p:color', Icons.palette_outlined, 'اللون'),
            it('p:font', Icons.font_download_outlined, 'الخطوط'),
            it('p:border', Icons.crop_din, 'إحاطة'),
            it('p:effects', Icons.flip_to_back, 'انعكاس'),
            it('p:depth', Icons.layers_outlined, 'العمق'),
            it('p:skew', Icons.rotate_90_degrees_ccw, 'انحناء'),
            it('p:corners', Icons.rounded_corner, 'خلفية'),
            it('p:shadow', Icons.blur_on, 'الظل'),
            it('opacity', Icons.opacity, 'الشفافية'),
            it('p:blend', Icons.layers, 'وضع الدمج'),
            it('flip', Icons.flip, 'قلب', flip),
            it('size', Icons.zoom_out_map, 'الحجم'),
            it('rotate', Icons.rotate_right, 'الدوران'),
            it('p:pos', Icons.open_with, 'الموقع'),
          ];
        } else {
          items = [
            it('add', Icons.add_circle_outline, 'إضافة'),
            it('p:color', Icons.palette_outlined, 'اللون'),
            if (l.type == LayerType.image) it('p:image', Icons.crop_rotate, 'قص/تدوير'),
            it('p:border', Icons.border_style, 'إطار'),
            it('p:shadow', Icons.blur_on, 'الظل'),
            it('p:corners', Icons.rounded_corner, 'الزوايا'),
            it('opacity', Icons.opacity, 'الشفافية'),
            if (l.type == LayerType.image) it('color', Icons.filter_vintage_outlined, 'فلاتر'),
            it('p:blend', Icons.layers, 'وضع الدمج'),
            it('flip', Icons.flip, 'قلب', flip),
            it('size', Icons.zoom_out_map, 'الحجم'),
            it('rotate', Icons.rotate_right, 'الدوران'),
            it('p:pos', Icons.open_with, 'الموقع'),
          ];
        }

        return ValueListenableBuilder<String?>(
          valueListenable: popup,
          builder: (context, open, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (open != null)
                  Container(
                    height: 290,
                    color: AppColors.panel,
                    child: Column(
                      children: [
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          color: AppColors.panel2,
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => popup.value = null,
                                icon: const Icon(Icons.check, color: AppColors.accent),
                              ),
                              Expanded(
                                child: Text(
                                  _titles[open] ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                        Expanded(child: _popupBody(open, l, bloc)),
                      ],
                    ),
                  ),
                Container(
                  height: 62,
                  color: AppColors.panel,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    children: [
                      for (final e in items)
                        InkWell(
                          onTap: () {
                            if (e.tap != null) {
                              e.tap!();
                            } else {
                              popup.value = popup.value == e.id ? null : e.id;
                            }
                          },
                          child: SizedBox(
                            width: 68,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(e.icon, size: 24, color: open == e.id ? AppColors.accent : AppColors.text),
                                const SizedBox(height: 4),
                                Text(e.label, style: TextStyle(fontSize: 11, color: open == e.id ? AppColors.accent : AppColors.text)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _popupBody(String open, Layer? l, CanvasBloc bloc) {
    if ((open == 'opacity' || open == 'size' || open == 'rotate') && l != null) {
      void start() => bloc.add(const CheckpointRequested());
      void live(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id));
      double deg(double rad) => ((rad * 180 / math.pi + 180) % 360) - 180;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (open == 'opacity')
              SliderRow(label: 'الشفافية', value: l.opacity, min: 0, max: 1, onStart: start, onChanged: (v) => live((x) => x.opacity = v), display: (v) => '${(v * 100).round()}%'),
            if (open == 'size')
              SliderRow(label: 'الحجم', value: l.scale, min: 0.1, max: 4, onStart: start, onChanged: (v) => live((x) => x.scale = v), display: (v) => '${(v * 100).round()}%'),
            if (open == 'rotate')
              SliderRow(label: 'الدوران', value: deg(l.rotation), min: -180, max: 180, onStart: start, onChanged: (v) => live((x) => x.rotation = v * math.pi / 180), display: (v) => '${v.round()}°'),
          ],
        ),
      );
    }
    return EditorPanel(
      key: ValueKey('p$open'),
      controller: controller,
      images: images,
      onEditNewText: onEditNewText,
      only: (open == 'opacity' || open == 'size' || open == 'rotate' || open.startsWith('p:')) ? 'layer' : open,
      part: open.startsWith('p:') ? open.substring(2) : null,
    );
  }
}

/// خلفية منقّطة خلف اللوحة.
class DotsPainter extends CustomPainter {
  const DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x14FFFFFF);
    for (double y = 6; y < size.height; y += 14) {
      for (double x = 6; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotsPainter old) => false;
}

// يُبقي الاستيراد مستخدماً لتسخين الخط الافتراضي عند الحاجة.
Future<void> warmDefaultFont() => FontService.ensure('Cairo');
