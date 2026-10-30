import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../theme/app_theme.dart';

/// منزلق بعنوان وقيمة. [onStart] لحفظ نقطة تراجع قبل البدء.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onStart,
    this.display,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onStart;
  final String Function(double)? display;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max).toDouble();
    return Row(
      children: [
        SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted))),
        Expanded(
          child: Slider(
            value: v,
            min: min,
            max: max,
            onChangeStart: onStart == null ? null : (_) => onStart!(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            display != null ? display!(v) : v.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.accent2, fontWeight: FontWeight.w700)),
      );
}

const List<int> kQuickColors = [
  0xFFFFFFFF, 0xFF111111, 0xFFE53935, 0xFFFB8C00, 0xFFFDD835, 0xFF43A047, //
  0xFF00BCD4, 0xFF1E88E5, 0xFF8B6CFF, 0xFFEC407A, 0xFFFFC107, 0xFF795548,
];

Future<Color?> showColorPicker(BuildContext context, Color initial) async {
  Color current = initial;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: initial,
          onColorChanged: (c) => current = c,
          enableAlpha: false,
          labelTypes: const [],
          pickerAreaHeightPercent: 0.7,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تم')),
      ],
    ),
  );
  return res == true ? current : null;
}

/// صف ألوان سريعة + زر منتقي ألوان كامل.
class ColorRow extends StatelessWidget {
  const ColorRow({super.key, required this.selected, required this.onPick});
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () async {
              final c = await showColorPicker(context, Color(selected));
              if (c != null) onPick(c.toARGB32());
            },
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
              ),
              child: const Icon(Icons.colorize, size: 16, color: Colors.white),
            ),
          ),
          for (final c in kQuickColors)
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected == c ? AppColors.accent : Colors.white24, width: selected == c ? 3 : 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChipChoice extends StatelessWidget {
  const ChipChoice({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12.5)),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.accent.withValues(alpha: 0.35),
          backgroundColor: AppColors.panel2,
          side: BorderSide.none,
        ),
      );
}
