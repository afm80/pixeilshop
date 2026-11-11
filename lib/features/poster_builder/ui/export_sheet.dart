import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/export_service.dart';
import '../../../core/services/image_store.dart';
import '../model/doc.dart';

const _yellow = Color(0xFFFFC400);

/// نافذة «خيارات الحفظ» بأسلوب بوستر شوب: الامتداد (JPEG/PNG) + الأبعاد + موافق/إلغاء.
/// [share] = true يشارك الصورة بدل حفظها في المعرض.
Future<void> showExportSheet(BuildContext context, Doc doc, ImageStore images, {bool share = false}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ExportDialog(doc: doc, images: images, share: share),
  );
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.doc, required this.images, required this.share});
  final Doc doc;
  final ImageStore images;
  final bool share;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ExportFormat _fmt = ExportFormat.png;
  late final List<int> _sizes;
  int _sel = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doc;
    final cur = math.max(d.w, d.h).round();
    final set = <int>[cur];
    for (final s in const [720, 1280, 1536, 1920, 2048]) {
      if (!set.contains(s)) set.add(s);
    }
    _sizes = set;
  }

  String _label(int longSide) {
    final d = widget.doc;
    final k = longSide / math.max(d.w, d.h);
    return '${(d.w * k).round()} X ${(d.h * k).round()}';
  }

  Future<void> _ok() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final d = widget.doc;
      final scale = _sizes[_sel] / math.max(d.w, d.h);
      final img = await ExportService.render(d, widget.images, scale: scale);
      final bytes = await ExportService.encode(img, _fmt, quality: 95);
      if (widget.share) {
        await ExportService.share(bytes, _fmt);
      } else {
        await ExportService.saveToGallery(bytes, _fmt);
        messenger.showSnackBar(const SnackBar(content: Text('تم الحفظ في المعرض')));
      }
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _head(String t) => Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        color: const Color(0xFF1F1F1F),
        child: Text(t, style: const TextStyle(fontSize: 16, color: Colors.white)),
      );

  Widget _fmtBtn(ExportFormat f, String t) {
    final sel = _fmt == f;
    return InkWell(
      onTap: () => setState(() => _fmt = f),
      child: Container(
        width: 104,
        height: 96,
        alignment: Alignment.center,
        color: sel ? _yellow : Colors.transparent,
        child: Text(t, style: TextStyle(fontSize: 18, color: sel ? Colors.black : Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 14),
                child: Text('خيارات الحفظ', style: TextStyle(fontSize: 20, color: _yellow)),
              ),
              _head('الامتداد'),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [_fmtBtn(ExportFormat.jpg, 'JPEG'), _fmtBtn(ExportFormat.png, 'PNG')])),
              ),
              _head('الابعاد'),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sizes.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => setState(() => _sel = i),
                    child: Container(
                      height: 78,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                      child: Row(children: [
                        Icon(_sel == i ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _sel == i ? _yellow : Colors.white54, size: 36),
                        Expanded(child: Center(child: Text(_label(_sizes[i]), style: const TextStyle(fontSize: 17, color: Colors.white)))),
                      ]),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _busy
                    ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: _yellow)))
                    : Row(children: [
                        TextButton(onPressed: _ok, child: const Text('موافق', style: TextStyle(fontSize: 17, color: _yellow))),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء', style: TextStyle(fontSize: 17, color: _yellow))),
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
