import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خطوط يضيفها المستخدم من جهازه (ttf / otf)
class UserFonts {
  static final List<String> names = [];

  static Future<void> _load(String family, String path) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    if (!names.contains(family)) names.add(family);
  }

  /// يُستدعى عند بدء التطبيق لتحميل الخطوط المحفوظة
  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    for (final e in p.getStringList('ufonts') ?? const <String>[]) {
      final i = e.indexOf('|');
      if (i < 0) continue;
      final f = e.substring(0, i), path = e.substring(i + 1);
      try {
        if (File(path).existsSync()) await _load(f, path);
      } catch (_) {}
    }
  }

  /// يختار ملف خط من الجهاز ويضيفه. يرجع اسم الخط أو null
  static Future<String?> add() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ttf', 'otf'], withData: true);
    if (r == null || r.files.isEmpty) return null;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;
    var base = f.name.replaceAll(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '');
    base = base.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final family = 'user_${base}_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final dir = await getApplicationDocumentsDirectory();
    final fd = Directory('${dir.path}/fonts')..createSync(recursive: true);
    final file = File('${fd.path}/$family.ttf')..writeAsBytesSync(bytes);
    await _load(family, file.path);
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList('ufonts') ?? <String>[];
    l.add('$family|${file.path}');
    await p.setStringList('ufonts', l);
    return family;
  }
}
