import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../core/services/font_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/services/media_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/blend_modes.dart';
import '../../../core/utils/color_matrices.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../anime_morph/ui/anime_section.dart';
import '../../background_remover/ui/remover_section.dart';
import '../bloc/canvas_bloc.dart';
import '../model/adjust.dart';
import '../model/doc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';

/// محرر موحّد: يجمع (الطبقة المحددة، الإضافة، الألوان، الخلفية والمقاس، الطبقات)
/// في لوحة واحدة بأقسام قابلة للطي بدل التبويبات المنفصلة.

// ───────────────────────── محرر النص ─────────────────────────

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

// ───────────────────────── ثوابت ─────────────────────────

const _stickers = [
  '⭐', '🔥', '❤️', '✨', '🎉', '👑', '💎', '🌟', '⚡', '🎯', '🏆', '💥', //
  '🌸', '🍕', '☕', '🚀', '🎵', '📣', '🛒', '🔔', '✅', '❌', '🆕', '🎁',
];

const _shapes = <(String, ShapeKind, IconData)>[
  ('مستطيل', ShapeKind.rect, Icons.crop_square),
  ('دائرة', ShapeKind.circle, Icons.circle_outlined),
  ('مثلث', ShapeKind.triangle, Icons.change_history),
  ('نجمة', ShapeKind.star, Icons.star_border),
  ('معين', ShapeKind.diamond, Icons.diamond_outlined),
  ('خط', ShapeKind.line, Icons.horizontal_rule),
];

const _docSizes = <(String, double, double)>[
  ('مربع 1:1', 1080, 1080),
  ('بوست 4:5', 1080, 1350),
  ('ستوري 9:16', 1080, 1920),
  ('أفقي 16:9', 1920, 1080),
  ('A4 بوستر', 1240, 1754),
  ('غلاف 3:1', 1500, 500),
];

typedef _Setter = void Function(void Function(Layer));

// ───────────────────────── اللوحة الموحدة ─────────────────────────

class EditorPanel extends StatefulWidget {
  const EditorPanel({super.key, required this.controller, required this.images, required this.onEditNewText});
  final EditorController controller;
  final ImageStore images;
  final VoidCallback onEditNewText;

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  bool _wholeDoc = false;

  EditorController get ec => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ec,
      builder: (context, _) => BlocBuilder<CanvasBloc, CanvasState>(
        builder: (context, st) {
          final sel = st.selected;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              _Section(
                key: const ValueKey('layer'),
                icon: Icons.tune,
                title: 'الطبقة المحددة',
                open: ec.isOpen('layer'),
                onTap: () => ec.toggle('layer'),
                builder: () => sel == null ? _noSelection() : _layerSection(context, sel),
              ),
              _Section(
                key: const ValueKey('add'),
                icon: Icons.add_circle_outline,
                title: 'إضافة',
                open: ec.isOpen('add'),
                onTap: () => ec.toggle('add'),
                builder: () => _addSection(context),
              ),
              _Section(
                key: const ValueKey('color'),
                icon: Icons.color_lens_outlined,
                title: 'الألوان',
                open: ec.isOpen('color'),
                onTap: () => ec.toggle('color'),
                builder: () => _colorSection(context, st),
              ),
              _Section(
                key: const ValueKey('bg'),
                icon: Icons.wallpaper,
                title: 'الخلفية والمقاس',
                open: ec.isOpen('bg'),
                onTap: () => ec.toggle('bg'),
                builder: () => _backgroundSection(context, st),
              ),
              _Section(
                key: const ValueKey('layers'),
                icon: Icons.layers_outlined,
                title: 'الطبقات',
                open: ec.isOpen('layers'),
                onTap: () => ec.toggle('layers'),
                builder: () => _layersSection(context, st),
              ),
            ],
          );
        },
      ),
    );
  }

  // ───────────── إضافة ─────────────

  Future<void> _addImage(BuildContext context, ImageSource src) async {
    final bloc = context.read<CanvasBloc>();
    final m = await MediaService.pick(source: src);
    if (m == null) return;
    // نفك الصورة قبل إضافتها: تظهر كاملة في مكانها النهائي بدون وميض أو قفزة.
    await widget.images.ensure(m.path);
    if (!mounted) return;
    bloc.add(ImageLayerAdded(m.path, m.w, m.h));
  }

  Widget _noSelection() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('اضغط على أي عنصر في التصميم لتعديل خصائصه', style: TextStyle(color: AppColors.muted)),
      );

  List<Widget> _addSection(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Big(
            icon: Icons.title,
            label: 'نص',
            onTap: () async {
              await FontService.ensure('Cairo'); // الخط جاهز قبل ظهور النص
              if (!mounted) return;
              bloc.add(const TextLayerAdded('اكتب هنا'));
              widget.onEditNewText();
            },
          ),
          _Big(icon: Icons.image_outlined, label: 'صورة', onTap: () => _addImage(context, ImageSource.gallery)),
          _Big(icon: Icons.photo_camera_outlined, label: 'كاميرا', onTap: () => _addImage(context, ImageSource.camera)),
        ],
      ),
      const SectionLabel('أشكال'),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final s in _shapes) ChipChoice(label: s.$1, icon: s.$3, selected: false, onTap: () => bloc.add(ShapeLayerAdded(s.$2))),
          ],
        ),
      ),
      const SectionLabel('ملصقات'),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final e in _stickers)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                await FontService.ensure('Cairo');
                if (!mounted) return;
                // حدث واحد بالحجم النهائي (بدل إضافة ثم تعديل) فلا يقفز الملصق
                bloc.add(TextLayerAdded(
                  e,
                  fontSize: bloc.state.doc.w * 0.2,
                  width: bloc.state.doc.w * 0.4,
                  bold: false,
                ));
              },
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10)),
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ],
      ),
    ];
  }

  // ───────────── الطبقة المحددة ─────────────

  static double _deg(double rad) {
    var d = rad * 180 / math.pi;
    d = ((d + 180) % 360) - 180;
    return d;
  }

  List<Widget> _layerSection(BuildContext context, Layer l) {
    final bloc = context.read<CanvasBloc>();
    void set(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id, commit: true));
    void live(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id));
    void start() => bloc.add(const CheckpointRequested());

    return [
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
        RemoverSection(layer: l, controller: ec),
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
    ];
  }

  List<Widget> _shadowControls(Layer l, _Setter set, _Setter live, VoidCallback start) {
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

  List<Widget> _textControls(BuildContext context, Layer l, _Setter set, _Setter live, VoidCallback start) {
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
            for (final f in FontService.all)
              ChipChoice(
                label: f,
                selected: l.font == f,
                onTap: () async {
                  await FontService.ensure(f); // نحمّل الخط ثم نطبّقه دفعة واحدة
                  set((x) => x.font = f);
                },
              ),
          ],
        ),
      ),
      SliderRow(label: 'حجم الخط', value: l.fontSize, min: 16, max: 400, onStart: start, onChanged: (v) => live((x) => x.fontSize = v), display: (v) => v.round().toString()),
      SliderRow(label: 'عرض الصندوق', value: l.w, min: 80, max: 2400, onStart: start, onChanged: (v) => live((x) => x.w = v), display: (v) => v.round().toString()),
      SliderRow(label: 'تباعد الحروف', value: l.letterSpacing, min: -5, max: 40, onStart: start, onChanged: (v) => live((x) => x.letterSpacing = v), display: (v) => v.toStringAsFixed(0)),
      SliderRow(label: 'ارتفاع السطر', value: l.lineHeight, min: 0.8, max: 2.4, onStart: start, onChanged: (v) => live((x) => x.lineHeight = v)),
      const SectionLabel('اللون'),
      ColorRow(
        selected: l.color,
        onPick: (c) => set((x) {
          x.color = c;
          x.gradOn = false;
        }),
      ),
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

  List<Widget> _shapeControls(Layer l, _Setter set, _Setter live, VoidCallback start) {
    return [
      const SectionLabel('لون الشكل'),
      ColorRow(
        selected: l.color,
        onPick: (c) => set((x) {
          x.color = c;
          x.gradOn = false;
        }),
      ),
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

  // ───────────── الألوان (Lightroom-style) ─────────────

  List<Widget> _colorSection(BuildContext context, CanvasState st) {
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

    return [
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
    ];
  }

  // ───────────── الخلفية والمقاس ─────────────

  List<Widget> _backgroundSection(BuildContext context, CanvasState st) {
    final d = st.doc;
    final bloc = context.read<CanvasBloc>();
    void set(void Function(Doc) f) => bloc.add(DocMutated(f, commit: true));
    return [
      const SectionLabel('نوع الخلفية'),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ChipChoice(label: 'لون', selected: d.bgKind == 0, onTap: () => set((x) => x.bgKind = 0)),
            ChipChoice(label: 'تدرج', selected: d.bgKind == 1, onTap: () => set((x) => x.bgKind = 1)),
            ChipChoice(
              label: 'صورة',
              selected: d.bgKind == 2,
              onTap: () async {
                final m = await MediaService.pick();
                if (m != null) {
                  await widget.images.ensure(m.path);
                  if (!mounted) return;
                  bloc.add(DocMutated((x) {
                    x.bgKind = 2;
                    x.bgPath = m.path;
                  }, commit: true));
                }
              },
            ),
            ChipChoice(label: 'شفافة', selected: d.bgKind == 3, onTap: () => set((x) => x.bgKind = 3)),
          ],
        ),
      ),
      if (d.bgKind == 0 || d.bgKind == 1) ...[
        const SectionLabel('اللون'),
        ColorRow(selected: d.bgColor1, onPick: (c) => set((x) => x.bgColor1 = c)),
      ],
      if (d.bgKind == 1) ...[
        const SectionLabel('اللون الثاني'),
        ColorRow(selected: d.bgColor2, onPick: (c) => set((x) => x.bgColor2 = c)),
        SliderRow(
          label: 'الزاوية',
          value: d.bgAngle,
          min: 0,
          max: 360,
          onStart: () => bloc.add(const CheckpointRequested()),
          onChanged: (v) => bloc.add(DocMutated((x) => x.bgAngle = v)),
          display: (v) => '${v.round()}°',
        ),
      ],
      const SectionLabel('مقاس التصميم'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _docSizes)
            ActionChip(
              label: Text(s.$1, style: const TextStyle(fontSize: 12)),
              backgroundColor: (d.w == s.$2 && d.h == s.$3) ? AppColors.accent.withValues(alpha: 0.35) : AppColors.panel2,
              side: BorderSide.none,
              onPressed: () => bloc.add(DocMutated((x) {
                // نعيد توسيط العناصر عند تغيير المقاس
                final kx = s.$2 / x.w, ky = s.$3 / x.h;
                for (final l in x.layers) {
                  l.x *= kx;
                  l.y *= ky;
                }
                x.w = s.$2;
                x.h = s.$3;
              }, commit: true)),
            ),
        ],
      ),
    ];
  }

  // ───────────── الطبقات ─────────────

  static IconData _layerIcon(Layer l) => switch (l.type) {
        LayerType.text => Icons.title,
        LayerType.image => Icons.image_outlined,
        LayerType.shape => Icons.category_outlined,
      };

  static String _layerLabel(Layer l) {
    switch (l.type) {
      case LayerType.text:
        final t = l.text.trim().replaceAll('\n', ' ');
        return t.isEmpty ? 'نص' : (t.length > 22 ? '${t.substring(0, 22)}…' : t);
      case LayerType.image:
        return 'صورة';
      case LayerType.shape:
        return 'شكل';
    }
  }

  List<Widget> _layersSection(BuildContext context, CanvasState st) {
    final layers = st.doc.layers;
    if (layers.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('لا توجد طبقات بعد', style: TextStyle(color: AppColors.muted))),
        ),
      ];
    }
    final bloc = context.read<CanvasBloc>();
    // القائمة تعرض الأعلى أولاً؛ نحول الفهارس إلى فهارس فعلية
    return [
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        buildDefaultDragHandles: true,
        itemCount: layers.length,
        onReorder: (oldI, newI) {
          if (newI > oldI) newI -= 1;
          final n = layers.length;
          bloc.add(LayerReordered(n - 1 - oldI, n - 1 - newI));
        },
        itemBuilder: (context, i) {
          final l = layers[layers.length - 1 - i];
          final sel = l.id == st.selectedId;
          return Container(
            key: ValueKey(l.id),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent.withValues(alpha: 0.22) : AppColors.panel2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              dense: true,
              onTap: () => bloc.add(LayerSelected(l.id)),
              leading: Icon(_layerIcon(l), size: 20),
              title: Text(_layerLabel(l), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(l.hidden ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => bloc.add(LayerMutated((x) => x.hidden = !x.hidden, id: l.id, commit: true)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(l.locked ? Icons.lock : Icons.lock_open, size: 18),
                    onPressed: () => bloc.add(LayerMutated((x) => x.locked = !x.locked, id: l.id, commit: true)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }
}

// ───────────────────────── عناصر مساعدة ─────────────────────────

/// قسم قابل للطي داخل المحرر الموحّد. المحتوى لا يُبنى إلا عند فتح القسم.
class _Section extends StatelessWidget {
  const _Section({super.key, required this.icon, required this.title, required this.open, required this.onTap, required this.builder});
  final IconData icon;
  final String title;
  final bool open;
  final VoidCallback onTap;
  final List<Widget> Function() builder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Row(
              children: [
                Icon(icon, size: 20, color: open ? AppColors.accent : AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: open ? AppColors.accent : null),
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: builder()),
          ),
        const Divider(height: 1, color: Colors.white10),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ]),
        ),
      );
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
