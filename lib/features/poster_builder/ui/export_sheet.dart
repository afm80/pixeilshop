import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/export_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../model/doc.dart';

Future<void> showExportSheet(BuildContext context, Doc doc, ImageStore images) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExportSheet(doc: doc, images: images),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.doc, required this.images});
  final Doc doc;
  final ImageStore images;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  ExportFormat _fmt = ExportFormat.png;
  double _scale = 1;
  double _quality = 92;
  bool _busy = false;

  String get _sizeText {
    final k = math.min(_scale, ExportService.maxSide / math.max(widget.doc.w, widget.doc.h));
    return '${(widget.doc.w * k).round()} × ${(widget.doc.h * k).round()} px';
  }

  Future<void> _run(bool share) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final img = await ExportService.render(widget.doc, widget.images, scale: _scale);
      final bytes = await ExportService.encode(img, _fmt, quality: _quality.round());
      if (share) {
        await ExportService.share(bytes, _fmt);
      } else {
        await ExportService.saveToGallery(bytes, _fmt);
        messenger.showSnackBar(const SnackBar(content: Text('تم الحفظ في المعرض')));
      }
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تصدير التصميم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SectionLabel('الصيغة'),
          Row(children: [
            for (final f in ExportFormat.values) ChipChoice(label: f.label, selected: _fmt == f, onTap: () => setState(() => _fmt = f)),
          ]),
          const SectionLabel('الدقة'),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final s in [0.5, 1.0, 2.0, 3.0, 4.0])
              ChipChoice(label: s == s.toInt() ? '${s.toInt()}x' : '${s}x', selected: _scale == s, onTap: () => setState(() => _scale = s)),
            const SizedBox(width: 8),
            Text(_sizeText, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
          if (_fmt != ExportFormat.png)
            SliderRow(
              label: 'الجودة',
              value: _quality,
              min: 50,
              max: 100,
              onChanged: (v) => setState(() => _quality = v),
              display: (v) => v.round().toString(),
            ),
          const SizedBox(height: 14),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => _run(false), icon: const Icon(Icons.download), label: const Text('حفظ في المعرض'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => _run(true), icon: const Icon(Icons.share), label: const Text('مشاركة'))),
            ]),
        ],
      ),
    );
  }
}
