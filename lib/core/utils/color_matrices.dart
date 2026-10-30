import 'dart:math' as math;
import 'dart:ui';

import '../../features/poster_builder/model/adjust.dart';

/// فلتر جاهز (مصفوفة 5x4 لـ ColorFilter.matrix) مع ألوان معاينة.
class FilterPreset {
  const FilterPreset(this.name, this.matrix, this.swatch1, this.swatch2);
  final String name;
  final List<double> matrix;
  final Color swatch1, swatch2;
}

/// مصفوفات الألوان: الصف = [R,G,B,A,offset] بمقياس 0..255 للإزاحة.
class ColorMatrices {
  static const List<double> identity = [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// يطبّق [first] ثم [second].
  static List<double> compose(List<double> first, List<double> second) {
    final r = List<double>.filled(20, 0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 5; j++) {
        double v = 0;
        for (int k = 0; k < 4; k++) {
          v += second[i * 5 + k] * first[k * 5 + j];
        }
        if (j == 4) v += second[i * 5 + 4];
        r[i * 5 + j] = v;
      }
    }
    return r;
  }

  static List<double> lerp(List<double> a, List<double> b, double t) =>
      List<double>.generate(20, (i) => a[i] + (b[i] - a[i]) * t);

  static List<double> brightness(double b) => [
        1, 0, 0, 0, b * 255, //
        0, 1, 0, 0, b * 255,
        0, 0, 1, 0, b * 255,
        0, 0, 0, 1, 0,
      ];

  /// c: معامل (1 = بدون تغيير)
  static List<double> contrast(double c) {
    final o = 128 * (1 - c);
    return [
      c, 0, 0, 0, o, //
      0, c, 0, 0, o,
      0, 0, c, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  /// s: معامل (1 = بدون تغيير، 0 = رمادي)
  static List<double> saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    return [
      lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
      lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0,
      lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// t: -1 (بارد) .. 1 (دافئ)
  static List<double> temperature(double t) => [
        1 + 0.18 * t, 0, 0, 0, 10 * t, //
        0, 1 + 0.02 * t, 0, 0, 0,
        0, 0, 1 - 0.18 * t, 0, -10 * t,
        0, 0, 0, 1, 0,
      ];

  /// t: -1 (أخضر) .. 1 (أرجواني)
  static List<double> tint(double t) => [
        1 + 0.04 * t, 0, 0, 0, 0, //
        0, 1 - 0.12 * t, 0, 0, 0,
        0, 0, 1 + 0.04 * t, 0, 0,
        0, 0, 0, 1, 0,
      ];

  static List<double> fade(double f) {
    final s = 1 - f * 0.18;
    final o = f * 45;
    return [
      s, 0, 0, 0, o, //
      0, s, 0, 0, o,
      0, 0, s, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> hueRotate(double degrees) {
    final a = degrees * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    return [
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> channelScale(double r, double g, double b, {double ro = 0, double go = 0, double bo = 0}) => [
        r, 0, 0, 0, ro, //
        0, g, 0, 0, go,
        0, 0, b, 0, bo,
        0, 0, 0, 1, 0,
      ];

  static const List<double> _sepia = [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double> _chain(List<List<double>> steps) {
    var m = identity;
    for (final s in steps) {
      m = compose(m, s);
    }
    return m;
  }

  /// الفلاتر الجاهزة. الفهرس 0 = بدون.
  static final List<FilterPreset> presets = [
    const FilterPreset('بدون', identity, Color(0xFF444444), Color(0xFF888888)),
    FilterPreset(
      'سينمائي',
      _chain([contrast(1.12), saturation(1.1), channelScale(1.08, 0.98, 0.92, ro: 4, bo: 12)]),
      const Color(0xFF0E4D64),
      const Color(0xFFE08A3C),
    ),
    FilterPreset('دافئ', _chain([temperature(0.4), fade(0.08), contrast(1.05)]), const Color(0xFFE9A24B), const Color(0xFFB5532A)),
    FilterPreset('بارد', _chain([temperature(-0.4), tint(-0.1), saturation(1.05)]), const Color(0xFF4B8BE9), const Color(0xFF2A4EB5)),
    FilterPreset('أبيض وأسود', _chain([saturation(0), contrast(1.12)]), const Color(0xFFEEEEEE), const Color(0xFF222222)),
    FilterPreset('نوار', _chain([saturation(0), contrast(1.5), brightness(-0.05)]), const Color(0xFFBDBDBD), const Color(0xFF000000)),
    FilterPreset('سيبيا', _sepia, const Color(0xFFD9B98A), const Color(0xFF6B4A2A)),
    FilterPreset('كلاسيكي', _chain([lerp(identity, _sepia, 0.5), fade(0.25), saturation(0.85)]), const Color(0xFFCDBA9A), const Color(0xFF7A6A52)),
    FilterPreset('حيوي', _chain([saturation(1.5), contrast(1.1)]), const Color(0xFFFF5E8A), const Color(0xFF3AD1FF)),
    FilterPreset('مطفي', _chain([fade(0.35), saturation(0.9)]), const Color(0xFF9AA5A0), const Color(0xFF5C6663)),
    FilterPreset('الساعة الذهبية', _chain([temperature(0.5), tint(0.1), saturation(1.15), brightness(0.04)]), const Color(0xFFFFC857), const Color(0xFFE5703A)),
    FilterPreset('سايبر', _chain([hueRotate(40), saturation(1.4), contrast(1.1), channelScale(1, 1, 1.1, bo: 8)]), const Color(0xFFFF2BD6), const Color(0xFF2BD9FF)),
    FilterPreset('باستيل', _chain([contrast(0.85), brightness(0.12), saturation(0.8)]), const Color(0xFFF7C6D9), const Color(0xFFBFE3F5)),
    FilterPreset('درامي', _chain([contrast(1.35), saturation(1.2), brightness(-0.05)]), const Color(0xFF7A1F1F), const Color(0xFF111111)),
  ];

  /// يبني المصفوفة النهائية من إعدادات [Adjust].
  static List<double> forAdjust(Adjust a) {
    var m = identity;
    if (a.preset > 0 && a.preset < presets.length) {
      m = lerp(identity, presets[a.preset].matrix, a.presetAmount.clamp(0.0, 1.0).toDouble());
    }
    if (a.brightness != 0) m = compose(m, brightness(a.brightness));
    if (a.contrast != 0) m = compose(m, contrast(1 + a.contrast));
    if (a.saturation != 0) m = compose(m, saturation(1 + a.saturation));
    if (a.temperature != 0) m = compose(m, temperature(a.temperature));
    if (a.tint != 0) m = compose(m, tint(a.tint));
    if (a.fade != 0) m = compose(m, fade(a.fade));
    if (a.hue != 0) m = compose(m, hueRotate(a.hue));
    return m;
  }
}
