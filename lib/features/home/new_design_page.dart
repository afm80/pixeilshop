import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/ui/editor_page.dart';

const double kMaxSide = 1536;

const _ratios = <(String, double, double)>[
  ('1/1', 1, 1),
  ('1/2', 1, 2),
  ('2/3', 2, 3),
  ('3/4', 3, 4),
  ('9/16', 9, 16),
  ('16/9', 16, 9),
];

const _palette = <int>[
  0xFFFFFFFF, 0xFF000000, 0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7,
  0xFF3F51B5, 0xFF2196F3, 0xFF03A9F4, 0xFF00BCD4, 0xFF009688, 0xFF4CAF50,
  0xFF8BC34A, 0xFFCDDC39, 0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800, 0xFFFF5722,
  0xFF795548, 0xFF9E9E9E, 0xFF607D8B, 0xFF1A237E, 0xFF880E4F, 0xFF004D40,
];

/// شاشة إنشاء تصميم: [colored] = خلفية ملونة، وإلا تصميم فارغ (شفاف).
class NewDesignPage extends StatefulWidget {
  const NewDesignPage({super.key, required this.colored});
  final bool colored;

  @override
  State<NewDesignPage> createState() => _NewDesignPageState();
}

class _NewDesignPageState extends State<NewDesignPage> {
  final _w = TextEditingController(text: '1080');
  final _h = TextEditingController(text: '1080');
  int _color = 0xFFFFFFFF;
  int _ratio = 0;

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) => (double.tryParse(c.text) ?? 1080).clamp(100, kMaxSide).toDouble();

  void _setRatio(int i) {
    final r = _ratios[i];
    final w = _val(_w);
    var h = (w * r.$3 / r.$2).roundToDouble();
    var ww = w;
    if (h > kMaxSide) {
      h = kMaxSide;
      ww = (h * r.$2 / r.$3).roundToDouble();
    }
    setState(() {
      _ratio = i;
      _w.text = ww.round().toString();
      _h.text = h.round().toString();
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
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = _val(_w), h = _val(_h);
    final ar = w / h;
    return Scaffold(
      appBar: AppBar(title: Text(widget.colored ? 'خلفية ملونة' : 'تصميم فارغ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              _field('العرض', _w),
              const SizedBox(width: 12),
              _field('الارتفاع', _h),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < _ratios.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_ratios[i].$1),
                        selected: _ratio == i,
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(color: _ratio == i ? Colors.black : AppColors.text),
                        backgroundColor: AppColors.panel,
                        side: BorderSide.none,
                        onSelected: (_) => _setRatio(i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 300),
                child: AspectRatio(
                  aspectRatio: math.max(0.2, math.min(5, ar)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.colored ? Color(_color) : AppColors.panel,
                      border: Border.all(color: AppColors.accent, width: 1.5),
                    ),
                    child: widget.colored ? null : const Center(child: Icon(Icons.grid_on, color: AppColors.muted)),
                  ),
                ),
              ),
            ),
            if (widget.colored) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _palette)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _color == c ? AppColors.accent : Colors.white24, width: _color == c ? 3 : 1),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Center(child: Text('أكبر مقاس مسموح 1536 بكسل', style: TextStyle(color: AppColors.muted, fontSize: 12))),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black, padding: const EdgeInsets.all(14)),
              onPressed: _create,
              child: const Text('إنشاء', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
