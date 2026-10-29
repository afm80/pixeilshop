import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const kAccent = Color(0xFF2EE6B8);
const kAccentDim = Color(0xFF1B7F68);
const kBg = Color(0xFF0F1115);
const kPanel = Color(0xFF181B21);
const kCard = Color(0xFF20242C);
const kDot = Color(0xFF171A20);

/// خلفية داكنة منقّطة
class DotBg extends StatelessWidget {
  const DotBg({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _DotP()))),
        child,
      ]);
}

class _DotP extends CustomPainter {
  const _DotP();
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = kBg);
    final pts = <Offset>[];
    for (double y = 6; y < s.height; y += 12) {
      for (double x = ((y ~/ 12).isEven ? 6 : 12); x < s.width; x += 12) {
        pts.add(Offset(x, y));
      }
    }
    c.drawPoints(PointMode.points, pts,
        Paint()..color = kDot..strokeWidth = 3..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

/// زر أيقونة + نص صغير (للشريط العلوي)
class BarBtn extends StatelessWidget {
  const BarBtn(this.icon, this.label, this.onTap, {super.key});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 64, height: 66, color: kPanel,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: kAccent, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}

/// شريط عنوان الصفحات الفرعية: رجوع يسار، تأكيد يمين
class SubBar extends StatelessWidget {
  const SubBar({super.key, required this.title, required this.onOk});
  final String title;
  final VoidCallback onOk;
  @override
  Widget build(BuildContext context) => Container(
        height: 56, color: kPanel,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: kAccent), onPressed: () => Navigator.pop(context)),
            Text(title, style: const TextStyle(fontSize: 18)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.check, color: kAccent, size: 30), onPressed: onOk),
          ]),
        ),
      );
}

/// أوضاع الدمج (الأول = عادي)
const kBlends = <(String, BlendMode)>[
  ('عادي', BlendMode.srcOver), ('ضرب', BlendMode.multiply), ('شاشة', BlendMode.screen), ('تراكب', BlendMode.overlay),
  ('تغميق', BlendMode.darken), ('تفتيح', BlendMode.lighten), ('إضاءة اللون', BlendMode.colorDodge),
  ('حرق اللون', BlendMode.colorBurn), ('إضاءة قوية', BlendMode.hardLight), ('إضاءة ناعمة', BlendMode.softLight),
  ('فرق', BlendMode.difference), ('استبعاد', BlendMode.exclusion),
];

/// يدمج الطفل مع ما تحته بوضع دمج معيّن
class BlendBox extends SingleChildRenderObjectWidget {
  const BlendBox({super.key, required this.mode, super.child});
  final BlendMode mode;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlend(mode);
  @override
  void updateRenderObject(BuildContext context, covariant _RenderBlend r) => r.mode = mode;
}

class _RenderBlend extends RenderProxyBox {
  _RenderBlend(this._mode);
  BlendMode _mode;
  set mode(BlendMode m) {
    if (m == _mode) return;
    _mode = m;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(null, Paint()..blendMode = _mode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
