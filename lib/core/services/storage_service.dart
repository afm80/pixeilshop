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
  static Box<String>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
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
