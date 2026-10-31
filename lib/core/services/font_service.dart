import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// خطوط جوجل (عربية + إنجليزية) تُحمّل تلقائياً عند أول استخدام ثم تُخزَّن محلياً.
class FontService {
  static final Set<String> _ready = {};
  static int epoch = 0; // يزيد عند اكتمال تحميل خطوط لإبطال كاش القياسات

  static const List<String> arabic = [
    'Cairo',
    'Tajawal',
    'Almarai',
    'Changa',
    'El Messiri',
    'Lalezar',
    'Reem Kufi',
    'Amiri',
    'Harmattan',
    'Lemonada',
    'Mada',
    'Rakkas',
    'Aref Ruqaa',
    'Noto Kufi Arabic',
    'IBM Plex Sans Arabic',
    'Readex Pro',
    'Katibeh',
    'Jomhuria',
    'Marhey',
  ];

  static const List<String> latin = [
    'Poppins',
    'Montserrat',
    'Bebas Neue',
    'Anton',
    'Oswald',
    'Playfair Display',
    'Pacifico',
    'Lobster',
    'Righteous',
    'Bangers',
    'Permanent Marker',
  ];

  static List<String> get all => [...arabic, ...latin];

  static TextStyle style(
    String family, {
    required double size,
    bool bold = false,
    bool italic = false,
    double letterSpacing = 0,
    double height = 1.2,
    Color? color,
    Paint? foreground,
  }) {
    final weight = bold ? FontWeight.w700 : FontWeight.w400;
    final fs = italic ? FontStyle.italic : FontStyle.normal;
    try {
      return GoogleFonts.getFont(
        family,
        fontSize: size,
        fontWeight: weight,
        fontStyle: fs,
        letterSpacing: letterSpacing,
        height: height,
        color: foreground == null ? color : null,
        foreground: foreground,
      );
    } catch (_) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontStyle: fs,
        letterSpacing: letterSpacing,
        height: height,
        color: foreground == null ? color : null,
        foreground: foreground,
      );
    }
  }

  /// يبدأ تحميل الخطوط ويعيد Future يكتمل عند انتهائها.
  static Future<void> preload(Iterable<String> families) async {
    final list = families.toSet();
    for (final f in list) {
      try {
        GoogleFonts.getFont(f);
      } catch (_) {}
    }
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {}
    _ready.addAll(list);
  }

  /// ينتظر جاهزية الخط قبل استخدامه (بحد أقصى [timeout]) كي لا يتغير شكل/ارتفاع
  /// النص بعد ظهوره على اللوحة. بدون إنترنت لا يتعطل التطبيق.
  static Future<void> ensure(String family, {Duration timeout = const Duration(seconds: 4)}) async {
    if (_ready.contains(family)) return;
    try {
      await preload([family]).timeout(timeout);
    } catch (_) {}
  }
}
