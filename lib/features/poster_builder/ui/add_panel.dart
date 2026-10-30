import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../core/services/media_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../bloc/canvas_bloc.dart';
import '../model/layer.dart';

const _stickers = [
  '⭐', '🔥', '❤️', '✨', '🎉', '👑', '💎', '🌟', '⚡', '🎯', '🏆', '💥', //
  '🌸', '🍕', '☕', '🚀', '🎵', '📣', '🛒', '🔔', '✅', '❌', '🆕', '🎁',
];

const _shapes = <(String, ShapeKind, IconData)>[
  ('مستطيل', ShapeKind.rect, Icons.crop_square),
  ('دائرة', ShapeKind.circle, Icons.circle_outlined),
  ('مثلث', ShapeKind.triangle, Icons.change_history),
  ('نجمة', ShapeKind.star, Icons.star_border),
  ('معين', ShapeKind.diamond, Icons.diamond_outlined),
  ('خط', ShapeKind.line, Icons.horizontal_rule),
];

class AddPanel extends StatelessWidget {
  const AddPanel({super.key, required this.onEditNewText});
  final VoidCallback onEditNewText;

  Future<void> _addImage(BuildContext context, ImageSource src) async {
    final bloc = context.read<CanvasBloc>();
    final m = await MediaService.pick(source: src);
    if (m != null) bloc.add(ImageLayerAdded(m.path, m.w, m.h));
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CanvasBloc>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Big(icon: Icons.title, label: 'نص', onTap: () {
              bloc.add(const TextLayerAdded('اكتب هنا'));
              onEditNewText();
            }),
            _Big(icon: Icons.image_outlined, label: 'صورة', onTap: () => _addImage(context, ImageSource.gallery)),
            _Big(icon: Icons.photo_camera_outlined, label: 'كاميرا', onTap: () => _addImage(context, ImageSource.camera)),
          ],
        ),
        const SectionLabel('أشكال'),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in _shapes)
                ChipChoice(label: s.$1, icon: s.$3, selected: false, onTap: () => bloc.add(ShapeLayerAdded(s.$2))),
            ],
          ),
        ),
        const SectionLabel('ملصقات'),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final e in _stickers)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  bloc.add(TextLayerAdded(e, fontSize: bloc.state.doc.w * 0.2));
                  bloc.add(LayerMutated((l) {
                    l.w = bloc.state.doc.w * 0.4;
                    l.bold = false;
                  }));
                },
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10)),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ]),
        ),
      );
}
