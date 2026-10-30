import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/services/media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/model/layer.dart';
import '../poster_builder/ui/editor_page.dart';

/// تخطيطات الكولاج: تُرجع مستطيلات الخلايا داخل لوحة مربعة.
List<Rect> collageRects(int n, int kind, double size, double gap) {
  final out = <Rect>[];
  final inner = size - gap * 2;
  switch (kind) {
    case 1: // أعمدة
      final w = (inner - gap * (n - 1)) / n;
      for (int i = 0; i < n; i++) {
        out.add(Rect.fromLTWH(gap + i * (w + gap), gap, w, inner));
      }
      break;
    case 2: // صفوف
      final h = (inner - gap * (n - 1)) / n;
      for (int i = 0; i < n; i++) {
        out.add(Rect.fromLTWH(gap, gap + i * (h + gap), inner, h));
      }
      break;
    case 3: // رئيسية + بقية
      if (n == 1) {
        out.add(Rect.fromLTWH(gap, gap, inner, inner));
        break;
      }
      final bigW = inner * 0.6;
      out.add(Rect.fromLTWH(gap, gap, bigW, inner));
      final rest = n - 1;
      final sw = inner - bigW - gap;
      final sh = (inner - gap * (rest - 1)) / rest;
      for (int i = 0; i < rest; i++) {
        out.add(Rect.fromLTWH(gap + bigW + gap, gap + i * (sh + gap), sw, sh));
      }
      break;
    default: // شبكة
      final cols = math.max(1, math.sqrt(n).ceil());
      final rows = (n / cols).ceil();
      final ch = (inner - gap * (rows - 1)) / rows;
      int idx = 0;
      for (int r = 0; r < rows; r++) {
        final k = math.min(cols, n - idx);
        final cw = (inner - gap * (k - 1)) / k;
        for (int c = 0; c < k; c++) {
          out.add(Rect.fromLTWH(gap + c * (cw + gap), gap + r * (ch + gap), cw, ch));
          idx++;
        }
      }
  }
  return out;
}

class CollagePage extends StatefulWidget {
  const CollagePage({super.key});

  @override
  State<CollagePage> createState() => _CollagePageState();
}

class _CollagePageState extends State<CollagePage> {
  List<MediaRef> _imgs = [];
  int _kind = 0;
  double _gap = 12;
  int _bg = 0xFFFFFFFF;

  Future<void> _pick() async {
    final m = await MediaService.pickMany();
    if (m.isNotEmpty && mounted) setState(() => _imgs = m.take(9).toList());
  }

  Future<void> _create() async {
    const size = 1080.0;
    final doc = Doc.blank(name: 'كولاج', w: size, h: size)..bgColor1 = _bg;
    final rects = collageRects(_imgs.length, _kind, size, _gap);
    for (int i = 0; i < _imgs.length; i++) {
      final r = rects[i];
      final l = Layer.create(LayerType.image, name: 'صورة ${i + 1}')
        ..path = _imgs[i].path
        ..x = r.center.dx
        ..y = r.center.dy
        ..w = r.width
        ..h = r.height;
      doc.layers.add(l);
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EditorPage(doc: doc)));
  }

  @override
  Widget build(BuildContext context) {
    const kinds = ['شبكة', 'أعمدة', 'صفوف', 'رئيسية'];
    return Scaffold(
      appBar: AppBar(title: const Text('كولاج الصور')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_imgs.isEmpty ? 'اختر الصور (حتى 9)' : 'تغيير الصور (${_imgs.length})')),
            const SizedBox(height: 10),
            Expanded(
              child: _imgs.isEmpty
                  ? const Center(child: Text('لم تُختر صور بعد', style: TextStyle(color: AppColors.muted)))
                  : MasonryGridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      itemCount: _imgs.length,
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: _imgs[i].w / _imgs[i].h,
                          child: Image.file(File(_imgs[i].path), fit: BoxFit.cover, cacheWidth: 400),
                        ),
                      ),
                    ),
            ),
            const SectionLabel('التخطيط'),
            Row(children: [
              for (int i = 0; i < kinds.length; i++) ChipChoice(label: kinds[i], selected: _kind == i, onTap: () => setState(() => _kind = i)),
            ]),
            SliderRow(label: 'المسافة', value: _gap, min: 0, max: 40, onChanged: (v) => setState(() => _gap = v), display: (v) => v.round().toString()),
            const SectionLabel('لون الإطار'),
            ColorRow(selected: _bg, onPick: (c) => setState(() => _bg = c)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _imgs.isEmpty ? null : _create, child: const Text('إنشاء الكولاج وفتح المحرر')),
            ),
          ],
        ),
      ),
    );
  }
}
