import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_matrices.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../poster_builder/bloc/canvas_bloc.dart';
import '../../poster_builder/model/adjust.dart';
import '../../poster_builder/model/layer.dart';

/// تعديل الألوان الاحترافي (Lightroom-style): مصفوفات ColorFilter.matrix لحظية.
class GradingPanel extends StatefulWidget {
  const GradingPanel({super.key});

  @override
  State<GradingPanel> createState() => _GradingPanelState();
}

class _GradingPanelState extends State<GradingPanel> {
  bool _wholeDoc = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, st) {
        final bloc = context.read<CanvasBloc>();
        final sel = st.selected;
        final canLayer = sel != null;
        final doc = _wholeDoc || !canLayer;
        final Adjust a = doc ? st.doc.adjust : sel!.adj;

        void edit(void Function(Adjust) f, {bool commit = false}) {
          if (doc) {
            bloc.add(DocMutated((d) => f(d.adjust), commit: commit));
          } else {
            bloc.add(LayerMutated((l) => f(l.adj), id: sel!.id, commit: commit));
          }
        }

        Widget slider(String label, double v, double min, double max, void Function(Adjust, double) set) => SliderRow(
              label: label,
              value: v,
              min: min,
              max: max,
              onStart: () => bloc.add(const CheckpointRequested()),
              onChanged: (x) => edit((ad) => set(ad, x)),
              display: (x) => (x * (max == 180 ? 1 : 100)).round().toString(),
            );

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                ChipChoice(
                  label: canLayer ? 'الطبقة المحددة' : 'اختر طبقة',
                  selected: !doc,
                  onTap: () => setState(() => _wholeDoc = false),
                ),
                ChipChoice(label: 'التصميم كله', selected: doc, onTap: () => setState(() => _wholeDoc = true)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => edit((ad) => ad.reset(), commit: true),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('إعادة ضبط'),
                ),
              ],
            ),
            const SectionLabel('فلاتر سينمائية'),
            SizedBox(
              height: 84,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ColorMatrices.presets.length,
                itemBuilder: (context, i) {
                  final p = ColorMatrices.presets[i];
                  final on = a.preset == i;
                  return GestureDetector(
                    onTap: () => edit((ad) {
                      ad.preset = i;
                      ad.presetAmount = 1;
                    }, commit: true),
                    child: Container(
                      width: 66,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [p.swatch1, p.swatch2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              border: Border.all(color: on ? AppColors.accent : Colors.transparent, width: 3),
                            ),
                            child: i == 0 ? const Icon(Icons.block, size: 20, color: Colors.white54) : null,
                          ),
                          const SizedBox(height: 3),
                          Text(p.name, style: TextStyle(fontSize: 10.5, color: on ? AppColors.accent : AppColors.muted), maxLines: 1),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (a.preset != 0) slider('شدة الفلتر', a.presetAmount, 0, 1, (ad, v) => ad.presetAmount = v),
            const SectionLabel('الإضاءة واللون'),
            slider('السطوع', a.brightness, -1, 1, (ad, v) => ad.brightness = v),
            slider('التباين', a.contrast, -1, 1, (ad, v) => ad.contrast = v),
            slider('التشبع', a.saturation, -1, 1, (ad, v) => ad.saturation = v),
            slider('الحرارة', a.temperature, -1, 1, (ad, v) => ad.temperature = v),
            slider('الصبغة', a.tint, -1, 1, (ad, v) => ad.tint = v),
            slider('بهتان', a.fade, 0, 1, (ad, v) => ad.fade = v),
            slider('تدرج اللون', a.hue, -180, 180, (ad, v) => ad.hue = v),
            if (doc) slider('فينيت', a.vignette, 0, 1, (ad, v) => ad.vignette = v),
          ],
        );
      },
    );
  }
}

/// يُستخدم لمعاينة اسم الطبقة فقط.
String layerTypeName(LayerType t) => switch (t) {
      LayerType.text => 'نص',
      LayerType.image => 'صورة',
      LayerType.shape => 'شكل',
    };
