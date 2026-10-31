import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../poster_builder/ui/editor_page.dart';

/// التصاميم المحفوظة: شبكة مصغّرات. ضغطة تفتح، ضغطة مطوّلة تحذف.
class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<ProjectMeta> _projects = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final l = await StorageService.list();
    if (mounted) setState(() => _projects = l);
  }

  Future<void> _delete(ProjectMeta p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التصميم؟'),
        content: Text(p.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.delete(p.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تصاميم محفوظة')),
      body: _projects.isEmpty
          ? const Center(child: Text('لا توجد تصاميم محفوظة', style: TextStyle(color: AppColors.muted)))
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9),
              itemCount: _projects.length,
              itemBuilder: (context, i) {
                final p = _projects[i];
                return GestureDetector(
                  onTap: () async {
                    final d = StorageService.load(p.id);
                    if (d == null) return;
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(doc: d)));
                    _refresh();
                  },
                  onLongPress: () => _delete(p),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(8)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: AppColors.panel2,
                          child: p.thumbPath != null
                              ? Image.file(File(p.thumbPath!), fit: BoxFit.contain, key: ValueKey('${p.id}${p.updated.millisecondsSinceEpoch}'))
                              : const Icon(Icons.image_outlined, color: AppColors.muted, size: 40),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('${p.w.round()}×${p.h.round()}', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
