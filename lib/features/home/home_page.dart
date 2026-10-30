import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../core/services/media_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../collage/collage_page.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/model/layer.dart';
import '../poster_builder/ui/editor_page.dart';

const _sizes = <(String, double, double, IconData)>[
  ('مربع', 1080, 1080, Icons.crop_square),
  ('بوست 4:5', 1080, 1350, Icons.crop_portrait),
  ('ستوري 9:16', 1080, 1920, Icons.smartphone),
  ('أفقي 16:9', 1920, 1080, Icons.crop_landscape),
  ('بوستر A4', 1240, 1754, Icons.description_outlined),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  Future<void> _open(Doc d, {String tool = ''}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(doc: d, startTool: tool)));
    _refresh();
  }

  /// مستند يحتوي صورة كطبقة بحجم التصميم كله
  Doc _photoDoc(MediaRef m, {bool transparent = false}) {
    final k = math.min(1.0, 2048 / math.max(m.w, m.h));
    final w = (m.w * k).roundToDouble(), h = (m.h * k).roundToDouble();
    final d = Doc.blank(name: 'صورة', w: w, h: h);
    if (transparent) d.bgKind = 3;
    final l = Layer.create(LayerType.image, name: 'صورة')
      ..path = m.path
      ..x = w / 2
      ..y = h / 2
      ..w = w
      ..h = h;
    d.layers.add(l);
    return d;
  }

  Future<void> _fromPhoto(String tool, {ImageSource source = ImageSource.gallery}) async {
    final m = await MediaService.pick(source: source);
    if (m == null || !mounted) return;
    _open(_photoDoc(m, transparent: tool == 'rmbg'), tool: tool);
  }

  Future<void> _delete(ProjectMeta p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المشروع؟'),
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
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.auto_fix_high, 'إزالة الخلفية', () => _fromPhoto('rmbg')),
      (Icons.face_retouching_natural, 'تحويل أنمي', () => _fromPhoto('anime')),
      (Icons.color_lens_outlined, 'تعديل الألوان', () => _fromPhoto('grade')),
      (Icons.grid_view_rounded, 'كولاج', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CollagePage()))),
    ];
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(colors: [AppColors.accent, AppColors.accent2]).createShader(r),
                      child: const Text('OmniStudio AI', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    const Text('مجاني 100% · المعالجة تتم على جهازك', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final t in tools)
                      GestureDetector(
                        onTap: t.$3,
                        child: Container(
                          width: 112,
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.panel,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(t.$1, size: 30, color: AppColors.accent),
                              const SizedBox(height: 8),
                              Text(t.$2, style: const TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Text('تصميم جديد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _sizes)
                      ActionChip(
                        avatar: Icon(s.$4, size: 18, color: AppColors.accent2),
                        label: Text(s.$1),
                        backgroundColor: AppColors.panel,
                        side: BorderSide.none,
                        onPressed: () => _open(Doc.blank(name: s.$1, w: s.$2, h: s.$3)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.accent2),
                      label: const Text('من صورة'),
                      backgroundColor: AppColors.panel,
                      side: BorderSide.none,
                      onPressed: () => _fromPhoto(''),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 20, 18, 6),
                child: Text('مشاريعي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            if (_projects.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد مشاريع بعد — ابدأ بتصميم جديد', style: TextStyle(color: AppColors.muted))),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final p = _projects[i];
                      return GestureDetector(
                        onTap: () {
                          final d = StorageService.load(p.id);
                          if (d != null) _open(d);
                        },
                        onLongPress: () => _delete(p),
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
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
                                child: Row(
                                  children: [
                                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text('${p.w.round()}×${p.h.round()}', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _projects.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
