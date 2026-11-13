import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/export_service.dart';
import '../../core/services/font_service.dart';
import '../../core/services/image_store.dart';
import '../../core/theme/app_theme.dart';
import '../poster_builder/ui/editor_page.dart';
import 'templates_data.dart';

/// قوالب جاهزة: تصنيفات + شبكة معاينات. الضغط على قالب يفتحه في المحرر كتصميم جديد.
class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  final ImageStore _images = ImageStore();
  final Map<String, ui.Image> _thumbs = {};
  String _cat = 'الكل';
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _renderAll();
  }

  Future<void> _renderAll() async {
    // الخطوط أولاً كي تظهر النصوص في المعاينات بشكلها الصحيح
    try {
      await FontService.preload({for (final t in kTemplates) ...t.fonts});
    } catch (_) {}
    for (final t in kTemplates) {
      if (!mounted) return;
      try {
        final d = t.create();
        final img = await ExportService.render(d, _images, scale: 360 / math.max(d.w, d.h));
        if (!mounted) return;
        setState(() => _thumbs[t.id] = img);
      } catch (_) {}
    }
  }

  Future<void> _open(TemplateDef t) async {
    if (_opening) return;
    _opening = true;
    try {
      await FontService.preload(t.fonts);
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(doc: t.create())));
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final list = [for (final t in kTemplates) if (_cat == 'الكل' || templateTab(t) == _cat) t];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('قوالب جاهزة'),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            children: [
              for (final c in kTemplateCategories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _cat == c,
                    selectedColor: AppColors.accent2,
                    labelStyle: TextStyle(color: _cat == c ? Colors.black : null),
                    onSelected: (_) => setState(() => _cat = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              final img = _thumbs[t.id];
              return InkWell(
                onTap: () => _open(t),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: img == null
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : ClipRRect(borderRadius: BorderRadius.circular(4), child: RawImage(image: img, fit: BoxFit.contain)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    Text('${t.w.round()}×${t.h.round()}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
