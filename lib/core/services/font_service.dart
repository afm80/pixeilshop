import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  /// خطوط رفعها المستخدم (ملفات ttf/otf) — تُحفظ في مجلد التطبيق وتُحمَّل عند الإقلاع.
  static final List<String> custom = [];

  /// عائلة خط أيقونات Material (لطبقات الأيقونات القابلة للتعديل).
  static const String iconFont = 'MaterialIcons';

  static List<String> get all => [...custom, ...arabic, ...latin];

  static Future<Directory> _fontsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'fonts'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<void> _register(String family, String path) async {
    final loader = FontLoader(family)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
    if (!custom.contains(family)) custom.add(family);
    _ready.add(family);
  }

  /// يحمّل الخطوط المخصصة المحفوظة. يُستدعى مرة عند الإقلاع.
  static Future<void> loadCustom() async {
    try {
      final d = await _fontsDir();
      await for (final f in d.list()) {
        if (f is! File) continue;
        final ext = p.extension(f.path).toLowerCase();
        if (ext != '.ttf' && ext != '.otf') continue;
        try {
          await _register(p.basenameWithoutExtension(f.path), f.path);
        } catch (_) {}
      }
      epoch++;
    } catch (_) {}
  }

  /// يضيف خطاً من ملف اختاره المستخدم ويعيد اسم العائلة (أو null عند الفشل).
  static Future<String?> addCustom(String srcPath) async {
    try {
      final ext = p.extension(srcPath).toLowerCase();
      if (ext != '.ttf' && ext != '.otf') return null;
      final family = p.basenameWithoutExtension(srcPath).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final d = await _fontsDir();
      final dst = p.join(d.path, '$family$ext');
      await File(srcPath).copy(dst);
      await _register(family, dst);
      epoch++;
      return family;
    } catch (_) {
      return null;
    }
  }

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
    // خطوط محلية: أيقونات Material أو خطوط رفعها المستخدم (لا تمر عبر google_fonts)
    if (family == iconFont || custom.contains(family)) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: family == iconFont ? FontWeight.w400 : weight,
        fontStyle: family == iconFont ? FontStyle.normal : fs,
        letterSpacing: letterSpacing,
        height: height,
        color: foreground == null ? color : null,
        foreground: foreground,
      );
    }
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
    if (_ready.contains(family) || family == iconFont) return;
    try {
      await preload([family]).timeout(timeout);
    } catch (_) {}
  }
}
