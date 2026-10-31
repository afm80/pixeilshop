import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../core/services/font_service.dart';
import '../../../core/services/image_edit_service.dart';
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
import 'crop_dialog.dart';
import 'font_picker.dart';

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

/// أيقونات قابلة للتعديل (لون/تدرج/ظل/حد/حجم) — تُرسم من خط Material Icons.
const _icons = <IconData>[
  Icons.favorite, Icons.star, Icons.home, Icons.person, Icons.phone, Icons.email, //
  Icons.location_on, Icons.shopping_cart, Icons.shopping_bag, Icons.local_offer, Icons.percent, Icons.verified,
  Icons.check_circle, Icons.cancel, Icons.info, Icons.warning, Icons.thumb_up, Icons.emoji_events,
  Icons.workspace_premium, Icons.diamond, Icons.local_fire_department, Icons.bolt, Icons.rocket_launch, Icons.lightbulb,
  Icons.wifi, Icons.language, Icons.public, Icons.share, Icons.camera_alt, Icons.photo,
  Icons.music_note, Icons.movie, Icons.sports_soccer, Icons.restaurant, Icons.local_cafe, Icons.cake,
  Icons.directions_car, Icons.flight, Icons.school, Icons.work, Icons.build, Icons.settings,
  Icons.search, Icons.menu, Icons.arrow_forward, Icons.arrow_back, Icons.arrow_upward, Icons.arrow_downward,
  Icons.play_arrow, Icons.pause, Icons.chat_bubble, Icons.notifications, Icons.lock, Icons.key,
  Icons.wb_sunny, Icons.nightlight, Icons.cloud, Icons.water_drop, Icons.eco, Icons.pets,
];

const _shapes = <(String, ShapeKind, IconData)>[
  ('مستطيل', ShapeKind.rect, Icons.crop_square),
  ('دائرة', ShapeKind.circle, Icons.circle_outlined),
  ('مثلث', ShapeKind.triangle, Icons.change_history),
  ('نجمة', ShapeKind.star, Icons.star_border),
  ('معين', ShapeKind.diamond, Icons.diamond_outlined),
  ('مخروط', ShapeKind.cone, Icons.filter_alt_outlined),
  ('خماسي', ShapeKind.pentagon, Icons.pentagon_outlined),
  ('سداسي', ShapeKind.hexagon, Icons.hexagon_outlined),
  ('سباعي', ShapeKind.heptagon, Icons.stop_circle_outlined),
  ('ثماني', ShapeKind.octagon, Icons.stop_outlined),
  ('تساعي', ShapeKind.nonagon, Icons.circle_outlined),
  ('عشاري', ShapeKind.decagon, Icons.radio_button_unchecked),
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

const _fillKinds = <(String, int)>[
  ('لون', 0),
  ('تدرج خطي', 1),
  ('تدرج دائري', 2),
  ('نقشة', 3),
  ('صورة', 4),
];

const _patterns = <String>['خطوط', 'نقاط', 'شبكة', 'شطرنج', 'مائل'];

typedef _Setter = void Function(void Function(Layer));

// ───────────────────────── اللوحة الموحدة ─────────────────────────

class EditorPanel extends StatefulWidget {
  const EditorPanel({super.key, required this.controller, required this.images, required this.onEditNewText, this.only, this.part});

  /// عند تحديده يُعرض محتوى هذا القسم فقط ('layer' | 'add' | 'color' | 'bg' | 'layers') بدون ترويسة.
  final String? only;

  /// مع only='layer': جزء واحد من خصائص العنصر (color/border/shadow/corners/blend/font/effects/pos).
  final String? part;
  final EditorController controller;
  final ImageStore images;
  final VoidCallback onEditNewText;

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  bool _wholeDoc = false;
  bool _busy = false; // خبز صورة (قص/تدوير) جارٍ
  double _nudge = 1; // خطوة التحريك بالبكسل

  EditorController get ec => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ec,
      builder: (context, _) => BlocBuilder<CanvasBloc, CanvasState>(
        builder: (context, st) {
          final sel = st.selected;
          final only = widget.only;
          if (only != null) {
            final List<Widget> kids;
            switch (only) {
              case 'layer':
                kids = sel == null
                    ? [_noSelection()]
                    : (widget.part == null ? _layerSection(context, sel) : _layerPart(context, sel, widget.part!));
                break;
              case 'add':
                kids = _addSection(context);
                break;
              case 'color':
                kids = _colorSection(context, st);
                break;
              case 'bg':
                kids = _backgroundSection(context, st);
                break;
              case 'layers':
                kids = _layersSection(context, st);
                break;
              default:
                kids = const [];
            }
            return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 16), children: kids);
          }
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

  // ───────────── مساعدات ─────────────

  /// صف ألوان مع قطّارة تلتقط اللون من التصميم نفسه.
  Widget _colors(int selected, void Function(int) onPick) =>
      ColorRow(selected: selected, onPick: onPick, onEyedropper: () => ec.startPicker(onPick));

  Widget _switchRow(String label, bool v, ValueChanged<bool> on) => Row(
        children: [
          Switch(value: v, onChanged: on),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        ],
      );

  Widget _noSelection() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('اضغط على أي عنصر في التصميم لتعديل خصائصه', style: TextStyle(color: AppColors.muted)),
      );

  Future<String?> _pickImagePath() async {
    final m = await MediaService.pick();
    if (m == null) return null;
    await widget.images.ensure(m.path);
    return m.path;
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
          _Big(
            icon: Icons.brush,
            label: ec.brushOn ? 'إيقاف الفرشاة' : 'فرشاة',
            on: ec.brushOn,
            onTap: () => ec.update(() {
              ec.brushOn = !ec.brushOn;
              if (ec.brushOn) {
                ec.eraserLayerId = null;
                ec.picker = null;
              }
            }),
          ),
        ],
      ),
      if (ec.brushOn) ..._brushControls(bloc),
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
      const SectionLabel('أيقونات (قابلة للتلوين والتعديل)'),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final ic in _icons)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final w = bloc.state.doc.w;
                bloc.add(TextLayerAdded(
                  String.fromCharCode(ic.codePoint),
                  font: FontService.iconFont,
                  fontSize: w * 0.2,
                  width: w * 0.26,
                  bold: false,
                ));
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10)),
                child: Icon(ic, size: 24, color: AppColors.accent2),
              ),
            ),
        ],
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

  List<Widget> _brushControls(CanvasBloc bloc) {
    return [
      const SectionLabel('إعدادات الفرشاة'),
      _colors(ec.brushColor, (c) => ec.update(() => ec.brushColor = c)),
      SliderRow(
        label: 'السمك',
        value: ec.brushWidth,
        min: 2,
        max: 160,
        onChanged: (v) => ec.update(() => ec.brushWidth = v),
        display: (v) => v.round().toString(),
      ),
      SliderRow(
        label: 'الشفافية',
        value: ec.brushOpacity,
        min: 0.05,
        max: 1,
        onChanged: (v) => ec.update(() => ec.brushOpacity = v),
        display: (v) => '${(v * 100).round()}%',
      ),
      Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          _switchRow('خط متقطع', ec.brushDashed, (v) => ec.update(() => ec.brushDashed = v)),
          _switchRow('ممحاة (على طبقة الرسم المحددة)', ec.brushErase, (v) => ec.update(() => ec.brushErase = v)),
        ],
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => bloc.add(const LayerSelected(null)),
          icon: const Icon(Icons.layers_clear_outlined, size: 18),
          label: const Text('الرسم التالي على طبقة جديدة'),
        ),
      ),
    ];
  }

  // ───────────── الطبقة المحددة ─────────────

  static double _deg(double rad) {
    var d = rad * 180 / math.pi;
    d = ((d + 180) % 360) - 180;
    return d;
  }

  bool _isIcon(Layer l) => l.type == LayerType.text && l.font == FontService.iconFont;

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
            if (l.groupId != null)
              _Act(Icons.link_off, 'فك التجميع', () {
                final ids = bloc.state.doc.layers.where((x) => x.groupId == l.groupId).map((x) => x.id).toSet();
                bloc.add(LayersGrouped(ids, group: false));
              }),
            _Act(Icons.delete_outline, 'حذف', () => bloc.add(LayerRemoved(l.id)), color: AppColors.danger),
          ],
        ),
      ),
      _nudgeRow(bloc, l),
      if (l.type == LayerType.text && !_isIcon(l)) ..._textControls(context, l, set, live, start),
      if (_isIcon(l)) ..._iconControls(context, l, set, live, start),
      if (l.type == LayerType.shape) ..._shapeControls(context, l, set, live, start),
      if (l.type == LayerType.image) ..._imageControls(context, l, set, live, start),
      if (l.type == LayerType.draw) ..._drawControls(),
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

  /// جزء واحد من خصائص الطبقة (نافذة منبثقة مستقلة لكل زر في الشريط السفلي).
  List<Widget> _layerPart(BuildContext context, Layer l, String part) {
    final bloc = context.read<CanvasBloc>();
    void set(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id, commit: true));
    void live(void Function(Layer) f) => bloc.add(LayerMutated(f, id: l.id));
    void start() => bloc.add(const CheckpointRequested());
    final isText = l.type == LayerType.text;
    switch (part) {
      case 'color':
        if (l.type == LayerType.draw) return _drawControls();
        return _fillControls(l, set, live, start, title: isText ? 'لون النص' : 'اللون');
      case 'border':
        if (l.type == LayerType.image) return _strokeControls(l, set, live, start, label: 'سمك الإطار');
        return _strokeControls(l, set, live, start, dashable: !isText, max: isText ? 30 : 40);
      case 'shadow':
        return _shadowControls(l, set, live, start);
      case 'corners':
        if (isText) {
          return [
            _switchRow('خلفية للنص', l.boxOn, (v) => set((x) => x.boxOn = v)),
            if (l.boxOn) ...[
              _colors(l.boxColor, (c) => set((x) => x.boxColor = c)),
              SliderRow(label: 'استدارة', value: l.boxRadius, min: 0, max: 100, onStart: start, onChanged: (v) => live((x) => x.boxRadius = v), display: (v) => v.round().toString()),
            ],
          ];
        }
        final mx = l.type == LayerType.image ? math.max(10.0, math.min(l.w, l.h) / 2) : 300.0;
        return [
          SliderRow(label: 'استدارة الزوايا', value: l.cornerRadius.clamp(0.0, mx).toDouble(), min: 0, max: mx, onStart: start, onChanged: (v) => live((x) => x.cornerRadius = v), display: (v) => v.round().toString()),
        ];
      case 'blend':
        return [
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (int i = 0; i < kBlends.length; i++) ChipChoice(label: kBlends[i].label, selected: l.blend == i, onTap: () => set((x) => x.blend = i)),
            ],
          ),
        ];
      case 'font':
        return [
          Row(children: [
            IconButton.filledTonal(onPressed: () => set((x) => x.bold = !x.bold), isSelected: l.bold, icon: const Icon(Icons.format_bold)),
            IconButton.filledTonal(onPressed: () => set((x) => x.italic = !x.italic), isSelected: l.italic, icon: const Icon(Icons.format_italic)),
            IconButton(onPressed: () => set((x) => x.align = 0), icon: Icon(Icons.format_align_left, color: l.align == 0 ? AppColors.accent : null)),
            IconButton(onPressed: () => set((x) => x.align = 1), icon: Icon(Icons.format_align_center, color: l.align == 1 ? AppColors.accent : null)),
            IconButton(onPressed: () => set((x) => x.align = 2), icon: Icon(Icons.format_align_right, color: l.align == 2 ? AppColors.accent : null)),
          ]),
          const SectionLabel('الخط'),
          OutlinedButton.icon(
            onPressed: () async {
              final f = await showFontPicker(context, l.font);
              if (f != null) set((x) => x.font = f);
            },
            icon: const Icon(Icons.font_download_outlined),
            label: Text('${l.font}  ·  تغيير الخط'),
          ),
          SliderRow(label: 'حجم الخط', value: l.fontSize, min: 16, max: 400, onStart: start, onChanged: (v) => live((x) => x.fontSize = v), display: (v) => v.round().toString()),
          SliderRow(label: 'عرض الصندوق', value: l.w, min: 80, max: 2400, onStart: start, onChanged: (v) => live((x) => x.w = v), display: (v) => v.round().toString()),
          SliderRow(label: 'تباعد الحروف', value: l.letterSpacing, min: -5, max: 40, onStart: start, onChanged: (v) => live((x) => x.letterSpacing = v), display: (v) => v.toStringAsFixed(0)),
          SliderRow(label: 'ارتفاع السطر', value: l.lineHeight, min: 0.8, max: 2.4, onStart: start, onChanged: (v) => live((x) => x.lineHeight = v)),
        ];
      case 'depth':
        return [
          _switchRow('تفعيل العمق', l.depthOn, (v) => set((x) => x.depthOn = v)),
          if (l.depthOn) ...[
            _colors(l.depthColor, (c) => set((x) => x.depthColor = c)),
            SliderRow(label: 'العمق', value: l.depthLen, min: 1, max: 80, onStart: start, onChanged: (v) => live((x) => x.depthLen = v), display: (v) => v.round().toString()),
            SliderRow(label: 'الزاوية', value: l.depthAngle, min: 0, max: 360, onStart: start, onChanged: (v) => live((x) => x.depthAngle = v), display: (v) => '${v.round()}°'),
          ],
        ];
      case 'skew':
        return [
          SliderRow(label: 'العرض', value: l.skewX, min: -60, max: 60, onStart: start, onChanged: (v) => live((x) => x.skewX = v), display: (v) => '${v.round()}°'),
          SliderRow(label: 'الارتفاع', value: l.skewY, min: -60, max: 60, onStart: start, onChanged: (v) => live((x) => x.skewY = v), display: (v) => '${v.round()}°'),
        ];
      case 'effects':
        return [
          _switchRow('تظليل خلف الحروف', l.hlOn, (v) => set((x) => x.hlOn = v)),
          if (l.hlOn) _colors(l.hlColor, (c) => set((x) => x.hlColor = c)),
          _switchRow('انعكاس تحت النص', l.reflOn, (v) => set((x) => x.reflOn = v)),
          if (l.reflOn) ...[
            SliderRow(label: 'قوة الانعكاس', value: l.reflOpacity, min: 0.05, max: 1, onStart: start, onChanged: (v) => live((x) => x.reflOpacity = v), display: (v) => '${(v * 100).round()}%'),
            SliderRow(label: 'المسافة', value: l.reflGap, min: -30, max: 80, onStart: start, onChanged: (v) => live((x) => x.reflGap = v), display: (v) => v.round().toString()),
          ],
        ];
      case 'image':
        return l.type == LayerType.image ? _imageControls(context, l, set, live, start) : [_noSelection()];
      case 'pos':
        return [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Act(Icons.copy_all_outlined, 'تكرار', () => bloc.add(LayerDuplicated(l.id))),
                _Act(l.locked ? Icons.lock : Icons.lock_open, l.locked ? 'مقفلة' : 'قفل', () => set((x) => x.locked = !x.locked)),
                _Act(Icons.vertical_align_top, 'للأمام', () => bloc.add(LayerZMoved(l.id, toFront: true))),
                _Act(Icons.vertical_align_bottom, 'للخلف', () => bloc.add(LayerZMoved(l.id, toBack: true))),
                _Act(Icons.delete_outline, 'حذف', () => bloc.add(LayerRemoved(l.id)), color: AppColors.danger),
              ],
            ),
          ),
          _nudgeRow(bloc, l),
        ];
    }
    return const [];
  }

  /// تحريك بالبكسل (للمجموعة كلها إن كانت الطبقة ضمن مجموعة).
  Widget _nudgeRow(CanvasBloc bloc, Layer l) {
    void move(double dx, double dy) {
      final gid = l.groupId;
      bloc.add(DocMutated((d) {
        for (final m in d.layers) {
          if (m.id == l.id || (gid != null && m.groupId == gid)) {
            m.x += dx;
            m.y += dy;
          }
        }
      }, commit: true));
    }

    Widget arrow(IconData i, double dx, double dy) =>
        IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: () => move(dx, dy), icon: Icon(i, size: 20));

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Text('تحريك', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(width: 6),
          arrow(Icons.arrow_back, -_nudge, 0),
          arrow(Icons.arrow_upward, 0, -_nudge),
          arrow(Icons.arrow_downward, 0, _nudge),
          arrow(Icons.arrow_forward, _nudge, 0),
          const SizedBox(width: 6),
          for (final s in const [1.0, 5.0, 20.0])
            ChipChoice(label: '${s.toInt()}px', selected: _nudge == s, onTap: () => setState(() => _nudge = s)),
        ],
      ),
    );
  }

  List<Widget> _shadowControls(Layer l, _Setter set, _Setter live, VoidCallback start) {
    return [
      const SectionLabel('الظل'),
      _switchRow('تفعيل الظل (يتبع شكل العنصر)', l.shOn, (v) => set((x) => x.shOn = v)),
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
        _colors(l.shColor, (c) => set((x) => x.shColor = c)),
      ],
    ];
  }

  // ───────────── التعبئة: لون / تدرج / نقشة / صورة ─────────────

  Future<void> _chooseFillKind(Layer l, int kind, _Setter set) async {
    if (kind == 4 && l.fillPath == null) {
      final p = await _pickImagePath();
      if (p == null) return;
      set((x) {
        x.fillPath = p;
        x.fillKind = 4;
      });
      return;
    }
    set((x) => x.fillKind = kind);
  }

  List<Widget> _fillControls(Layer l, _Setter set, _Setter live, VoidCallback start, {String title = 'التعبئة'}) {
    return [
      SectionLabel(title),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final k in _fillKinds) ChipChoice(label: k.$1, selected: l.fillKind == k.$2, onTap: () => _chooseFillKind(l, k.$2, set)),
          ],
        ),
      ),
      if (l.fillKind == 0)
        _colors(l.color, (c) => set((x) {
              x.color = c;
              x.fillKind = 0;
            })),
      if (l.fillKind == 1 || l.fillKind == 2) ...[
        _colors(l.grad1, (c) => set((x) => x.grad1 = c)),
        _colors(l.grad2, (c) => set((x) => x.grad2 = c)),
      ],
      if (l.fillKind == 1)
        SliderRow(
          label: 'الزاوية',
          value: l.gradAngle,
          min: 0,
          max: 360,
          onStart: start,
          onChanged: (v) => live((x) => x.gradAngle = v),
          display: (v) => '${v.round()}°',
        ),
      if (l.fillKind == 3) ...[
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < _patterns.length; i++) ChipChoice(label: _patterns[i], selected: l.fillPattern == i, onTap: () => set((x) => x.fillPattern = i)),
            ],
          ),
        ),
        SliderRow(label: 'حجم النقشة', value: l.patSize, min: 12, max: 160, onStart: start, onChanged: (v) => live((x) => x.patSize = v), display: (v) => v.round().toString()),
        _colors(l.grad1, (c) => set((x) => x.grad1 = c)),
        _colors(l.grad2, (c) => set((x) => x.grad2 = c)),
      ],
      if (l.fillKind == 4)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: () async {
              final p = await _pickImagePath();
              if (p != null) set((x) => x.fillPath = p);
            },
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(l.fillPath == null ? 'اختيار صورة التعبئة' : 'تغيير صورة التعبئة'),
          ),
        ),
    ];
  }

  List<Widget> _strokeControls(Layer l, _Setter set, _Setter live, VoidCallback start, {bool dashable = true, double max = 40, String label = 'سمك الحد'}) {
    return [
      SliderRow(label: label, value: l.strokeW, min: 0, max: max, onStart: start, onChanged: (v) => live((x) => x.strokeW = v), display: (v) => v.round().toString()),
      if (l.strokeW > 0) _colors(l.strokeColor, (c) => set((x) => x.strokeColor = c)),
      if (dashable && l.strokeW > 0) ...[
        _switchRow('حد متقطع', l.dashed, (v) => set((x) => x.dashed = v)),
        if (l.dashed) SliderRow(label: 'طول القطع', value: l.dashLen, min: 4, max: 80, onStart: start, onChanged: (v) => live((x) => x.dashLen = v), display: (v) => v.round().toString()),
      ],
    ];
  }

  // ───────────── نص ─────────────

  Future<void> _addCustomFont(_Setter set) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['ttf', 'otf']);
    final path = res?.files.single.path;
    if (path == null) return;
    final family = await FontService.addCustom(path);
    if (!mounted) return;
    if (family == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل الخط (استخدم ملف ttf أو otf)')));
      return;
    }
    set((x) => x.font = family);
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
            ChipChoice(label: 'خط من جهازك', icon: Icons.upload_file, selected: false, onTap: () => _addCustomFont(set)),
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
      ..._fillControls(l, set, live, start, title: 'لون النص'),
      const SectionLabel('حدود النص'),
      ..._strokeControls(l, set, live, start, dashable: false, max: 30),
      const SectionLabel('تظليل (Highlight)'),
      _switchRow('تظليل خلف الحروف', l.hlOn, (v) => set((x) => x.hlOn = v)),
      if (l.hlOn) _colors(l.hlColor, (c) => set((x) => x.hlColor = c)),
      const SectionLabel('انعكاس'),
      _switchRow('انعكاس تحت النص', l.reflOn, (v) => set((x) => x.reflOn = v)),
      if (l.reflOn) ...[
        SliderRow(label: 'قوة الانعكاس', value: l.reflOpacity, min: 0.05, max: 1, onStart: start, onChanged: (v) => live((x) => x.reflOpacity = v), display: (v) => '${(v * 100).round()}%'),
        SliderRow(label: 'المسافة', value: l.reflGap, min: -30, max: 80, onStart: start, onChanged: (v) => live((x) => x.reflGap = v), display: (v) => v.round().toString()),
      ],
      _switchRow('خلفية للنص', l.boxOn, (v) => set((x) => x.boxOn = v)),
      if (l.boxOn) ...[
        _colors(l.boxColor, (c) => set((x) => x.boxColor = c)),
        SliderRow(label: 'استدارة', value: l.boxRadius, min: 0, max: 100, onStart: start, onChanged: (v) => live((x) => x.boxRadius = v), display: (v) => v.round().toString()),
      ],
    ];
  }

  // ───────────── أيقونة ─────────────

  List<Widget> _iconControls(BuildContext context, Layer l, _Setter set, _Setter live, VoidCallback start) {
    return [
      SliderRow(
        label: 'حجم الأيقونة',
        value: l.fontSize,
        min: 24,
        max: 700,
        onStart: start,
        onChanged: (v) => live((x) {
          x.fontSize = v;
          x.w = v * 1.3;
        }),
        display: (v) => v.round().toString(),
      ),
      ..._fillControls(l, set, live, start, title: 'لون الأيقونة'),
      const SectionLabel('حدود'),
      ..._strokeControls(l, set, live, start, dashable: false, max: 30),
    ];
  }

  // ───────────── شكل ─────────────

  List<Widget> _shapeControls(BuildContext context, Layer l, _Setter set, _Setter live, VoidCallback start) {
    return [
      ..._fillControls(l, set, live, start, title: 'تعبئة الشكل'),
      SliderRow(label: 'العرض', value: l.w, min: 40, max: 2400, onStart: start, onChanged: (v) => live((x) => x.w = v), display: (v) => v.round().toString()),
      SliderRow(label: 'الارتفاع', value: l.h, min: 20, max: 2400, onStart: start, onChanged: (v) => live((x) => x.h = v), display: (v) => v.round().toString()),
      if (l.shape == ShapeKind.rect)
        SliderRow(label: 'استدارة الزوايا', value: l.cornerRadius, min: 0, max: 300, onStart: start, onChanged: (v) => live((x) => x.cornerRadius = v), display: (v) => v.round().toString()),
      const SectionLabel('الحدود'),
      ..._strokeControls(l, set, live, start),
    ];
  }

  // ───────────── صورة (قص / تدوير / حدود / زوايا) ─────────────

  Future<void> _rotateImage(Layer l, int turns) async {
    if (_busy || l.path == null) return;
    final bloc = context.read<CanvasBloc>();
    setState(() => _busy = true);
    try {
      final r = await ImageEditService.bake(l, quarterTurns: turns);
      await widget.images.ensure(r.path);
      if (!mounted) return;
      bloc.add(ImageBaked(l.id, r.path, l.h, l.w));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التدوير: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _imageControls(BuildContext context, Layer l, _Setter set, _Setter live, VoidCallback start) {
    final maxRadius = math.max(10.0, math.min(l.w, l.h) / 2);
    return [
      const SectionLabel('قص وتدوير'),
      if (_busy) const Padding(padding: EdgeInsets.only(bottom: 6), child: LinearProgressIndicator()),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => showCropDialog(context, l, widget.images),
            icon: const Icon(Icons.crop, size: 18),
            label: const Text('قص'),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _rotateImage(l, 3),
            icon: const Icon(Icons.rotate_left, size: 18),
            label: const Text('يسار 90°'),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _rotateImage(l, 1),
            icon: const Icon(Icons.rotate_right, size: 18),
            label: const Text('يمين 90°'),
          ),
        ],
      ),
      const SectionLabel('الحدود والزوايا'),
      SliderRow(
        label: 'استدارة الزوايا',
        value: l.cornerRadius,
        min: 0,
        max: maxRadius,
        onStart: start,
        onChanged: (v) => live((x) => x.cornerRadius = v),
        display: (v) => v.round().toString(),
      ),
      ..._strokeControls(l, set, live, start, label: 'سمك الإطار'),
      RemoverSection(layer: l, controller: ec),
      AnimeSection(layer: l),
    ];
  }

  // ───────────── رسم حر ─────────────

  List<Widget> _drawControls() {
    return [
      const SectionLabel('طبقة رسم'),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => ec.update(() {
              ec.brushOn = !ec.brushOn;
              if (ec.brushOn) {
                ec.eraserLayerId = null;
                ec.picker = null;
                ec.show('add');
              }
            }),
            icon: Icon(ec.brushOn ? Icons.stop_circle_outlined : Icons.brush, size: 18),
            label: Text(ec.brushOn ? 'إيقاف الفرشاة' : 'متابعة الرسم على هذه الطبقة'),
          ),
        ],
      ),
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
            ChipChoice(label: 'تدرج خطي', selected: d.bgKind == 1, onTap: () => set((x) => x.bgKind = 1)),
            ChipChoice(label: 'تدرج دائري', selected: d.bgKind == 4, onTap: () => set((x) => x.bgKind = 4)),
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
      if (d.bgKind == 0 || d.bgKind == 1 || d.bgKind == 4) ...[
        const SectionLabel('اللون'),
        _colors(d.bgColor1, (c) => set((x) => x.bgColor1 = c)),
      ],
      if (d.bgKind == 1 || d.bgKind == 4) ...[
        const SectionLabel('اللون الثاني'),
        _colors(d.bgColor2, (c) => set((x) => x.bgColor2 = c)),
      ],
      if (d.bgKind == 1)
        SliderRow(
          label: 'الزاوية',
          value: d.bgAngle,
          min: 0,
          max: 360,
          onStart: () => bloc.add(const CheckpointRequested()),
          onChanged: (v) => bloc.add(DocMutated((x) => x.bgAngle = v)),
          display: (v) => '${v.round()}°',
        ),
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

  // ───────────── الطبقات (ترتيب + تجميع) ─────────────

  IconData _layerIcon(Layer l) {
    if (_isIcon(l)) return Icons.category;
    return switch (l.type) {
      LayerType.text => Icons.title,
      LayerType.image => Icons.image_outlined,
      LayerType.shape => Icons.category_outlined,
      LayerType.draw => Icons.brush,
    };
  }

  String _layerLabel(Layer l) {
    if (_isIcon(l)) return 'أيقونة';
    switch (l.type) {
      case LayerType.text:
        final t = l.text.trim().replaceAll('\n', ' ');
        return t.isEmpty ? 'نص' : (t.length > 22 ? '${t.substring(0, 22)}…' : t);
      case LayerType.image:
        return 'صورة';
      case LayerType.shape:
        return 'شكل';
      case LayerType.draw:
        return 'رسم';
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
    final multi = ec.multiMode;
    // أرقام تحديد قديمة لطبقات حُذفت
    ec.multi.removeWhere((id) => st.doc.indexOf(id) < 0);

    return [
      Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChipChoice(
            label: 'تحديد متعدد',
            icon: Icons.checklist,
            selected: multi,
            onTap: () => ec.update(() {
              ec.multiMode = !ec.multiMode;
              ec.multi.clear();
            }),
          ),
          if (multi)
            FilledButton.tonalIcon(
              onPressed: ec.multi.length < 2
                  ? null
                  : () {
                      bloc.add(LayersGrouped(Set<String>.of(ec.multi)));
                      ec.update(() {
                        ec.multiMode = false;
                        ec.multi.clear();
                      });
                    },
              icon: const Icon(Icons.link, size: 18),
              label: Text('تجميع (${ec.multi.length})'),
            ),
        ],
      ),
      // القائمة تعرض الأعلى أولاً؛ نحول الفهارس إلى فهارس فعلية
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
          final checked = ec.multi.contains(l.id);
          return Container(
            key: ValueKey(l.id),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent.withValues(alpha: 0.22) : AppColors.panel2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              dense: true,
              onTap: () {
                if (multi) {
                  ec.update(() {
                    if (!ec.multi.remove(l.id)) ec.multi.add(l.id);
                  });
                } else {
                  bloc.add(LayerSelected(l.id));
                }
              },
              leading: multi
                  ? Checkbox(value: checked, onChanged: (_) => ec.update(() => checked ? ec.multi.remove(l.id) : ec.multi.add(l.id)))
                  : Icon(_layerIcon(l), size: 20),
              title: Row(
                children: [
                  Flexible(child: Text(_layerLabel(l), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (l.groupId != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.link, size: 14, color: AppColors.accent2),
                  ],
                ],
              ),
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
  const _Big({required this.icon, required this.label, required this.onTap, this.on = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: on ? AppColors.accent.withValues(alpha: 0.35) : AppColors.panel2,
            borderRadius: BorderRadius.circular(14),
          ),
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
