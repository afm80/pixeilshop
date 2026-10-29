import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'model.dart';
import 'ui.dart';

Widget _top(BuildContext c, String title, VoidCallback ok) => Container(
      height: 56, color: kPanel,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.close, color: kAccent, size: 30), onPressed: () => Navigator.pop(c)),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 17)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.check, color: kAccent, size: 30), onPressed: ok),
        ]),
      ),
    );

/// معاينة الطبقة على خلفية فاتحة
Widget _preview(Layer l, Widget Function(Layer) body) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(14), color: const Color(0xFFF2F2F2), alignment: Alignment.center,
        child: Padding(padding: const EdgeInsets.all(18), child: FittedBox(child: body(l))),
      ),
    );

Future<Color?> _pick(BuildContext context, Color c0) {
  var c = c0;
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kPanel,
      content: SingleChildScrollView(child: ColorPicker(pickerColor: c, onColorChanged: (v) => c = v, enableAlpha: false, labelTypes: const [])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: kAccent))),
        TextButton(onPressed: () => Navigator.pop(ctx, c), child: const Text('موافق', style: TextStyle(color: kAccent))),
      ],
    ),
  );
}

List<Color> _palette() {
  final top = <Color>[Colors.black, Colors.white];
  final bottom = <Color>[const Color(0xFF7E57C2), const Color(0xFF5B9BE0)];
  for (var i = 0; i < 24; i++) {
    top.add(HSVColor.fromAHSV(1, i * 15.0, 1, 1).toColor());
    bottom.add(HSVColor.fromAHSV(1, (i * 15.0 + 270) % 360, .55, 1).toColor());
  }
  final out = <Color>[];
  for (var i = 0; i < top.length; i++) { out..add(top[i])..add(bottom[i]); }
  return out;
}

Widget _btn(IconData i, String t, VoidCallback f) => InkWell(
      onTap: f,
      child: Container(
        width: 84, margin: const EdgeInsets.all(2), decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: kAccent, size: 28), const SizedBox(height: 4), Text(t, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );

/// شاشة "التعبئة": لون واحد للطبقة
class FillPage extends StatefulWidget {
  const FillPage(this.l, this.body, {super.key});
  final Layer l;
  final Widget Function(Layer) body;
  @override
  State<FillPage> createState() => _FillState();
}

class _FillState extends State<FillPage> {
  final pal = _palette();
  Layer get l => widget.l;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DotBg(
          child: SafeArea(
            child: Column(children: [
              _top(context, 'التعبئة', () => Navigator.pop(context, l)),
              _preview(l, widget.body),
              Container(
                color: kPanel, height: 96,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    _btn(Icons.close, 'تفريغ', () => setState(() { l.color = Colors.transparent; l.grad = false; })),
                    _btn(Icons.palette_outlined, 'المزيد', () async {
                      final c = await _pick(context, l.color);
                      if (c != null) setState(() { l.color = c; l.grad = false; });
                    }),
                    Expanded(
                      child: GridView.count(
                        scrollDirection: Axis.horizontal, crossAxisCount: 2,
                        children: [
                          for (final c in pal)
                            GestureDetector(onTap: () => setState(() { l.color = c; l.grad = false; }), child: Container(color: c)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

const _presets = <(int, int)>[
  (0xFF8E54E9, 0xFF4776E6), (0xFFFF512F, 0xFFDD2476), (0xFFF09819, 0xFFEDDE5D), (0xFF7FFFD4, 0xFFA8FF78),
  (0xFF8E2020, 0xFFE52D27), (0xFF0093C4, 0xFF00B4DB), (0xFFFFFFFF, 0xFFFFE9B0), (0xFFA8A860, 0xFF606060),
  (0xFF3A0F5C, 0xFFB05080), (0xFF4B3AA8, 0xFFA0B8FF), (0xFFD01515, 0xFF333333), (0xFF8888FF, 0xFF4B4BD0),
  (0xFFB06080, 0xFF3A6A90), (0xFFEE0979, 0xFFFF6A00),
];

/// شاشة "تدرج": لونان، خطي/دائري، زاوية
class GradientPage extends StatefulWidget {
  const GradientPage(this.l, this.body, {super.key});
  final Layer l;
  final Widget Function(Layer) body;
  @override
  State<GradientPage> createState() => _GradState();
}

class _GradState extends State<GradientPage> {
  Layer get l => widget.l;

  @override
  void initState() {
    super.initState();
    l.grad = true;
  }

  void angle(double d) => setState(() => l.gAngle = (l.gAngle + d) % 360);

  Future<void> options() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: kPanel,
          title: const Text('خيارات التدرج', style: TextStyle(color: kAccent, fontSize: 17)),
          content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final first in [true, false])
              GestureDetector(
                onTap: () async {
                  final c = await _pick(ctx, first ? l.g1 : l.g2);
                  if (c != null) { set(() => first ? l.g1 = c : l.g2 = c); setState(() {}); }
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 70, height: 70, color: first ? l.g1 : l.g2),
                  const SizedBox(height: 6), Text(first ? 'اللون الأول' : 'اللون الثاني', style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('موافق', style: TextStyle(color: kAccent)))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DotBg(
          child: SafeArea(
            child: Column(children: [
              _top(context, 'تدرج', () => Navigator.pop(context, l)),
              _preview(l, widget.body),
              Container(
                color: kPanel, padding: const EdgeInsets.symmetric(vertical: 6),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _btn(l.radial ? Icons.radio_button_unchecked : Icons.linear_scale, l.radial ? 'دائري' : 'خطي', () => setState(() => l.radial = !l.radial)),
                    Container(
                      width: 150, height: 66, margin: const EdgeInsets.all(2), decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('الزاوية', style: TextStyle(fontSize: 12)),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, color: kAccent), onPressed: l.radial ? null : () => angle(-15)),
                          Text('${l.gAngle.round()}'),
                          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, color: kAccent), onPressed: l.radial ? null : () => angle(15)),
                        ]),
                      ]),
                    ),
                    _btn(Icons.settings_outlined, 'خيارات', options),
                  ]),
                ),
              ),
              Container(
                color: kPanel, height: 92,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final (a, b) in _presets)
                    GestureDetector(
                      onTap: () => setState(() { l.g1 = Color(a); l.g2 = Color(b); }),
                      child: Container(
                        width: 92, margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(a), Color(b)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );
}
