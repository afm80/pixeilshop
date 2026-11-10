import 'package:flutter/material.dart';

import '../../core/utils/ui_helpers.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/ui/editor_page.dart';
import '../poster_builder/ui/editor_shell.dart' show DotsPainter;

const double kMaxSide = 1536;
const _yellow = Color(0xFFFFC400);

// الترتيب من اليسار لليمين كما في بوستر شوب (بدون «قوالب»)
const _ratios = <(String, double, double)>[
  ('9/16', 9, 16),
  ('3/4', 3, 4),
  ('2/3', 2, 3),
  ('1/2', 1, 2),
  ('1/1', 1, 1),
];
const int _custom = 5; // تحكم كامل

List<int> _buildPalette() {
  Color hsv(double h, double s, double v) => HSVColor.fromAHSV(1, h % 360, s, v).toColor();
  final out = <Color>[const Color(0xFF000000), const Color(0xFFFFFFFF)];
  for (var i = 0; i < 10; i++) {
    out.add(hsv(i * 27.0, 1, 1)); // أحمر → بنفسجي
  }
  for (var i = 0; i < 12; i++) {
    out.add(hsv(235 - i * 14.0, 1, 1)); // أزرق → أخضر مصفر
  }
  for (var i = 0; i < 6; i++) {
    out.add(hsv(62 - i * 9.0, 1, 0.95 - i * 0.1)); // أصفر → برتقالي → بني
  }
  for (var i = 0; i < 6; i++) {
    out.add(hsv(345 - i * 55.0, .75, .85)); // ألوان مخففة
  }
  for (var i = 0; i < 12; i++) {
    out.add(hsv(i * 30.0, .45, .95)); // باستيل
  }
  for (var i = 0; i < 12; i++) {
    out.add(hsv(i * 30.0, .8, .45)); // داكنة
  }
  for (var i = 0; i < 12; i++) {
    final g = (i * 23).clamp(0, 255);
    out.add(Color.fromARGB(255, g, g, g));
  }
  return [for (final c in out) c.toARGB32()];
}

/// شاشة إنشاء تصميم على نمط بوستر شوب: [colored] = خلفية ملونة، وإلا تصميم فارغ (شفاف).
class NewDesignPage extends StatefulWidget {
  const NewDesignPage({super.key, required this.colored});
  final bool colored;

  @override
  State<NewDesignPage> createState() => _NewDesignPageState();
}

class _NewDesignPageState extends State<NewDesignPage> {
  final _w = TextEditingController(text: '576');
  final _h = TextEditingController(text: '1024');
  final _pal = _buildPalette();
  int _color = 0xFFFFFFFF;
  int _ratio = 0;

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) => (double.tryParse(c.text.replaceAll(',', '.')) ?? 1024).clamp(100, kMaxSide).toDouble();

  void _setRatio(int i) {
    if (i == _custom) {
      setState(() => _ratio = i);
      return;
    }
    if (i == _ratio) {
      // الضغط على النسبة المحددة مرة ثانية يدوّر الشكل
      final w = _w.text, h = _h.text;
      setState(() {
        _w.text = h;
        _h.text = w;
      });
      return;
    }
    final r = _ratios[i];
    final h = _val(_h);
    var w = (h * r.$2 / r.$3).roundToDouble();
    var hh = h;
    if (w > kMaxSide) {
      w = kMaxSide;
      hh = (w * r.$3 / r.$2).roundToDouble();
    }
    setState(() {
      _ratio = i;
      _w.text = w.round().toString();
      _h.text = hh.round().toString();
    });
  }

  void _create() {
    final w = _val(_w), h = _val(_h);
    final d = Doc.blank(name: widget.colored ? 'خلفية ملونة' : 'تصميم فارغ', w: w, h: h);
    if (widget.colored) {
      d.bgKind = 0;
      d.bgColor1 = _color;
    } else {
      d.bgKind = 3;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EditorPage(doc: d)));
  }

  Widget _field(String label, TextEditingController c) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            height: 44,
            color: const Color(0xFF212121),
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() => _ratio = _custom),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _yellow)),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ]),
      );

  Widget _ratioItem(int i) {
    final sel = _ratio == i;
    final label = i == _custom ? 'تحكم كامل' : _ratios[i].$1;
    return InkWell(
      onTap: () => _setRatio(i),
      child: Container(
        width: i == _custom ? 74 : 52,
        height: 48,
        color: sel ? _yellow : Colors.transparent,
        alignment: Alignment.center,
        child: Stack(alignment: Alignment.center, children: [
          if (sel && i != _custom) const Icon(Icons.rotate_left, size: 44, color: Color(0x66000000)),
          Text(label, style: TextStyle(fontSize: 13, color: sel ? Colors.black : _yellow)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _val(_w), h = _val(_h);
    final ar = (w / h).clamp(0.2, 5.0);
    return Scaffold(
      backgroundColor: const Color(0xFF272727),
      body: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: DotsPainter())),
        SafeArea(
          child: Column(children: [
            Container(
              height: 56,
              color: const Color(0xFF252525),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: _yellow, size: 28)),
                  Text(widget.colored ? 'خلفية ملونة' : 'تصميم فارغ', style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: _create, icon: const Icon(Icons.check, color: _yellow, size: 32)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [_field('العرض', _w), const SizedBox(width: 12), _field('الطول', _h)]),
              ),
            ),
            const SizedBox(height: 14),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(children: [for (var i = 0; i <= _custom; i++) _ratioItem(i)]),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                var pw = box.maxWidth - 80, ph = pw / ar;
                if (ph > box.maxHeight - 30) {
                  ph = box.maxHeight - 30;
                  pw = ph * ar;
                }
                return Center(
                  child: Container(
                    width: pw,
                    height: ph,
                    decoration: BoxDecoration(
                      color: widget.colored ? Color(_color) : const Color(0xFFEDEDED),
                      border: Border.all(color: _yellow, width: 1),
                    ),
                    child: Center(
                      child: Container(
                        height: 22,
                        width: double.infinity,
                        color: const Color(0xFF555555),
                        alignment: Alignment.center,
                        child: const Text('معاينة', style: TextStyle(color: _yellow, fontSize: 13)),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (widget.colored) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('ملاحظة: أقصى طول وعرض هو 1536 بكسل.', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ),
              SizedBox(
                height: 4 * 46.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 12, mainAxisExtent: 46),
                      itemCount: _pal.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return InkWell(
                            onTap: () async {
                              final c = await showColorPicker(context, Color(_color));
                              if (c != null) setState(() => _color = c.toARGB32());
                            },
                            child: Container(
                              color: Colors.white,
                              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.palette_outlined, color: Colors.black87, size: 22),
                                Text('المزيد', style: TextStyle(color: Colors.black87, fontSize: 9)),
                              ]),
                            ),
                          );
                        }
                        final c = _pal[i - 1];
                        return GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(c),
                              border: _color == c ? Border.all(color: _yellow, width: 2.5) : Border.all(color: Colors.black12, width: .5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text('ملاحظة: أقصى طول وعرض هو 1536 بكسل.', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ),
          ]),
        ),
      ]),
    );
  }
}
