import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/export_service.dart';
import '../../core/services/image_store.dart';
import '../../core/services/media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_matrices.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/model/layer.dart';
import '../poster_builder/ui/editor_page.dart';

/// يبني تصميماً من صورة واحدة (يستخدم في الكاميرا والاستوديو).
/// الفلتر يوضع على مستوى التصميم كله فيبقى قابلاً للتعديل داخل المحرر.
Doc docFromPhoto(MediaRef m, {int preset = 0, bool mirror = false}) {
  final k = math.min(1.0, 2048 / math.max(m.w, m.h));
  final w = (m.w * k).roundToDouble(), h = (m.h * k).roundToDouble();
  final d = Doc.blank(name: 'صورة', w: w, h: h);
  d.layers.add(Layer.create(LayerType.image, name: 'صورة')
    ..path = m.path
    ..x = w / 2
    ..y = h / 2
    ..w = w
    ..h = h
    ..flipX = mirror);
  d.adjust.preset = preset;
  d.adjust.presetAmount = 1;
  return d;
}

/// شاشة ما بعد الالتقاط: معاينة + تغيير الفلتر بالتمرير الأفقي + حفظ / مشاركة / تعديل.
class CapturePreviewPage extends StatefulWidget {
  const CapturePreviewPage({super.key, required this.photo, this.preset = 0, this.mirror = false});
  final MediaRef photo;
  final int preset;
  final bool mirror;

  @override
  State<CapturePreviewPage> createState() => _CapturePreviewPageState();
}

class _CapturePreviewPageState extends State<CapturePreviewPage> {
  late final Doc _doc = docFromPhoto(widget.photo, preset: widget.preset, mirror: widget.mirror);
  final ImageStore _images = ImageStore();
  bool _busy = false;
  bool _handedOff = false; // انتقلت الصورة للمحرر، فلا تُحذف
  String _label = '';
  Timer? _labelTimer;

  int get _preset => _doc.adjust.preset;

  @override
  void dispose() {
    _labelTimer?.cancel();
    _images.dispose();
    if (!_handedOff) {
      File(widget.photo.path).delete().catchError((_) => File(widget.photo.path));
    }
    super.dispose();
  }

  void _setPreset(int i) {
    final n = ColorMatrices.presets.length;
    final v = ((i % n) + n) % n;
    setState(() {
      _doc.adjust.preset = v;
      _label = ColorMatrices.presets[v].name;
    });
    _labelTimer?.cancel();
    _labelTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _label = '');
    });
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -250) _setPreset(_preset + 1); // سحب لليسار → التالي
    if (v > 250) _setPreset(_preset - 1); // سحب لليمين → السابق
  }

  Future<void> _export({required bool share}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final img = await ExportService.render(_doc, _images);
      final bytes = await ExportService.encode(img, ExportFormat.jpg, quality: 95);
      if (share) {
        await ExportService.share(bytes, ExportFormat.jpg);
      } else {
        await ExportService.saveToGallery(bytes, ExportFormat.jpg);
        messenger.showSnackBar(const SnackBar(content: Text('تم الحفظ في المعرض')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit() {
    _handedOff = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EditorPage(doc: _doc)));
  }

  @override
  Widget build(BuildContext context) {
    final matrix = ColorMatrices.forAdjust(_doc.adjust);
    Widget image = Image.file(File(widget.photo.path), fit: BoxFit.contain);
    if (widget.mirror) {
      image = Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: image);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: _onSwipe,
                child: ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: image),
              ),
            ),
            if (_label.isNotEmpty)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text(_label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _RoundBtn(icon: Icons.close, onTap: () => Navigator.of(context).pop()),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _RoundBtn(icon: Icons.download_rounded, onTap: _busy ? null : () => _export(share: false)),
                      const SizedBox(width: 10),
                      _RoundBtn(icon: Icons.ios_share_rounded, onTap: _busy ? null : () => _export(share: true)),
                      const Spacer(),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
                        ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _edit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('تعديل', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: 24)),
        ),
      );
}
