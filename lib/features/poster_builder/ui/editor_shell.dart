import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/font_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/services/media_service.dart';
import '../bloc/canvas_bloc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';
import 'crop_dialog.dart';
import 'editor_panel.dart';
import 'font_picker.dart';
import 'text_dialog.dart';
import 'tool_screens.dart';
import '../model/doc.dart';

const _bar = Color(0xFF252525);
const _yellow = Color(0xFFFFC400);
const _dim = Color(0xFF8A8A8A);

class DotsPainter extends CustomPainter {
  const DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF272727));
    final p = Paint()..color = const Color(0xFF1B1B1B);
    for (double y = 9; y < size.height; y += 18) {
      for (double x = 9; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 2.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotsPainter old) => false;
}

typedef _Btn = ({IconData icon, String label, String tool});

/// واجهة المحرر على نمط بوستر شوب: شريط علوي، لوحة، شريط أدوات سفلي، وكل أداة بشاشتها.
class EditorShell extends StatefulWidget {
  const EditorShell({
    super.key,
    required this.controller,
    required this.images,
    required this.onLeave,
    required this.onExport,
    required this.onEditText,
  });
  final EditorController controller;
  final ImageStore images;
  final VoidCallback onLeave, onExport, onEditText;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  String? _tool; // أداة مفتوحة بشاشتها
  bool _addMenu = false, _colorMenu = false, _shapes = false;
  int _undoAtOpen = 0;
  bool _touched = false;

  EditorController get ec => widget.controller;
  CanvasBloc get bloc => context.read<CanvasBloc>();

  @override
  void initState() {
    super.initState();
    ec.openTool = _open;
  }

  void _open(String t) {
    setState(() {
      _tool = t;
      _addMenu = _colorMenu = _shapes = false;
      _touched = false;
      _undoAtOpen = bloc.state.undoCount;
    });
    if (t == 'brush') {
      ec.brushOn = true;
    }
    ec.setTool(t);
  }

  void _close({bool cancel = false}) {
    if (cancel) {
      var n = bloc.state.undoCount - _undoAtOpen;
      while (n-- > 0) {
        bloc.add(const UndoRequested());
      }
    }
    ec.brushOn = false;
    ec.stopPicker();
    setState(() => _tool = null);
    ec.setTool(null);
  }

  static const _titles = {
    'add': 'إضافة',
    'p:color': 'اللون',
    'p:border': 'إطار',
    'p:shadow': 'الظل',
    'p:corners': 'الزوايا',
    'p:blend': 'وضع الدمج',
    'p:font': 'الخطوط',
    'p:effects': 'إنعكاس',
    'p:pos': 'الموقع',
    'p:curve': 'تقويس',
    'p:depth': 'العمق',
    'p:skew': 'إنحناء',
    'p:image': 'قص وتدوير',
    'opacity': 'الشفافية',
    'filters': 'فلاتر',
    'fsize': 'الحجم',
    'lh': 'ارتفاع السطر',
    'bg': 'الحجم',
    'bgcolor': 'اللون',
    'layers': 'الطبقات',
    'dfilters': 'فلاتر',
    'grad': 'تدرج',
    'pattern': 'نمط',
    'fill': 'تلبيس',
    'brush': 'ارسم',
    'stickers': 'ملصقات',
    'saved': 'تصميم',
    'p:hl': 'تحديد',
  };

  void _touch() {
    if (!_touched) {
      _touched = true;
      bloc.add(const CheckpointRequested());
    }
  }

  void _mut(void Function(Layer) f, {bool commit = true}) => bloc.add(LayerMutated(f, commit: commit));

  void _tmut(void Function(Layer) f) {
    _touch();
    bloc.add(LayerMutated(f));
  }

  void _tdoc(void Function(Doc) f) {
    _touch();
    bloc.add(DocMutated(f));
  }

  Future<void> _addText(String t, {String? font, double? fontSize, double? width}) async {
    await FontService.ensure(font ?? 'Cairo');
    bloc.add(TextLayerAdded(t, font: font, fontSize: fontSize, width: width, bold: font == null ? null : false));
  }

  Future<void> _addImg(String path, int w, int h) async {
    await widget.images.ensure(path);
    if (mounted) bloc.add(ImageLayerAdded(path, w, h));
  }

  ToolCtx _ctx(Layer? l, Doc d) => ToolCtx(
        context: context,
        layer: l,
        doc: d,
        mut: _tmut,
        mutDoc: _tdoc,
        ec: ec,
        images: widget.images,
        addText: _addText,
        addShape: (k) => bloc.add(ShapeLayerAdded(k)),
        addImage: _addImg,
        onEditText: widget.onEditText,
      );

  Future<void> _newText() async {
    setState(() => _addMenu = false);
    final t = await showTextDialog(context, initial: '', title: 'نص جديد');
    if (t == null || t.trim().isEmpty) return;
    await FontService.ensure('Cairo');
    bloc.add(TextLayerAdded(t));
  }

  Future<void> _gallery() async {
    setState(() => _addMenu = false);
    final m = await MediaService.pick();
    if (m == null) return;
    await widget.images.ensure(m.path);
    if (!mounted) return;
    bloc.add(ImageLayerAdded(m.path, m.w, m.h));
  }

  // ───────── الشريط العلوي ─────────
  Widget _topMain() {
    return BlocBuilder<CanvasBloc, CanvasState>(builder: (context, st) {
      Widget ic(IconData i, VoidCallback? f, {int badge = 0, Color c = kYellow}) => Stack(alignment: Alignment.center, children: [
            IconButton(onPressed: f, icon: Icon(i, color: f == null ? Colors.white30 : c, size: 26)),
            if (badge > 0)
              Positioned(
                bottom: 4,
                child: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ),
          ]);
      return Container(
        height: 56,
        color: _bar,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_for_offline_outlined, color: kYellow, size: 28),
              color: const Color(0xFF333333),
              onSelected: (v) {
                switch (v) {
                  case 'leave':
                    widget.onLeave();
                  case 'export':
                    widget.onExport();
                  case 'bg':
                    _open('bg');
                  case 'grid':
                    ec.update(() => ec.showGrid = !ec.showGrid);
                  case 'snap':
                    ec.update(() => ec.snap = !ec.snap);
                  case 'reset':
                    ec.resetView();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'leave', child: Text('حفظ والخروج')),
                PopupMenuItem(value: 'export', child: Text('تصدير')),
                PopupMenuItem(value: 'bg', child: Text('الخلفية والمقاس')),
                PopupMenuItem(value: 'grid', child: Text('إظهار/إخفاء الشبكة')),
                PopupMenuItem(value: 'snap', child: Text('تفعيل/إيقاف المحاذاة')),
                PopupMenuItem(value: 'reset', child: Text('إعادة ضبط العرض')),
              ],
            ),
            ic(Icons.layers_outlined, () => _open('layers')),
            ic(Icons.zoom_in, () => ec.setView(ec.zoom * 1.25, ec.pan)),
            ic(Icons.zoom_out, () => ec.setView(ec.zoom / 1.25, ec.pan)),
            const Spacer(),
            ic(Icons.undo, st.canUndo ? () => bloc.add(const UndoRequested()) : null, badge: st.undoCount),
            ic(Icons.redo, st.canRedo ? () => bloc.add(const RedoRequested()) : null, badge: st.redoCount),
            ic(_addMenu ? Icons.close : Icons.add_box_outlined, () => setState(() {
                  _addMenu = !_addMenu;
                  _colorMenu = false;
                })),
          ]),
        ),
      );
    });
  }

  String _stripTool(String t) => t.startsWith('p:') ? t.substring(2) : t;

  Widget _topTool() {
    return Container(
      height: 56,
      color: _bar,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          IconButton(onPressed: () => _close(cancel: true), icon: const Icon(Icons.close, color: _yellow, size: 32)),
          Expanded(child: Center(child: Text(_titles[_tool] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)))),
          ...toolExtras(_stripTool(_tool!), _ctx(bloc.state.selected, bloc.state.doc)),
          IconButton(onPressed: _close, icon: const Icon(Icons.check, color: _yellow, size: 32)),
        ]),
      ),
    );
  }

  // ───────── الشريط السفلي ─────────
  List<_Btn> _buttons(Layer? l) {
    if (l == null) {
      return const [
        (icon: Icons.add_circle_outline, label: 'إضافة', tool: 'add'),
        (icon: Icons.palette_outlined, label: 'اللون', tool: 'bgcolor'),
        (icon: Icons.tune, label: 'فلاتر', tool: 'dfilters'),
        (icon: Icons.aspect_ratio, label: 'الحجم', tool: 'bg'),
      ];
    }
    const common = <_Btn>[
      (icon: Icons.border_style, label: 'إطار', tool: 'p:border'),
      (icon: Icons.blur_on, label: 'الظل', tool: 'p:shadow'),
      (icon: Icons.rounded_corner, label: 'الزوايا', tool: 'p:corners'),
      (icon: Icons.opacity, label: 'الشفافية', tool: 'opacity'),
      (icon: Icons.filter_vintage_outlined, label: 'فلاتر', tool: 'filters'),
      (icon: Icons.layers, label: 'وضع الدمج', tool: 'p:blend'),
      (icon: Icons.flip, label: 'قلب', tool: 'flip'),
      (icon: Icons.open_with, label: 'الموقع', tool: 'p:pos'),
    ];
    switch (l.type) {
      case LayerType.text:
        return const [
          (icon: Icons.palette_outlined, label: 'اللون', tool: 'p:color'),
          (icon: Icons.font_download_outlined, label: 'الخطوط', tool: 'p:font'),
          (icon: Icons.format_size, label: 'الحجم', tool: 'fsize'),
          (icon: Icons.format_line_spacing, label: 'ارتفاع السطر', tool: 'lh'),
          (icon: Icons.format_align_center, label: 'المحاذاة', tool: 'align'),
          (icon: Icons.format_bold, label: 'الشكل', tool: 'bold'),
          (icon: Icons.format_italic, label: 'ستايل', tool: 'italic'),
          (icon: Icons.border_style, label: 'إطار', tool: 'p:border'),
          (icon: Icons.blur_on, label: 'الظل', tool: 'p:shadow'),
          (icon: Icons.waves, label: 'تقويس', tool: 'p:curve'),
          (icon: Icons.view_in_ar, label: 'العمق', tool: 'p:depth'),
          (icon: Icons.format_italic, label: 'إنحناء', tool: 'p:skew'),
          (icon: Icons.highlight, label: 'تحديد', tool: 'p:hl'),
          (icon: Icons.flip_to_back, label: 'إنعكاس', tool: 'p:effects'),
          (icon: Icons.opacity, label: 'الشفافية', tool: 'opacity'),
          (icon: Icons.layers, label: 'وضع الدمج', tool: 'p:blend'),
          (icon: Icons.filter_vintage_outlined, label: 'فلاتر', tool: 'filters'),
          (icon: Icons.flip, label: 'قلب', tool: 'flip'),
          (icon: Icons.open_with, label: 'الموقع', tool: 'p:pos'),
        ];
      case LayerType.image:
      case LayerType.draw:
        return [
          if (l.type == LayerType.image) (icon: Icons.crop_rotate, label: 'قص/تدوير', tool: 'crop'),
          ...common,
        ];
      case LayerType.shape:
        return [(icon: Icons.palette_outlined, label: 'اللون', tool: 'color'), ...common];
    }
  }

  void _tap(_Btn b, Layer? l) {
    switch (b.tool) {
      case 'flip':
        _mut((x) => x.flipX = !x.flipX);
      case 'align':
        _mut((x) => x.align = (x.align + 1) % 3);
      case 'bold':
        _mut((x) => x.bold = !x.bold);
      case 'italic':
        _mut((x) => x.italic = !x.italic);
      case 'color':
        setState(() => _colorMenu = !_colorMenu);
      case 'crop':
        if (l != null) showCropDialog(context, l, widget.images);
      case 'p:font':
        _pickFont(l);
      default:
        _open(b.tool);
    }
  }

  Future<void> _pickFont(Layer? l) async {
    if (l == null) return;
    final f = await showFontPicker(context, l.font);
    if (f != null) {
      await FontService.ensure(f);
      _mut((x) => x.font = f);
    }
  }

  Widget _bottomBar(Layer? l) {
    final items = _buttons(l);
    return Container(
      height: 74,
      color: _bar,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (l != null) _item(Icons.arrow_back, 'رجوع', () => bloc.add(const LayerSelected(null))),
            for (final b in items) _item(b.icon, b.label, () => _tap(b, l)),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData i, String t, VoidCallback f, {bool on = false}) => InkWell(
        onTap: f,
        child: SizedBox(
          width: 72,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, color: _yellow, size: 26),
            const SizedBox(height: 4),
            Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
      );

  // ───────── القوائم العائمة ─────────
  Widget _floating(List<Widget> children, {Alignment al = Alignment.topRight}) => Align(
        alignment: al,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black54)]),
          child: Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, children: children)),
        ),
      );

  List<Widget> _addItems() => [
        _item(Icons.title, 'إضافة نص', _newText),
        _item(Icons.dashboard_customize_outlined, 'تصميم', () {
          setState(() => _addMenu = false);
          _open('saved');
        }),
        _item(Icons.photo_library_outlined, 'من الاستوديو', _gallery),
        _item(Icons.category_outlined, 'هندسيات', () => setState(() {
              _addMenu = false;
              _shapes = true;
            })),
        _item(Icons.brush, 'ارسم', () {
          setState(() => _addMenu = false);
          _open('brush');
        }),
        _item(Icons.emoji_emotions_outlined, 'ملصقات', () {
          setState(() => _addMenu = false);
          _open('stickers');
        }),
      ];

  Widget _shapesRow() {
    const items = <(String, ShapeKind)>[
      ('مستطيل', ShapeKind.rect),
      ('مثلث', ShapeKind.triangle),
      ('دائرة', ShapeKind.circle),
      ('مخروط', ShapeKind.cone),
      ('خماسي', ShapeKind.pentagon),
      ('سداسي', ShapeKind.hexagon),
      ('سباعي', ShapeKind.heptagon),
      ('ثماني', ShapeKind.octagon),
      ('تساعي', ShapeKind.nonagon),
      ('عشاري', ShapeKind.decagon),
    ];
    return Container(
      height: 74,
      color: _bar,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _item(Icons.arrow_back, 'رجوع', () => setState(() => _shapes = false)),
          for (final s in items)
            _item(Icons.crop_square, s.$1, () {
              bloc.add(ShapeLayerAdded(s.$2));
              setState(() => _shapes = false);
            }),
        ]),
      ),
    );
  }

  // ───────── محتوى الأدوات ─────────
  Widget _slider(String label, double v, double min, double max, ValueChanged<double> f, {int digits = 2}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        SizedBox(width: 56, child: Center(child: Text(v.toStringAsFixed(digits), style: const TextStyle(fontSize: 13)))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 8, activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: _yellow),
            child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: f),
          ),
        ),
        SizedBox(width: 72, child: Center(child: Text(label, style: const TextStyle(fontSize: 13)))),
      ]),
    );
  }

  Widget _toolBody(Layer? l, Doc d) {
    final t = _tool!;
    final key = _stripTool(t);
    final w = buildToolBody(key, _ctx(l, d));
    if (w != null) return w;
    if (t == 'layers') return const SizedBox();
    String? only, part;
    if (t == 'add' || t == 'bg' || t == 'layers') {
      only = t;
    } else if (t == 'fill') {
      only = 'layer';
      part = 'color';
    } else if (t == 'dfilters') {
      only = 'color';
    } else if (t == 'bgcolor') {
      only = 'bg';
    } else if (t.startsWith('p:')) {
      only = 'layer';
      part = key;
    } else if (t == 'filters') {
      only = 'layer';
      part = 'image';
    }
    return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: only, part: part);
  }

  double _toolH() {
    final t = _tool!;
    if (t == 'layers') return 0;
    return toolHeight(_stripTool(t));
  }

  Widget _layersOverlay(CanvasState st) {
    final layers = st.doc.layers;
    final n = layers.length;
    String label(Layer l) {
      switch (l.type) {
        case LayerType.text:
          final t = l.text.trim().replaceAll('\n', ' ');
          return t.isEmpty ? 'نص' : (t.length > 20 ? '${t.substring(0, 20)}…' : t);
        case LayerType.image:
          return 'صورة';
        case LayerType.shape:
          return 'شكل';
        case LayerType.draw:
          return 'رسم';
      }
    }

    IconData icon(Layer l) => switch (l.type) {
          LayerType.text => Icons.title,
          LayerType.image => Icons.image_outlined,
          LayerType.shape => Icons.category_outlined,
          LayerType.draw => Icons.brush,
        };
    Widget sm(IconData i, VoidCallback f) => InkWell(onTap: f, child: SizedBox(width: 30, height: 28, child: Icon(i, size: 18, color: Colors.white70)));
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: (n * 60.0 + 4).clamp(60.0, 330.0),
      child: Material(
        color: const Color(0xFF252525),
        child: ReorderableListView.builder(
          padding: EdgeInsets.zero,
          buildDefaultDragHandles: false,
          itemCount: n,
          onReorder: (o, nw) {
            if (nw > o) nw -= 1;
            bloc.add(LayerReordered(n - 1 - o, n - 1 - nw));
          },
          itemBuilder: (context, i) {
            final l = layers[n - 1 - i];
            final sel = l.id == st.selectedId;
            return Container(
              key: ValueKey(l.id),
              height: 60,
              decoration: BoxDecoration(color: sel ? const Color(0xFF333333) : null, border: const Border(bottom: BorderSide(color: Colors.white10))),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: InkWell(
                  onTap: () => bloc.add(LayerSelected(l.id)),
                  child: Row(children: [
                    IconButton(onPressed: () => bloc.add(LayerRemoved(l.id)), icon: const Icon(Icons.delete_outline, size: 22, color: Colors.white70)),
                    Expanded(
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icon(l), size: 20, color: Colors.white70),
                        const SizedBox(width: 8),
                        Flexible(child: Text(label(l), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                      ]),
                    ),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Row(children: [
                        sm(Icons.copy_all_outlined, () => bloc.add(LayerDuplicated(l.id))),
                        sm(l.locked ? Icons.lock : Icons.lock_open, () => bloc.add(LayerMutated((x) => x.locked = !x.locked, id: l.id, commit: true))),
                      ]),
                      Row(children: [
                        sm(l.hidden ? Icons.visibility_off : Icons.visibility, () => bloc.add(LayerMutated((x) => x.hidden = !x.hidden, id: l.id, commit: true))),
                        sm(Icons.more_vert, () => bloc.add(LayerSelected(l.id))),
                      ]),
                    ]),
                    ReorderableDragStartListener(index: i, child: const SizedBox(width: 40, height: 60, child: Icon(Icons.drag_handle, color: Colors.white70))),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(builder: (context, st) {
      final l = st.selected;
      final inTool = _tool != null;
      final layersMode = _tool == 'layers';
      return Column(children: [
        inTool ? _topTool() : _topMain(),
        Expanded(
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: DotsPainter())),
            Positioned.fill(child: CanvasView(images: widget.images, controller: ec, onEditText: widget.onEditText)),
            if (layersMode) _layersOverlay(st),
            if (_colorMenu && !inTool && l != null)
              _floating(al: Alignment.bottomLeft, [
                for (final p in const [('لون واحد', 'p:color', Icons.format_color_fill), ('تدرج', 'grad', Icons.gradient), ('نمط', 'pattern', Icons.texture), ('تلبيس', 'fill', Icons.image_outlined)])
                  _item(p.$3, p.$1, () {
                    setState(() => _colorMenu = false);
                    _open(p.$2);
                  }),
              ]),
          ]),
        ),
        SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_addMenu && !inTool)
              Container(color: _bar, child: Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: _addItems()))),
            if (inTool && !layersMode)
              Container(
                height: _toolH(),
                color: const Color(0xFF212121),
                child: _toolBody(l, st.doc),
              )
            else if (_shapes && !inTool)
              _shapesRow()
            else
              Opacity(opacity: layersMode ? 0.35 : 1, child: IgnorePointer(ignoring: layersMode, child: _bottomBar(l))),
          ]),
        ),
      ]);
    });
  }
}
