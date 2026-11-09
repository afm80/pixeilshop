import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/font_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/blend_modes.dart';
import '../../../core/utils/ui_helpers.dart';
import '../model/adjust.dart';
import '../model/doc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';
import 'editor_panel.dart';

const kYellow = Color(0xFFFFC400);

/// سياق مشترك بين شاشات الأدوات.
class ToolCtx {
  ToolCtx({
    required this.context,
    required this.layer,
    required this.doc,
    required this.mut,
    required this.mutDoc,
    required this.ec,
    required this.images,
    required this.addText,
    required this.addShape,
    required this.addImage,
    required this.onEditText,
  });
  final BuildContext context;
  final Layer? layer;
  final Doc doc;
  final void Function(void Function(Layer)) mut;
  final void Function(void Function(Doc)) mutDoc;
  final EditorController ec;
  final ImageStore images;
  final Future<void> Function(String text, {String? font, double? fontSize, double? width}) addText;
  final void Function(ShapeKind) addShape;
  final Future<void> Function(String path, int w, int h) addImage;
  final VoidCallback onEditText;
}

/// ارتفاع منطقة الأداة السفلية.
double toolHeight(String t) {
  switch (t) {
    case 'grad':
      return 118;
    case 'pattern':
      return 118;
    case 'border':
    case 'corners':
    case 'opacity':
    case 'fsize':
    case 'lh':
      return 118;
    case 'filters':
    case 'dfilters':
      return 124;
    case 'color':
    case 'bgcolor':
      return 118;
    case 'shadow':
      return 190;
    case 'depth':
      return 190;
    case 'blend':
    case 'curve':
    case 'skew':
    case 'effects':
      return 170;
    case 'brush':
      return 250;
    case 'stickers':
    case 'saved':
      return 300;
    default:
      return 300;
  }
}

/// أزرار الشريط العلوي الإضافية لكل أداة (غير ✕ و ✓).
List<Widget> toolExtras(String t, ToolCtx c) {
  switch (t) {
    case 'filters':
    case 'dfilters':
      return [
        IconButton(
          onPressed: () {
            if (t == 'filters') {
              c.mut((l) => l.adj.reset());
            } else {
              c.mutDoc((d) => d.adjust.reset());
            }
          },
          icon: const Icon(Icons.restart_alt, color: kYellow, size: 28),
        ),
      ];
    case 'border':
      return [
        IconButton(
          onPressed: () => c.mut((l) => l.dashed = !l.dashed),
          icon: Icon(Icons.settings_outlined, color: c.layer?.dashed == true ? Colors.white : kYellow, size: 28),
        ),
      ];
    default:
      return const [];
  }
}

// ───────────────────────── عناصر مشتركة ─────────────────────────

class StepSlider extends StatelessWidget {
  const StepSlider({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.digits = 0, this.shown, this.step});
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final int digits;
  final double? shown;
  final double? step;

  @override
  Widget build(BuildContext context) {
    final st = step ?? (max - min) / 100;
    Widget sq(IconData i, double d) => InkWell(
          onTap: () => onChanged((value + d).clamp(min, max)),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(border: Border.all(color: kYellow, width: 1.4), borderRadius: BorderRadius.circular(2)),
            child: Icon(i, size: 16, color: kYellow),
          ),
        );
    return SizedBox(
      height: 39,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          SizedBox(width: 44, child: Center(child: Text((shown ?? value).toStringAsFixed(digits), style: const TextStyle(fontSize: 12)))),
          sq(Icons.remove, -st),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 12,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white,
                thumbColor: kYellow,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0, pressedElevation: 0),
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
            ),
          ),
          sq(Icons.add, st),
          SizedBox(width: 64, child: Center(child: Text(label, style: const TextStyle(fontSize: 12)))),
        ]),
      ),
    );
  }
}

List<int> _palette() {
  final top = <int>[0xFF000000, 0xFFFFFFFF];
  final bot = <int>[0xFF7E57C2, 0xFF5C8FD6];
  for (var h = 0; h < 360; h += 18) {
    top.add(HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor().toARGB32());
    bot.add(HSVColor.fromAHSV(1, (h + 9).toDouble(), .55, .85).toColor().toARGB32());
  }
  return [for (var i = 0; i < top.length; i++) ...[top[i], bot[i]]];
}

/// شريط الألوان: تفريغ / المزيد / القطارة + شبكة ألوان بصفين.
class ColorStrip extends StatelessWidget {
  const ColorStrip({super.key, required this.ec, required this.onPick, this.onClear, this.current});
  final EditorController ec;
  final ValueChanged<int> onPick;
  final VoidCallback? onClear;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final cols = _palette();
    Widget btn(IconData i, String t, VoidCallback f) => InkWell(
          onTap: f,
          child: Container(
            width: 50,
            height: 58,
            color: const Color(0xFF303030),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, color: kYellow, size: 24),
              Text(t, style: const TextStyle(fontSize: 10)),
            ]),
          ),
        );
    return SizedBox(
      height: 58,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          btn(Icons.close, 'تفريغ', () => onClear?.call()),
          btn(Icons.palette_outlined, 'المزيد', () async {
            final c = await showColorPicker(context, Color(current ?? 0xFFFFFFFF));
            if (c != null) onPick(c.toARGB32());
          }),
          btn(Icons.colorize, 'القطارة', () => ec.startPicker(onPick)),
          Expanded(
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 29),
              itemCount: cols.length,
              itemBuilder: (_, i) => GestureDetector(onTap: () => onPick(cols[i]), child: Container(color: Color(cols[i]))),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── محتوى الأدوات ─────────────────────────

/// يعيد محتوى الأداة، أو null إن لم تكن أداة جديدة (تُستخدم اللوحة القديمة).
Widget? buildToolBody(String t, ToolCtx c) {
  final l = c.layer;
  switch (t) {
    case 'border':
      if (l == null) return null;
      return Column(children: [
        StepSlider(label: 'العرض', value: l.strokeW, min: 0, max: 60, onChanged: (v) => c.mut((x) => x.strokeW = v)),
        ColorStrip(ec: c.ec, current: l.strokeColor, onPick: (v) => c.mut((x) {
              x.strokeColor = v;
              if (x.strokeW == 0) x.strokeW = 6;
            }), onClear: () => c.mut((x) => x.strokeW = 0)),
      ]);
    case 'shadow':
      if (l == null) return null;
      final dist = math.sqrt(l.shDx * l.shDx + l.shDy * l.shDy);
      var ang = math.atan2(l.shDy, l.shDx) * 180 / math.pi;
      if (ang < 0) ang += 360;
      void setPolar(double a, double d) => c.mut((x) {
            x.shOn = true;
            x.shDx = math.cos(a * math.pi / 180) * d;
            x.shDy = math.sin(a * math.pi / 180) * d;
          });
      return SingleChildScrollView(
        child: Column(children: [
          ColorStrip(ec: c.ec, current: l.shColor, onPick: (v) => c.mut((x) {
                x.shOn = true;
                x.shColor = v;
              }), onClear: () => c.mut((x) => x.shOn = false)),
          StepSlider(label: 'الزاوية', value: ang, min: 0, max: 360, onChanged: (v) => setPolar(v, dist)),
          StepSlider(label: 'المسافة', value: dist, min: 0, max: 100, onChanged: (v) => setPolar(ang, v)),
          StepSlider(label: 'تشويش', value: l.shBlur, min: 0, max: 60, digits: 1, onChanged: (v) => c.mut((x) {
                x.shOn = true;
                x.shBlur = v;
              })),
          StepSlider(label: 'الشفافية', value: l.shOpacity, min: 0, max: 1, digits: 2, onChanged: (v) => c.mut((x) {
                x.shOn = true;
                x.shOpacity = v;
              })),
        ]),
      );
    case 'corners':
      if (l == null) return null;
      return StepSlider(label: 'الزوايا', value: l.cornerRadius, min: 0, max: 200, onChanged: (v) => c.mut((x) => x.cornerRadius = v));
    case 'opacity':
      if (l == null) return null;
      return StepSlider(label: 'الشفافية', value: l.opacity, min: 0, max: 1, digits: 2, onChanged: (v) => c.mut((x) => x.opacity = v));
    case 'fsize':
      if (l == null) return null;
      return StepSlider(label: 'الحجم', value: l.fontSize, min: 8, max: 400, onChanged: (v) => c.mut((x) => x.fontSize = v));
    case 'lh':
      if (l == null) return null;
      return StepSlider(label: 'ارتفاع السطر', value: l.lineHeight, min: 0.6, max: 3, digits: 2, onChanged: (v) => c.mut((x) => x.lineHeight = v));
    case 'filters':
      if (l == null) return null;
      return _adjustSliders(l.adj, (f) => c.mut((x) => f(x.adj)));
    case 'dfilters':
      return _adjustSliders(c.doc.adjust, (f) => c.mutDoc((d) => f(d.adjust)));
    case 'color':
      if (l == null) return null;
      return Column(children: [
        ColorStrip(ec: c.ec, current: l.color, onPick: (v) => c.mut((x) {
              x.color = v;
              x.fillKind = 0;
            })),
      ]);
    case 'bgcolor':
      return Column(children: [
        ColorStrip(ec: c.ec, current: c.doc.bgColor1, onPick: (v) => c.mutDoc((d) {
              d.bgKind = 0;
              d.bgColor1 = v;
            })),
      ]);
    case 'blend':
      if (l == null) return null;
      return SingleChildScrollView(child: Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < kBlends.length; i++)
            ChoiceChip(label: Text(kBlends[i].label), selected: l.blend == i, onSelected: (_) => c.mut((x) => x.blend = i)),
        ]),
      ));
    case 'curve':
      if (l == null) return null;
      return Column(children: [
        StepSlider(label: 'تقويس', value: l.curve, min: -100, max: 100, onChanged: (v) => c.mut((x) => x.curve = v)),
        StepSlider(label: 'تباعد الحروف', value: l.letterSpacing, min: -10, max: 60, digits: 1, onChanged: (v) => c.mut((x) => x.letterSpacing = v)),
      ]);
    case 'skew':
      if (l == null) return null;
      return Column(children: [
        StepSlider(label: 'أفقي', value: l.skewX, min: -60, max: 60, onChanged: (v) => c.mut((x) => x.skewX = v)),
        StepSlider(label: 'عمودي', value: l.skewY, min: -60, max: 60, onChanged: (v) => c.mut((x) => x.skewY = v)),
      ]);
    case 'depth':
      if (l == null) return null;
      return SingleChildScrollView(
        child: Column(children: [
          ColorStrip(ec: c.ec, current: l.depthColor, onPick: (v) => c.mut((x) {
                x.depthOn = true;
                x.depthColor = v;
              }), onClear: () => c.mut((x) => x.depthOn = false)),
          StepSlider(label: 'العمق', value: l.depthLen, min: 0, max: 100, onChanged: (v) => c.mut((x) {
                x.depthOn = true;
                x.depthLen = v;
              })),
          StepSlider(label: 'الزاوية', value: l.depthAngle, min: 0, max: 360, onChanged: (v) => c.mut((x) {
                x.depthOn = true;
                x.depthAngle = v;
              })),
        ]),
      );
    case 'effects':
      if (l == null) return null;
      return Column(children: [
        StepSlider(label: 'الانعكاس', value: l.reflOn ? l.reflOpacity : 0, min: 0, max: 1, digits: 2, onChanged: (v) => c.mut((x) {
              x.reflOn = v > 0;
              x.reflOpacity = v;
            })),
        StepSlider(label: 'المسافة', value: l.reflGap, min: 0, max: 80, onChanged: (v) => c.mut((x) => x.reflGap = v)),
      ]);
    case 'hl':
      if (l == null) return null;
      return ColorStrip(ec: c.ec, current: l.hlColor, onPick: (v) => c.mut((x) {
            x.hlOn = true;
            x.hlColor = v;
          }), onClear: () => c.mut((x) => x.hlOn = false));
    case 'grad':
      if (l == null) return null;
      return _Grad(c: c, l: l);
    case 'pattern':
      if (l == null) return null;
      return Column(children: [
        SizedBox(
          height: 46,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text(const ['خطوط', 'نقاط', 'شبكة', 'شطرنج', 'مائل'][i]),
                    selected: l.fillKind == 3 && l.fillPattern == i,
                    onSelected: (_) => c.mut((x) {
                      x.fillKind = 3;
                      x.fillPattern = i;
                    }),
                  ),
                ),
            ]),
          ),
        ),
        ColorStrip(ec: c.ec, current: l.grad1, onPick: (v) => c.mut((x) {
              x.fillKind = 3;
              x.grad1 = v;
            })),
      ]);
    case 'brush':
      return _Brush(c: c);
    case 'stickers':
      return _Stickers(c: c);
    case 'saved':
      return _Saved(c: c);
  }
  return null;
}

Widget _adjustSliders(Adjust a, void Function(void Function(Adjust)) set) {
  Widget row(String label, double v, double min, double max, void Function(Adjust, double) f, {bool plus1 = false}) => StepSlider(
        label: label,
        value: v,
        min: min,
        max: max,
        shown: plus1 ? (1 + v) * 100 : v * (max > 1 ? 1 : 100),
        onChanged: (n) => set((x) => f(x, n)),
      );
  return ListView(
    padding: EdgeInsets.zero,
    children: [
      row('لمعان', a.brightness, -1, 1, (x, v) => x.brightness = v, plus1: true),
      row('تباين', a.contrast, -1, 1, (x, v) => x.contrast = v, plus1: true),
      row('تشبع', a.saturation, -1, 1, (x, v) => x.saturation = v, plus1: true),
      row('حرارة', a.temperature, -1, 1, (x, v) => x.temperature = v),
      row('تلوين', a.tint, -1, 1, (x, v) => x.tint = v),
      row('بهتان', a.fade, 0, 1, (x, v) => x.fade = v),
      row('درجة اللون', a.hue, -180, 180, (x, v) => x.hue = v),
      row('تظليل الحواف', a.vignette, 0, 1, (x, v) => x.vignette = v),
    ],
  );
}

class _Brush extends StatelessWidget {
  const _Brush({required this.c});
  final ToolCtx c;
  @override
  Widget build(BuildContext context) {
    final ec = c.ec;
    return ListenableBuilder(
      listenable: ec,
      builder: (context, _) => SingleChildScrollView(
        child: Column(children: [
          ColorStrip(ec: ec, current: ec.brushColor, onPick: (v) => ec.update(() => ec.brushColor = v)),
          StepSlider(label: 'السمك', value: ec.brushWidth, min: 2, max: 160, onChanged: (v) => ec.update(() => ec.brushWidth = v)),
          StepSlider(label: 'الشفافية', value: ec.brushOpacity, min: 0.05, max: 1, digits: 2, onChanged: (v) => ec.update(() => ec.brushOpacity = v)),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ChoiceChip(label: const Text('ممحاة'), selected: ec.brushErase, onSelected: (_) => ec.update(() => ec.brushErase = !ec.brushErase)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('متقطع'), selected: ec.brushDashed, onSelected: (_) => ec.update(() => ec.brushDashed = !ec.brushDashed)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stickers extends StatelessWidget {
  const _Stickers({required this.c});
  final ToolCtx c;
  @override
  Widget build(BuildContext context) {
    final w = c.doc.w;
    Widget cell(Widget child, VoidCallback f) => InkWell(onTap: f, child: Container(width: 52, height: 52, alignment: Alignment.center, color: const Color(0xFF303030), child: child));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in kStickerList)
          cell(Text(e, style: const TextStyle(fontSize: 28)), () => c.addText(e, fontSize: w * 0.2, width: w * 0.4)),
        for (final ic in kIconList)
          cell(Icon(ic, color: kYellow, size: 28), () => c.addText(String.fromCharCode(ic.codePoint), font: FontService.iconFont, fontSize: w * 0.2, width: w * 0.26)),
      ]),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.c});
  final ToolCtx c;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectMeta>>(
      future: StorageService.list(),
      builder: (context, snap) {
        final items = (snap.data ?? const <ProjectMeta>[]).where((m) => m.thumbPath != null).toList();
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (items.isEmpty) return const Center(child: Text('لا توجد تصاميم محفوظة'));
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 110, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final m = items[i];
            return InkWell(onTap: () => c.addImage(m.thumbPath!, m.w.round(), m.h.round()), child: Image.file(File(m.thumbPath!), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()));
          },
        );
      },
    );
  }
}

const List<List<int>> _gradPresets = [
  [0xFFF8CDD3, 0xFFE57F8E],
  [0xFF4FC3F7, 0xFF26C6DA],
  [0xFFFFE082, 0xFFFF8A65],
  [0xFF263238, 0xFF455A64],
  [0xFFEC407A, 0xFF5C6BC0],
  [0xFF42A5F5, 0xFF7E57C2],
  [0xFF8B6CFF, 0xFF4527A0],
  [0xFFA5D6A7, 0xFF26A69A],
  [0xFFF06292, 0xFFBA68C8],
  [0xFF80DEEA, 0xFFCE93D8],
  [0xFF311B92, 0xFFB71C1C],
  [0xFFFFB300, 0xFFFF3D00],
];

class _Grad extends StatelessWidget {
  const _Grad({required this.c, required this.l});
  final ToolCtx c;
  final Layer l;
  @override
  Widget build(BuildContext context) {
    final radial = l.fillKind == 2;
    Widget box(Widget child, VoidCallback f) => InkWell(onTap: f, child: Container(height: 42, color: const Color(0xFF303030), padding: const EdgeInsets.symmetric(horizontal: 10), child: Center(child: child)));
    return Column(children: [
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          box(Row(children: [const Icon(Icons.remove, color: kYellow, size: 18), Text(' ${l.gradAngle.round()} ', style: const TextStyle(fontSize: 12)), const Icon(Icons.add, color: kYellow, size: 18)]), () {}),
          const SizedBox(width: 6),
          box(Text(radial ? 'دائري' : 'خطي', style: const TextStyle(color: kYellow, fontSize: 13)), () => c.mut((x) => x.fillKind = radial ? 1 : 2)),
        ]),
      ),
      StepSlider(label: 'الزاوية', value: l.gradAngle, min: 0, max: 360, onChanged: (v) => c.mut((x) {
            if (!x.gradOn) x.fillKind = 1;
            x.gradAngle = v;
          })),
      SizedBox(
        height: 44,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final g in _gradPresets)
              GestureDetector(
                onTap: () => c.mut((x) {
                  x.fillKind = radial ? 2 : 1;
                  x.grad1 = g[0];
                  x.grad2 = g[1];
                }),
                child: Container(width: 52, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(g[0]), Color(g[1])]))),
              ),
          ]),
        ),
      ),
    ]);
  }
}
