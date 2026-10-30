import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../poster_builder/model/layer.dart';
import '../../poster_builder/ui/canvas_view.dart';
import '../bloc/subject_segmentation_bloc.dart';

/// إزالة الخلفية + الممحاة اليدوية لطبقة صورة.
class RemoverSection extends StatefulWidget {
  const RemoverSection({super.key, required this.layer, required this.controller});
  final Layer layer;
  final EditorController controller;

  @override
  State<RemoverSection> createState() => _RemoverSectionState();
}

class _RemoverSectionState extends State<RemoverSection> {
  double _tol = 42;

  @override
  Widget build(BuildContext context) {
    final l = widget.layer;
    final ec = widget.controller;
    final erasing = ec.eraserLayerId == l.id;
    return BlocBuilder<SubjectSegmentationBloc, SubjectSegmentationState>(
      builder: (context, st) {
        final busy = st.status == RemoverStatus.working;
        final bloc = context.read<SubjectSegmentationBloc>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('عزل الخلفية'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: busy || l.path == null ? null : () => bloc.removeBackground(l.id, l.path!),
                  icon: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(busy ? 'جارٍ المعالجة…' : 'إزالة الخلفية بالذكاء الاصطناعي'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || l.path == null ? null : () => bloc.removeBackground(l.id, l.path!, tolerance: _tol, colorOnly: true),
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('بالألوان'),
                ),
              ],
            ),
            SliderRow(
              label: 'حساسية الألوان',
              value: _tol,
              min: 10,
              max: 120,
              onChanged: (v) => setState(() => _tol = v),
              display: (v) => v.round().toString(),
            ),
            const SectionLabel('الممحاة'),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => erasing ? ec.stopEraser() : ec.startEraser(l.id),
                  icon: Icon(erasing ? Icons.check : Icons.cleaning_services_outlined, size: 18),
                  label: Text(erasing ? 'إنهاء المسح' : 'مسح يدوي'),
                  style: erasing ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
                ),
              ],
            ),
            if (erasing)
              SliderRow(
                label: 'حجم الفرشاة',
                value: ec.eraserRadius,
                min: 0.01,
                max: 0.15,
                onChanged: ec.setRadius,
                display: (v) => (v * 100).round().toString(),
              ),
          ],
        );
      },
    );
  }
}
