import 'package:flutter/material.dart';

import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../poster_builder/ui/editor_page.dart';
import 'saved_ui.dart';

/// التصاميم المحفوظة: صف «حفظ تلقائي» ثم قائمة (مصغّرة، اسم، حذف، تفاصيل). الضغط يفتح التصميم.
class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<ProjectMeta> _projects = [];
  bool _newest = true;
  bool _auto = StorageService.autosave;

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
    if (!await confirmDelete(context, p)) return;
    await StorageService.delete(p.id);
    _refresh();
  }

  Future<void> _open(ProjectMeta p) async {
    final d = StorageService.load(p.id);
    if (d == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(doc: d)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('تصاميم محفوظة'),
        actions: [
          IconButton(
            tooltip: _newest ? 'الأحدث أولاً' : 'الأقدم أولاً',
            icon: const Icon(Icons.sort, color: AppColors.accent2),
            onPressed: () => setState(() => _newest = !_newest),
          ),
          IconButton(icon: const Icon(Icons.check, color: AppColors.accent2), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Column(children: [
        SwitchListTile(
          title: const Text('حفظ تلقائي'),
          value: _auto,
          activeColor: AppColors.accent2,
          onChanged: (v) async {
            await StorageService.setAutosave(v);
            setState(() => _auto = v);
          },
        ),
        const Divider(height: 1, color: Colors.white10),
        Expanded(child: SavedList(projects: sorted(_projects, _newest), onOpen: _open, onDelete: _delete)),
      ]),
    );
  }
}
