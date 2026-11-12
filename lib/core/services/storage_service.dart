import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/poster_builder/model/doc.dart';

class ProjectMeta {
  const ProjectMeta(this.id, this.name, this.updated, this.w, this.h, this.thumbPath);
  final String id, name;
  final DateTime updated;
  final double w, h;
  final String? thumbPath;
}

/// تخزين المشاريع محلياً عبر Hive (JSON لكل مشروع).
class StorageService {
  static const _boxName = 'pixeilshop_projects';
  static const _setBoxName = 'pixeilshop_settings';
  static Box<String>? _box;
  static Box<String>? _setBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _setBox = await Hive.openBox<String>(_setBoxName);
  }

  /// الحفظ التلقائي للتصاميم أثناء التعديل (مطفأ افتراضياً).
  static bool get autosave => _setBox?.get('autosave') == '1';
  static Future<void> setAutosave(bool v) async => _setBox?.put('autosave', v ? '1' : '0');

  /// الحد الأقصى لأكبر بُعد للصور المستوردة (1280 / 1536 / 2048).
  static int get maxImport {
    final v = int.tryParse(_setBox?.get('maxImport') ?? '') ?? 2048;
    return const [1280, 1536, 2048].contains(v) ? v : 2048;
  }

  static Future<void> setMaxImport(int v) async => _setBox?.put('maxImport', '$v');

  /// علامة مائية تُضاف إلى الصور المصدّرة (نص و/أو شعار).
  static bool get wmOn => _setBox?.get('wmOn') == '1';
  static Future<void> setWmOn(bool v) async => _setBox?.put('wmOn', v ? '1' : '0');
  static String get wmText => _setBox?.get('wmText') ?? '';
  static Future<void> setWmText(String v) async => _setBox?.put('wmText', v);
  static String? get wmLogo {
    final v = _setBox?.get('wmLogo');
    return (v == null || v.isEmpty || !File(v).existsSync()) ? null : v;
  }

  static Future<void> setWmLogo(String? v) async => _setBox?.put('wmLogo', v ?? '');

  static bool exists(String id) => _b.containsKey(id);

  /// يحفظ نسخة من التصميم تحت معرّف واسم محددين (حفظ جديد أو كتابة فوق تصميم محفوظ).
  static Future<void> saveCopy(Doc doc, String id, String name) async {
    final c = Doc.fromJson({...doc.toJson(), 'id': id, 'name': name});
    await save(c);
  }

  static Box<String> get _b => _box!;

  static Future<void> save(Doc doc) async {
    final m = {'updated': DateTime.now().millisecondsSinceEpoch, 'doc': doc.toJson()};
    await _b.put(doc.id, jsonEncode(m));
  }

  static Doc? load(String id) {
    final s = _b.get(id);
    if (s == null) return null;
    final m = jsonDecode(s) as Map<String, dynamic>;
    return Doc.fromJson(Map<String, dynamic>.from(m['doc'] as Map));
  }

  static Future<void> delete(String id) async {
    await _b.delete(id);
    try {
      final f = File(await thumbPathFor(id));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<String> thumbPathFor(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'thumbs', '$id.png');
  }

  static Future<List<ProjectMeta>> list() async {
    final out = <ProjectMeta>[];
    for (final key in _b.keys) {
      try {
        final m = jsonDecode(_b.get(key as String)!) as Map<String, dynamic>;
        final d = Map<String, dynamic>.from(m['doc'] as Map);
        final tp = await thumbPathFor(key);
        out.add(ProjectMeta(
          key,
          (d['name'] as String?) ?? 'تصميم',
          DateTime.fromMillisecondsSinceEpoch((m['updated'] as num).toInt()),
          (d['w'] as num).toDouble(),
          (d['h'] as num).toDouble(),
          File(tp).existsSync() ? tp : null,
        ));
      } catch (_) {}
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }
}
