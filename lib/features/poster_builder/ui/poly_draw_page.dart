import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/export_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/theme/app_theme.dart';
import '../model/doc.dart';

/// صفحة رسم مضلع حر: انقر لإضافة نقاط فوق معاينة التصميم، وانقر النقطة الأولى (أو ✓) لإغلاق الشكل.
/// تُرجع النقاط بإحداثيات نسبية 0..1 من التصميم، أو null عند الإلغاء.
class PolygonDrawPage extends StatefulWidget {
  const PolygonDrawPage({super.key, required this.doc, required this.images});
  final Doc doc;
  final ImageStore images;

  @override
  State<PolygonDrawPage> createState() => _PolygonDrawPageState();
}

class _PolygonDrawPageState extends State<PolygonDrawPage> {
  final List<Offset> _pts = [];
  ui.Image? _bg;

  @override
  void initState() {
    super.initState();
    _loadBg();
  }

  Future<void> _loadBg() async {
    try {
      final d = widget.doc;
      final k = 1024 / (d.w > d.h ? d.w : d.h);
      final img = await ExportService.render(d, widget.images, scale: k);
      if (mounted) setState(() => _bg = img);
    } catch (_) {}
  }

  void _finish() {
    if (_pts.length >= 3) Navigator.pop(context, List<Offset>.of(_pts));
  }

  void _tap(Offset local, Size size) {
    final p = Offset((local.dx / size.width).clamp(0.0, 1.0).toDouble(), (local.dy / size.height).clamp(0.0, 1.0).toDouble());
    // نقر قريب من النقطة الأولى (بعد ثلاث نقاط على الأقل) يغلق الشكل
    if (_pts.length >= 3 && (Offset(_pts.first.dx * size.width, _pts.first.dy * size.height) - local).distance < 22) {
      _finish();
      return;
    }
    setState(() => _pts.add(p));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final ready = _pts.length >= 3;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        leading: IconButton(icon: const Icon(Icons.close, color: AppColors.accent2), onPressed: () => Navigator.pop(context)),
        title: const Text('ارسم مضلع'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'حذف آخر نقطة',
            icon: Icon(Icons.undo, color: _pts.isEmpty ? Colors.white30 : AppColors.accent2),
            onPressed: _pts.isEmpty ? null : () => setState(_pts.removeLast),
          ),
          IconButton(
            tooltip: 'تأكيد',
            icon: Icon(Icons.check, color: ready ? AppColors.accent2 : Colors.white30),
            onPressed: ready ? _finish : null,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: AspectRatio(
                aspectRatio: d.w / d.h,
                child: LayoutBuilder(builder: (context, box) {
                  final size = Size(box.maxWidth, box.maxHeight);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (t) => _tap(t.localPosition, size),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: Colors.white),
                      if (_bg != null) RawImage(image: _bg, fit: BoxFit.fill),
                      CustomPaint(painter: _PolyPainter(_pts)),
                    ]),
                  );
                }),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            ready ? 'انقر ✓ أو النقطة الأولى لإغلاق الشكل، أو تابع إضافة النقاط' : 'انقر لإضافة نقاط (ثلاث نقاط على الأقل)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      ]),
    );
  }
}

class _PolyPainter extends CustomPainter {
  _PolyPainter(this.pts);
  final List<Offset> pts;

  @override
  void paint(Canvas c, Size s) {
    if (pts.isEmpty) return;
    final o = [for (final p in pts) Offset(p.dx * s.width, p.dy * s.height)];
    final path = Path()..moveTo(o.first.dx, o.first.dy);
    for (final p in o.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (o.length >= 3) {
      path.close();
      c.drawPath(path, Paint()..color = const Color(0x44FFC400));
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFFC400);
    c.drawPath(path, line);
    for (var i = 0; i < o.length; i++) {
      c.drawCircle(o[i], i == 0 ? 9 : 6, Paint()..color = Colors.black54);
      c.drawCircle(o[i], i == 0 ? 7 : 4.5, Paint()..color = i == 0 ? const Color(0xFFFF5C6C) : const Color(0xFFFFC400));
    }
  }

  @override
  bool shouldRepaint(covariant _PolyPainter old) => true;
}
