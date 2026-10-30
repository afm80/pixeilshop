import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// خطوط جوجل (عربية + إنجليزية) تُحمّل تلقائياً عند أول استخدام ثم تُخزَّن محلياً.
class FontService {
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
    for (final f in families.toSet()) {
      try {
        GoogleFonts.getFont(f);
      } catch (_) {}
    }
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {}
  }
}
