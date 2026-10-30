import 'dart:ui';

class BlendOption {
  const BlendOption(this.label, this.mode);
  final String label;
  final BlendMode mode;
}

const List<BlendOption> kBlends = [
  BlendOption('عادي', BlendMode.srcOver),
  BlendOption('Multiply', BlendMode.multiply),
  BlendOption('Screen', BlendMode.screen),
  BlendOption('Overlay', BlendMode.overlay),
  BlendOption('Darken', BlendMode.darken),
  BlendOption('Lighten', BlendMode.lighten),
  BlendOption('Color Dodge', BlendMode.colorDodge),
  BlendOption('Color Burn', BlendMode.colorBurn),
  BlendOption('Soft Light', BlendMode.softLight),
  BlendOption('Hard Light', BlendMode.hardLight),
  BlendOption('Difference', BlendMode.difference),
  BlendOption('Exclusion', BlendMode.exclusion),
];
