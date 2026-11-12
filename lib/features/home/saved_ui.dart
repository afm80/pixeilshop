import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/export_service.dart';
import '../../core/services/image_store.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../poster_builder/model/doc.dart';

String _two(int v) => v.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}  ${_two(d.hour)}:${_two(d.minute)}';

List<ProjectMeta> sorted(List<ProjectMeta> l, bool newestFirst) {
  final c = [...l];
  c.sort((a, b) => newestFirst ? b.updated.compareTo(a.updated) : a.updated.compareTo(b.updated));
  return c;
}

Future<void> showDetails(BuildContext context, ProjectMeta p) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('التفاصيل', style: TextStyle(color: AppColors.accent2)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الاسم: ${p.name}'),
          const SizedBox(height: 6),
          Text('الحجم: ${p.w.round()} × ${p.h.round()}'),
          const SizedBox(height: 6),
          Text('آخر تعديل: ${fmtDate(p.updated)}'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );

Future<bool> confirmDelete(BuildContext context, ProjectMeta p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('حذف التصميم؟'),
      content: Text(p.name),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ),
  );
  return ok == true;
}

/// قائمة التصاميم المحفوظة: مصغّرة + اسم + (حفظ فوقه) + حذف + «التفاصيل».
class SavedList extends StatelessWidget {
  const SavedList({super.key, required this.projects, required this.onOpen, required this.onDelete, this.onOverwrite});
  final List<ProjectMeta> projects;
  final void Function(ProjectMeta) onOpen, onDelete;
  final void Function(ProjectMeta)? onOverwrite;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Center(child: Text('لا توجد تصاميم محفوظة', style: TextStyle(color: AppColors.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, i) {
        final p = projects[i];
        return InkWell(
          onTap: () => onOpen(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                color: AppColors.panel2,
                child: p.thumbPath != null
                    ? Image.file(File(p.thumbPath!), fit: BoxFit.contain, key: ValueKey('${p.id}${p.updated.millisecondsSinceEpoch}'))
                    : const Icon(Icons.image_outlined, color: AppColors.muted),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
              if (onOverwrite != null)
                IconButton(
                  tooltip: 'حفظ فوق هذا التصميم',
                  icon: const Icon(Icons.save_outlined, color: AppColors.accent2),
                  onPressed: () => onOverwrite!(p),
                ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline, color: AppColors.accent2),
                onPressed: () => onDelete(p),
              ),
              TextButton(onPressed: () => showDetails(context, p), child: const Text('التفاصيل')),
            ]),
          ),
        );
      },
    );
  }
}

/// إعدادات التطبيق (حالياً: الحفظ التلقائي).
Future<void> showAppSettings(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('إعدادات التطبيق', style: TextStyle(color: AppColors.accent2)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('حفظ تلقائي'),
              value: StorageService.autosave,
              activeColor: AppColors.accent2,
              onChanged: (v) async {
                await StorageService.setAutosave(v);
                set(() {});
              },
            ),
            const SizedBox(height: 10),
            const Text('الحد الأقصى لحجم الصور المستوردة'),
            const SizedBox(height: 8),
            Row(children: [
              for (final v in const [1280, 1536, 2048])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text('$v'),
                    selected: StorageService.maxImport == v,
                    selectedColor: AppColors.accent2,
                    labelStyle: TextStyle(color: StorageService.maxImport == v ? Colors.black : null),
                    onSelected: (_) async {
                      await StorageService.setMaxImport(v);
                      set(() {});
                    },
                  ),
                ),
            ]),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );

/// لوحة «حفظ التصميم» داخل المحرر.
Future<void> showSaveDesignPanel(BuildContext context, Doc doc, ImageStore images) =>
    showDialog<void>(context: context, builder: (_) => _SavePanel(doc: doc, images: images));

class _SavePanel extends StatefulWidget {
  const _SavePanel({required this.doc, required this.images});
  final Doc doc;
  final ImageStore images;

  @override
  State<_SavePanel> createState() => _SavePanelState();
}

class _SavePanelState extends State<_SavePanel> {
  List<ProjectMeta> _projects = [];
  bool _newest = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await StorageService.list();
    if (mounted) setState(() => _projects = l);
  }

  Future<String?> _askName(String initial) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('يرجى كتابة اسم للتصميم', style: TextStyle(fontSize: 16, color: AppColors.accent2)),
        content: TextField(controller: ctrl, autofocus: true, textInputAction: TextInputAction.done),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('الغاء')),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }

  Future<void> _write(String id, String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    var ok = true;
    try {
      await StorageService.saveCopy(widget.doc, id, name);
      await ExportService.thumbnail(widget.doc, widget.images, id);
      if (id == widget.doc.id) widget.doc.name = name;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        content: Text(ok ? 'تم حفظ التصميم بنجاح.' : 'تعذر حفظ التصميم.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
    _load();
  }

  Future<void> _newDesign() async {
    final name = await _askName(widget.doc.name);
    if (name == null) return;
    // إن كان هذا التصميم محفوظاً مسبقاً نحفظ نسخة جديدة بمعرّف جديد كي لا نكتب فوقه
    final id = StorageService.exists(widget.doc.id) ? DateTime.now().microsecondsSinceEpoch.toString() : widget.doc.id;
    await _write(id, name);
  }

  Future<void> _overwrite(ProjectMeta p) => _write(p.id, p.name);

  Future<void> _delete(ProjectMeta p) async {
    if (!await confirmDelete(context, p)) return;
    await StorageService.delete(p.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.8;
    return Dialog(
      backgroundColor: AppColors.panel,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxH),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close, color: AppColors.accent2), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('حفظ التصميم', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: AppColors.accent2))),
              IconButton(
                tooltip: _newest ? 'الأحدث أولاً' : 'الأقدم أولاً',
                icon: const Icon(Icons.sort, color: AppColors.accent2),
                onPressed: () => setState(() => _newest = !_newest),
              ),
            ]),
          ),
          const Divider(height: 1, color: Colors.white10),
          InkWell(
            onTap: _busy ? null : _newDesign,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.add_circle_outline, color: AppColors.accent2),
                SizedBox(width: 12),
                Text('تصميم جديد', style: TextStyle(fontSize: 15)),
              ]),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Flexible(
            child: SavedList(
              projects: sorted(_projects, _newest),
              onOpen: (_) {},
              onOverwrite: _overwrite,
              onDelete: _delete,
            ),
          ),
        ]),
      ),
    );
  }
}
