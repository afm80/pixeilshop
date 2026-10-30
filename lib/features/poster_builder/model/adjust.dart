/// إعدادات التعديل اللوني (Lightroom-style) لطبقة أو للتصميم كله.
class Adjust {
  Adjust({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.fade = 0,
    this.hue = 0,
    this.vignette = 0,
    this.preset = 0,
    this.presetAmount = 1,
  });

  double brightness; // -1..1
  double contrast; // -1..1
  double saturation; // -1..1
  double temperature; // -1..1
  double tint; // -1..1
  double fade; // 0..1
  double hue; // -180..180 (درجات)
  double vignette; // 0..1
  int preset; // 0 = بدون
  double presetAmount; // 0..1

  /// هل يوجد أي تعديل يؤثر على مصفوفة الألوان (الفينيت منفصل).
  bool get hasMatrix =>
      brightness != 0 ||
      contrast != 0 ||
      saturation != 0 ||
      temperature != 0 ||
      tint != 0 ||
      fade != 0 ||
      hue != 0 ||
      preset != 0;

  void reset() {
    brightness = 0;
    contrast = 0;
    saturation = 0;
    temperature = 0;
    tint = 0;
    fade = 0;
    hue = 0;
    vignette = 0;
    preset = 0;
    presetAmount = 1;
  }

  Adjust clone() => Adjust.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'b': brightness,
        'c': contrast,
        's': saturation,
        't': temperature,
        'ti': tint,
        'f': fade,
        'h': hue,
        'v': vignette,
        'p': preset,
        'pa': presetAmount,
      };

  factory Adjust.fromJson(Map<String, dynamic>? m) {
    if (m == null) return Adjust();
    double d(String k, [double def = 0]) => (m[k] as num?)?.toDouble() ?? def;
    return Adjust(
      brightness: d('b'),
      contrast: d('c'),
      saturation: d('s'),
      temperature: d('t'),
      tint: d('ti'),
      fade: d('f'),
      hue: d('h'),
      vignette: d('v'),
      preset: (m['p'] as num?)?.toInt() ?? 0,
      presetAmount: d('pa', 1),
    );
  }
}
