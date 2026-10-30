import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/font_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/blend_modes.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../anime_morph/ui/anime_section.dart';
import '../../background_remover/ui/remover_section.dart';
import '../bloc/canvas_bloc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';

Future<void> showTextEditor(BuildContext context, Layer layer) async {
  final bloc = context.read<CanvasBloc>();
  final ctrl = TextEditingController(text: layer.text);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'النص', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final t = ctrl.text;
                bloc.add(LayerMutated((l) => l.text = t.isEmpty ? ' ' : t, id: layer.id, commit: true));
                Navigator.pop(ctx);
              },
              child: const Text('تم'),
            ),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
}

class LayerPanel extends StatelessWidget {
  const LayerPanel({super.key, required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, st) {
        final l = st.selected;
        if (l == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('اضغط على أي عنصر في التصميم لتعديل خصائصه', style: TextStyle(color: AppColors.muted)),
            ),
          );
        }
        final bloc = context.read<CanvasBloc>();
        void set(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id, commit: true));
        void live(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id));
        void start() => bloc.add(const CheckpointRequested());

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // أزرار سريعة
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Act(Icons.copy_all_outlined, 'تكرار', () => bloc.add(LayerDuplicated(l.id))),
                  _Act(Icons.flip, 'قلب', () => set((x) => x.flipX = !x.flipX)),
                  _Act(l.locked ? Icons.lock : Icons.lock_open, l.locked ? 'مقفلة' : 'قفل', () => set((x) => x.locked = !x.locked)),
                  _Act(l.hidden ? Icons.visibility_off : Icons.visibility, 'إظهار/إخفاء', () => set((x) => x.hidden = !x.hidden)),
                  _Act(Icons.vertical_align_top, 'للأمام', () => bloc.add(LayerZMoved(l.id, toFront: true))),
                  _Act(Icons.vertical_align_bottom, 'للخلف', () => bloc.add(LayerZMoved(l.id, toBack: true))),
                  _Act(Icons.delete_outline, 'حذف', () => bloc.add(LayerRemoved(l.id)), color: AppColors.danger),
                ],
              ),
            ),
            if (l.type == LayerType.text) ..._textControls(context, l, set, live, start),
            if (l.type == LayerType.shape) ..._shapeControls(l, set, live, start),
            if (l.type == LayerType.image) ...[
              RemoverSection(layer: l, controller: controller),
              AnimeSection(layer: l),
            ],
            const SectionLabel('الشفافية والدوران'),
            SliderRow(
              label: 'الشفافية',
              value: l.opacity,
              min: 0,
              max: 1,
              onStart: start,
              onChanged: (v) => live((x) => x.opacity = v),
              display: (v) => '${(v * 100).round()}%',
            ),
            SliderRow(
              label: 'الدوران',
              value: _deg(l.rotation),
              min: -180,
              max: 180,
              onStart: start,
              onChanged: (v) => live((x) => x.rotation = v * math.pi / 180),
              display: (v) => '${v.round()}°',
            ),
            SliderRow(
              label: 'الحجم',
              value: l.scale,
              min: 0.1,
              max: 4,
              onStart: start,
              onChanged: (v) => live((x) => x.scale = v),
              display: (v) => '${(v * 100).round()}%',
            ),
            const SectionLabel('الدمج (Blend)'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < kBlends.length; i++) ChipChoice(label: kBlends[i].label, selected: l.blend == i, onTap: () => set((x) => x.blend = i)),
                ],
              ),
            ),
            ..._shadowControls(l, set, live, start),
          ],
        );
      },
    );
  }

  static double _deg(double rad) {
    var d = rad * 180 / math.pi;
    d = ((d + 180) % 360) - 180;
    return d;
  }

  List<Widget> _shadowControls(Layer l, void Function(void Function(Layer)) set, void Function(void Function(Layer)) live, VoidCallback start) {
    return [
      const SectionLabel('الظل'),
      Row(
        children: [
          Switch(value: l.shOn, onChanged: (v) => set((x) => x.shOn = v)),
          const Text('تفعيل الظل (يتبع شكل العنصر)', style: TextStyle(fontSize: 12.5)),
        ],
      ),
      if (l.shOn) ...[
        Row(
          children: [
            ChipChoice(label: 'ظل ساقط', selected: !l.shGround, onTap: () => set((x) => x.shGround = false)),
            ChipChoice(label: 'ظل أرضي', selected: l.shGround, onTap: () => set((x) => x.shGround = true)),
          ],
        ),
        SliderRow(label: 'التمويه', value: l.shBlur, min: 0, max: 60, onStart: start, onChanged: (v) => live((x) => x.shBlur = v), display: (v) => v.round().toString()),
        SliderRow(label: 'إزاحة أفقية', value: l.shDx, min: -80, max: 80, onStart: start, onChanged: (v) => live((x) => x.shDx = v), display: (v) => v.round().toString()),
        SliderRow(label: 'إزاحة رأسية', value: l.shDy, min: -80, max: 80, onStart: start, onChanged: (v) => live((x) => x.shDy = v), display: (v) => v.round().toString()),
        SliderRow(label: 'القوة', value: l.shOpacity, min: 0, max: 1, onStart: start, onChanged: (v) => live((x) => x.shOpacity = v), display: (v) => '${(v * 100).round()}%'),
        ColorRow(selected: l.shColor, onPick: (c) => set((x) => x.shColor = c)),
      ],
    ];
  }

  List<Widget> _textControls(BuildContext context, Layer l, void Function(void Function(Layer)) set, void Function(void Function(Layer)) live, VoidCallback start) {
    return [
      const SizedBox(height: 6),
      Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () => showTextEditor(context, l),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('تعديل النص'),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(onPressed: () => set((x) => x.bold = !x.bold), isSelected: l.bold, icon: const Icon(Icons.format_bold)),
          IconButton.filledTonal(onPressed: () => set((x) => x.italic = !x.italic), isSelected: l.italic, icon: const Icon(Icons.format_italic)),
          IconButton(onPressed: () => set((x) => x.align = 0), icon: Icon(Icons.format_align_left, color: l.align == 0 ? AppColors.accent : null)),
          IconButton(onPressed: () => set((x) => x.align = 1), icon: Icon(Icons.format_align_center, color: l.align == 1 ? AppColors.accent : null)),
          IconButton(onPressed: () => set((x) => x.align = 2), icon: Icon(Icons.format_align_right, color: l.align == 2 ? AppColors.accent : null)),
        ],
      ),
      const SectionLabel('الخط'),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in FontService.all) ChipChoice(label: f, selected: l.font == f, onTap: () => set((x) => x.font = f)),
          ],
        ),
      ),
      SliderRow(label: 'حجم الخط', value: l.fontSize, min: 16, max: 400, onStart: start, onChanged: (v) => live((x) => x.fontSize = v), display: (v) => v.round().toString()),
      SliderRow(label: 'عرض الصندوق', value: l.w, min: 80, max: 2400, onStart: start, onChanged: (v) => live((x) => x.w = v), display: (v) => v.round().toString()),
      SliderRow(label: 'تباعد الحروف', value: l.letterSpacing, min: -5, max: 40, onStart: start, onChanged: (v) => live((x) => x.letterSpacing = v), display: (v) => v.toStringAsFixed(0)),
      SliderRow(label: 'ارتفاع السطر', value: l.lineHeight, min: 0.8, max: 2.4, onStart: start, onChanged: (v) => live((x) => x.lineHeight = v)),
      const SectionLabel('اللون'),
      ColorRow(selected: l.color, onPick: (c) => set((x) {
            x.color = c;
            x.gradOn = false;
          })),
      Row(
        children: [
          Switch(value: l.gradOn, onChanged: (v) => set((x) => x.gradOn = v)),
          const Text('تدرج لوني', style: TextStyle(fontSize: 12.5)),
        ],
      ),
      if (l.gradOn) ...[
        ColorRow(selected: l.grad1, onPick: (c) => set((x) => x.grad1 = c)),
        ColorRow(selected: l.grad2, onPick: (c) => set((x) => x.grad2 = c)),
      ],
      const SectionLabel('حدود النص'),
      SliderRow(label: 'سمك الحد', value: l.strokeW, min: 0, max: 30, onStart: start, onChanged: (v) => live((x) => x.strokeW = v), display: (v) => v.round().toString()),
      if (l.strokeW > 0) ColorRow(selected: l.strokeColor, onPick: (c) => set((x) => x.strokeColor = c)),
      Row(
        children: [
          Switch(value: l.boxOn, onChanged: (v) => set((x) => x.boxOn = v)),
          const Text('خلفية للنص', style: TextStyle(fontSize: 12.5)),
        ],
      ),
      if (l.boxOn) ...[
        ColorRow(selected: l.boxColor, onPick: (c) => set((x) => x.boxColor = c)),
        SliderRow(label: 'استدارة', value: l.boxRadius, min: 0, max: 100, onStart: start, onChanged: (v) => live((x) => x.boxRadius = v), display: (v) => v.round().toString()),
      ],
    ];
  }

  List<Widget> _shapeControls(Layer l, void Function(void Function(Layer)) set, void Function(void Function(Layer)) live, VoidCallback start) {
    return [
      const SectionLabel('لون الشكل'),
      ColorRow(selected: l.color, onPick: (c) => set((x) {
            x.color = c;
            x.gradOn = false;
          })),
      Row(
        children: [
          Switch(value: l.gradOn, onChanged: (v) => set((x) => x.gradOn = v)),
          const Text('تدرج لوني', style: TextStyle(fontSize: 12.5)),
        ],
      ),
      if (l.gradOn) ...[
        ColorRow(selected: l.grad1, onPick: (c) => set((x) => x.grad1 = c)),
        ColorRow(selected: l.grad2, onPick: (c) => set((x) => x.grad2 = c)),
      ],
      SliderRow(label: 'العرض', value: l.w, min: 40, max: 2400, onStart: start, onChanged: (v) => live((x) => x.w = v), display: (v) => v.round().toString()),
      SliderRow(label: 'الارتفاع', value: l.h, min: 20, max: 2400, onStart: start, onChanged: (v) => live((x) => x.h = v), display: (v) => v.round().toString()),
      if (l.shape == ShapeKind.rect)
        SliderRow(label: 'استدارة الزوايا', value: l.cornerRadius, min: 0, max: 300, onStart: start, onChanged: (v) => live((x) => x.cornerRadius = v), display: (v) => v.round().toString()),
      SliderRow(label: 'سمك الحد', value: l.strokeW, min: 0, max: 40, onStart: start, onChanged: (v) => live((x) => x.strokeW = v), display: (v) => v.round().toString()),
      if (l.strokeW > 0) ColorRow(selected: l.strokeColor, onPick: (c) => set((x) => x.strokeColor = c)),
    ];
  }
}

class _Act extends StatelessWidget {
  const _Act(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ActionChip(
          avatar: Icon(icon, size: 16, color: color),
          label: Text(label, style: TextStyle(fontSize: 12, color: color)),
          onPressed: onTap,
          backgroundColor: AppColors.panel2,
          side: BorderSide.none,
        ),
      );
}
