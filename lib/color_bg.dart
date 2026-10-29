import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'model.dart';
import 'ui.dart';

/// شاشة "خلفية ملونة": الطول والعرض + النسبة + معاينة + شبكة ألوان
class ColorBgPage extends StatefulWidget {
  const ColorBgPage({super.key});
  @override
  State<ColorBgPage> createState() => _ColorBgState();
}

const _max = 1536;
const _ratios = <String, double?>{
  'تحكم كامل': null, '1/1': 1, '1/2': 1 / 2, '2/3': 2 / 3, '3/4': 3 / 4, '16/9': 16 / 9,
};

List<Color> _grid() {
  final l = <Color>[Colors.black, Colors.white];
  for (var i = 0; i < 10; i++) {
    l.add(HSVColor.fromAHSV(1, i * 36.0, 1, 1).toColor());
  }
  for (var r = 0; r < 3; r++) {
    for (var i = 0; i < 12; i++) {
      l.add(HSVColor.fromAHSV(1, 220 + i * 12.0 % 360, 1 - r * .2, 1 - r * .12).toColor());
    }
  }
  return l;
}

class _ColorBgState extends State<ColorBgPage> {
  final wC = TextEditingController(text: '1024'), hC = TextEditingController(text: '1024');
  String ratio = '1/1';
  Color color = Colors.white;
  final colors = _grid();

  int get w => (int.tryParse(wC.text) ?? 1024).clamp(64, _max);
  int get h => (int.tryParse(hC.text) ?? 1024).clamp(64, _max);

  void pickRatio(String k) {
    setState(() => ratio = k);
    final r = _ratios[k];
    if (r == null) return;
    var nw = w.toDouble(), nh = nw / r;
    if (nh > _max) { nh = _max.toDouble(); nw = nh * r; }
    wC.text = nw.round().toString();
    hC.text = nh.round().toString();
  }

  void more() {
    var c = color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanel,
        content: SingleChildScrollView(child: ColorPicker(pickerColor: c, onColorChanged: (v) => c = v, enableAlpha: false, labelTypes: const [])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: kAccent))),
          TextButton(onPressed: () { setState(() => color = c); Navigator.pop(ctx); }, child: const Text('موافق', style: TextStyle(color: kAccent))),
        ],
      ),
    );
  }

  Widget field(String label, TextEditingController c) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Container(
              color: kPanel,
              child: TextField(
                controller: c, textAlign: TextAlign.center, keyboardType: TextInputType.number,
                onChanged: (_) { setState(() => ratio = 'تحكم كامل'); },
                decoration: const InputDecoration(border: UnderlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ar = w / h;
    return Scaffold(
      body: DotBg(
        child: SafeArea(
          child: Column(children: [
            SubBar(title: 'خلفية ملونة', onOk: () => Navigator.pop(context, Doc(w.toDouble(), h.toDouble(), Bg(c1: color), []))),
            // الطول يمين والعرض يسار (كالأصل)
            Row(children: [field('الطول', hC), field('العرض', wC)]),
            SizedBox(
              height: 56,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final k in _ratios.keys)
                  GestureDetector(
                    onTap: () => pickRatio(k),
                    child: Container(
                      alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 18),
                      color: ratio == k ? kAccent : null,
                      child: Text(k, style: TextStyle(color: ratio == k ? Colors.black : kAccent, fontSize: 17)),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: ar,
                    child: Container(
                      decoration: BoxDecoration(color: color, border: Border.all(color: kAccent, width: .6)),
                      alignment: Alignment.center,
                      child: Container(
                        width: double.infinity, height: 38, color: const Color(0xFF4A4A4A), alignment: Alignment.center,
                        child: const Text('معاينة', style: TextStyle(color: kAccent)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Text('ملاحظة: أقصى طول وعرض هو $_max بكسل.', style: TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            SizedBox(
              height: 190,
              child: GridView.count(
                crossAxisCount: 12, padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  InkWell(
                    onTap: more,
                    child: Container(
                      color: Colors.white,
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.palette_outlined, color: Colors.black, size: 20),
                        Text('المزيد', style: TextStyle(color: Colors.black, fontSize: 9)),
                      ]),
                    ),
                  ),
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => setState(() => color = c),
                      child: Container(
                        decoration: BoxDecoration(color: c, border: color == c ? Border.all(color: kAccent, width: 2) : null),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
