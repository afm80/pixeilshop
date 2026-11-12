import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../../core/services/beauty_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/image_store.dart';
import '../../core/services/media_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_matrices.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/model/layer.dart';
import '../poster_builder/ui/editor_page.dart';

/// يبني تصميماً من صورة واحدة (يستخدم في الكاميرا والاستوديو).
/// الفلتر يوضع على مستوى التصميم كله فيبقى قابلاً للتعديل داخل المحرر.
Doc docFromPhoto(MediaRef m, {int preset = 0, bool mirror = false}) {
  final k = math.min(1.0, StorageService.maxImport / math.max(m.w, m.h));
  final w = (m.w * k).roundToDouble(), h = (m.h * k).roundToDouble();
  final d = Doc.blank(name: 'صورة', w: w, h: h);
  d.layers.add(Layer.create(LayerType.image, name: 'صورة')
    ..path = m.path
    ..x = w / 2
    ..y = h / 2
    ..w = w
    ..h = h
    ..flipX = mirror);
  d.adjust.preset = preset;
  d.adjust.presetAmount = 1;
  return d;
}

/// زر أيقونة فقط بأسلوب سناب شات: أيقونة بيضاء بظل خفيف، ووصف عند الضغط المطوّل.
class CamSideBtn extends StatelessWidget {
  const CamSideBtn({super.key, required this.icon, required this.tip, required this.onTap, this.active = false});
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 52,
            height: 52,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white24 : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 30,
              color: onTap == null ? Colors.white38 : Colors.white,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black87), Shadow(blurRadius: 2, color: Colors.black54)],
            ),
          ),
        ),
      );
}

/// شاشة ما بعد الالتقاط: الصورة + أيقونات عمودية (نص، رسم، ملصقات، فلاتر، قص، تعديل، حفظ).
/// التمرير الأفقي على الصورة يغيّر الفلتر، والرجوع من زر الجهاز.
class CapturePreviewPage extends StatefulWidget {
  const CapturePreviewPage({super.key, required this.photo, this.preset = 0, this.mirror = false});
  final MediaRef photo;
  final int preset;
  final bool mirror;

  @override
  State<CapturePreviewPage> createState() => _CapturePreviewPageState();
}

class _CapturePreviewPageState extends State<CapturePreviewPage> {
  late final Doc _doc = docFromPhoto(widget.photo, preset: widget.preset, mirror: widget.mirror);
  final ImageStore _images = ImageStore();
  bool _busy = false;
  bool _handedOff = false; // انتقلت الصورة للمحرر، فلا تُحذف
  String _label = '';
  Timer? _labelTimer;
  BeautyService? _beauty;
  String? _bakedPath; // الصورة المجمَّلة (تنعيم داخل الشخص + تمويه الخلفية)
  bool _beautyBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBeauty();
    });
  }

  String get _shownPath => _bakedPath ?? widget.photo.path;

  /// يطبّق التجميل الحقيقي إن كان الفلتر الحالي من فلاتر التجميل، وإلا يعيد الصورة الأصلية.
  Future<void> _syncBeauty() async {
    final idx = _preset;
    final pr = ColorMatrices.presets[idx];
    final isBeauty = pr.smooth > 0 || pr.bgBlur > 0;
    _doc.adjust.noPresetSmooth = isBeauty;
    if (!isBeauty) {
      _setBaked(null);
      return;
    }
    setState(() => _beautyBusy = true);
    String? out;
    try {
      _beauty ??= BeautyService(widget.photo.path);
      out = await _beauty!.bake(smooth: pr.smooth, bgBlur: pr.bgBlur);
    } catch (e) {
      debugPrint('beauty failed: $e');
    }
    if (!mounted || idx != _preset) {
      if (out != null) File(out).delete().catchError((_) => File(out!));
      return; // طلب أحدث يتولّى الأمر
    }
    _setBaked(out);
    setState(() => _beautyBusy = false);
    if (out != null && pr.smooth > 0 && !(_beauty?.hasFace ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يُكتشف وجه: طُبّق تمويه الخلفية فقط')));
    }
    if (out == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يُكتشف شخص في الصورة، لم يُطبَّق التجميل')));
    }
  }

  void _setBaked(String? path) {
    final old = _bakedPath;
    if (old != null && old != path) File(old).delete().catchError((_) => File(old));
    _bakedPath = path;
    for (final l in _doc.layers) {
      if (l.type == LayerType.image) {
        l.path = path ?? widget.photo.path;
        break;
      }
    }
    if (mounted) setState(() {});
  }

  int get _preset => _doc.adjust.preset;

  @override
  void dispose() {
    _labelTimer?.cancel();
    _images.dispose();
    _beauty?.dispose();
    if (!_handedOff) {
      File(widget.photo.path).delete().catchError((_) => File(widget.photo.path));
      final b = _bakedPath;
      if (b != null) File(b).delete().catchError((_) => File(b));
    }
    super.dispose();
  }

  void _setPreset(int i) {
    final n = ColorMatrices.presets.length;
    final v = ((i % n) + n) % n;
    setState(() {
      _doc.adjust.preset = v;
      _label = ColorMatrices.presets[v].name;
    });
    _syncBeauty();
    _labelTimer?.cancel();
    _labelTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _label = '');
    });
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -250) _setPreset(_preset + 1); // سحب لليسار → التالي
    if (v > 250) _setPreset(_preset - 1); // سحب لليمين → السابق
  }

  Future<void> _save() async {
    if (_busy || _beautyBusy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final img = await ExportService.render(_doc, _images, watermark: true);
      final bytes = await ExportService.encode(img, ExportFormat.jpg, quality: 95);
      await ExportService.saveToGallery(bytes, ExportFormat.jpg);
      messenger.showSnackBar(const SnackBar(content: Text('تم الحفظ في المعرض')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// يفتح المحرر على أداة معينة ('' = المحرر كاملاً).
  void _toEditor(String tool) {
    if (_beautyBusy) return;
    _handedOff = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EditorPage(doc: _doc, startTool: tool)));
  }

  Future<void> _pickFilter() async {
    final i = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => _FiltersPage(path: widget.photo.path, mirror: widget.mirror, current: _preset)),
    );
    if (i != null) _setPreset(i);
  }

  @override
  Widget build(BuildContext context) {
    final matrix = ColorMatrices.forAdjust(_doc.adjust);
    Widget image = Image.file(File(_shownPath), fit: BoxFit.contain, key: ValueKey(_shownPath), gaplessPlayback: true);
    if (widget.mirror) {
      image = Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: image);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: _onSwipe,
                child: ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: image),
              ),
            ),
            if (_beautyBusy)
              const Center(child: SizedBox(width: 38, height: 38, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent))),
            if (_label.isNotEmpty)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text(_label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CamSideBtn(icon: Icons.text_fields_rounded, tip: 'نص', onTap: () => _toEditor('text')),
                      CamSideBtn(icon: Icons.edit_rounded, tip: 'رسم', onTap: () => _toEditor('brush')),
                      CamSideBtn(icon: Icons.sticky_note_2_outlined, tip: 'ملصقات وإيموجي', onTap: () => _toEditor('stickers')),
                      CamSideBtn(icon: Icons.auto_awesome_rounded, tip: 'الفلاتر', onTap: _pickFilter, active: _preset != 0),
                      CamSideBtn(icon: Icons.crop_rounded, tip: 'قص وتحجيم', onTap: () => _toEditor('crop')),
                      CamSideBtn(icon: Icons.tune_rounded, tip: 'تعديل', onTap: () => _toEditor('')),
                      _busy
                          ? const SizedBox(width: 52, height: 60, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent))))
                          : CamSideBtn(icon: Icons.download_rounded, tip: 'حفظ', onTap: _save),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صفحة اختيار الفلتر: شبكة معاينات للصورة نفسها، واللمس يختار ويرجع.
class _FiltersPage extends StatelessWidget {
  const _FiltersPage({required this.path, required this.mirror, required this.current});
  final String path;
  final bool mirror;
  final int current;

  @override
  Widget build(BuildContext context) {
    final presets = ColorMatrices.presets;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('الفلاتر'), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
        itemCount: presets.length,
        itemBuilder: (_, i) {
          final p = presets[i];
          Widget img = Image.file(File(path), fit: BoxFit.cover, cacheWidth: 360);
          if (mirror) img = Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: img);
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(i),
            child: Column(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i == current ? AppColors.accent2 : Colors.transparent, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  width: double.infinity,
                  child: ColorFiltered(colorFilter: ColorFilter.matrix(p.matrix), child: img),
                ),
              ),
              const SizedBox(height: 4),
              Text(p.name, style: TextStyle(color: i == current ? AppColors.accent2 : Colors.white70, fontSize: 12)),
            ]),
          );
        },
      ),
    );
  }
}
