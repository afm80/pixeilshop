import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/media_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../bloc/canvas_bloc.dart';
import '../model/doc.dart';

const _sizes = <(String, double, double)>[
  ('مربع 1:1', 1080, 1080),
  ('بوست 4:5', 1080, 1350),
  ('ستوري 9:16', 1080, 1920),
  ('أفقي 16:9', 1920, 1080),
  ('A4 بوستر', 1240, 1754),
  ('غلاف 3:1', 1500, 500),
];

class BackgroundPanel extends StatelessWidget {
  const BackgroundPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, st) {
        final d = st.doc;
        final bloc = context.read<CanvasBloc>();
        void set(void Function(Doc) f) => bloc.add(DocMutated(f, commit: true));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const SectionLabel('نوع الخلفية'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChipChoice(label: 'لون', selected: d.bgKind == 0, onTap: () => set((x) => x.bgKind = 0)),
                  ChipChoice(label: 'تدرج', selected: d.bgKind == 1, onTap: () => set((x) => x.bgKind = 1)),
                  ChipChoice(
                    label: 'صورة',
                    selected: d.bgKind == 2,
                    onTap: () async {
                      final m = await MediaService.pick();
                      if (m != null) {
                        bloc.add(DocMutated((x) {
                          x.bgKind = 2;
                          x.bgPath = m.path;
                        }, commit: true));
                      }
                    },
                  ),
                  ChipChoice(label: 'شفافة', selected: d.bgKind == 3, onTap: () => set((x) => x.bgKind = 3)),
                ],
              ),
            ),
            if (d.bgKind == 0 || d.bgKind == 1) ...[
              const SectionLabel('اللون'),
              ColorRow(selected: d.bgColor1, onPick: (c) => set((x) => x.bgColor1 = c)),
            ],
            if (d.bgKind == 1) ...[
              const SectionLabel('اللون الثاني'),
              ColorRow(selected: d.bgColor2, onPick: (c) => set((x) => x.bgColor2 = c)),
              SliderRow(
                label: 'الزاوية',
                value: d.bgAngle,
                min: 0,
                max: 360,
                onStart: () => bloc.add(const CheckpointRequested()),
                onChanged: (v) => bloc.add(DocMutated((x) => x.bgAngle = v)),
                display: (v) => '${v.round()}°',
              ),
            ],
            const SectionLabel('مقاس التصميم'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _sizes)
                  ActionChip(
                    label: Text(s.$1, style: const TextStyle(fontSize: 12)),
                    backgroundColor: (d.w == s.$2 && d.h == s.$3) ? AppColors.accent.withValues(alpha: 0.35) : AppColors.panel2,
                    side: BorderSide.none,
                    onPressed: () => bloc.add(DocMutated((x) {
                      // نعيد توسيط العناصر عند تغيير المقاس
                      final kx = s.$2 / x.w, ky = s.$3 / x.h;
                      for (final l in x.layers) {
                        l.x *= kx;
                        l.y *= ky;
                      }
                      x.w = s.$2;
                      x.h = s.$3;
                    }, commit: true)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
