import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/tflite_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../poster_builder/model/layer.dart';
import '../bloc/anime_bloc.dart';

/// تحويل الصورة إلى أنمي/كرتون/كوميك/رسم رصاص (محلياً).
class AnimeSection extends StatefulWidget {
  const AnimeSection({super.key, required this.layer});
  final Layer layer;

  @override
  State<AnimeSection> createState() => _AnimeSectionState();
}

class _AnimeSectionState extends State<AnimeSection> {
  StyleKind _kind = StyleKind.anime;
  double _strength = 1;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnimeBloc, AnimeState>(
      builder: (context, st) {
        final busy = st.status == AnimeStatus.working;
        final l = widget.layer;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('تحويل إلى أنمي / كرتون'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final k in StyleKind.values) ChipChoice(label: k.label, selected: _kind == k, onTap: () => setState(() => _kind = k)),
                ],
              ),
            ),
            SliderRow(
              label: 'الشدة',
              value: _strength,
              min: 0.2,
              max: 1,
              onChanged: (v) => setState(() => _strength = v),
              display: (v) => '${(v * 100).round()}%',
            ),
            FilledButton.icon(
              onPressed: busy || l.path == null ? null : () => context.read<AnimeBloc>().runAnimeModel(l.id, l.path!, kind: _kind, strength: _strength),
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.brush, size: 18),
              label: Text(busy ? 'جارٍ التحويل…' : 'تحويل'),
            ),
          ],
        );
      },
    );
  }
}
