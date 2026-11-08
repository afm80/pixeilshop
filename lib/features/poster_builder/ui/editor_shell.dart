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
      _undoAtOpen = bloc.state.undoCount;
    });
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
  };

  void _mut(void Function(Layer) f, {bool commit = true}) => bloc.add(LayerMutated(f, commit: commit));

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
      Widget ic(IconData i, VoidCallback? f, {int badge = 0, Color c = Colors.white}) => Stack(alignment: Alignment.center, children: [
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
              icon: const Icon(Icons.more_vert, color: Colors.white),
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
            ic(_addMenu ? Icons.close : Icons.add_circle, () => setState(() {
                  _addMenu = !_addMenu;
                  _colorMenu = false;
                }), c: _yellow),
          ]),
        ),
      );
    });
  }

  Widget _topTool() {
    return Container(
      height: 56,
      color: _bar,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          IconButton(onPressed: () => _close(cancel: true), icon: const Icon(Icons.close, color: _yellow, size: 32)),
          Expanded(child: Center(child: Text(_titles[_tool] ?? '', style: const TextStyle(color: _yellow, fontSize: 17)))),
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
            Icon(i, color: on ? _yellow : Colors.white, size: 26),
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

  Widget _addMenuW() => _floating([
        _item(Icons.title, 'إضافة نص', _newText),
        _item(Icons.dashboard_customize_outlined, 'تصميم', () {
          setState(() => _addMenu = false);
          _open('add');
        }),
        _item(Icons.photo_library_outlined, 'من الاستوديو', _gallery),
        _item(Icons.category_outlined, 'هندسيات', () => setState(() {
              _addMenu = false;
              _shapes = true;
            })),
        _item(Icons.brush, 'ارسم', () {
          setState(() => _addMenu = false);
          _open('add');
        }),
        _item(Icons.emoji_emotions_outlined, 'ملصقات', () {
          setState(() => _addMenu = false);
          _open('add');
        }),
      ]);

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

  Widget _toolBody(Layer? l) {
    final t = _tool!;
    switch (t) {
      case 'opacity':
        if (l == null) break;
        return _slider('الشفافية', l.opacity, 0, 1, (v) => _mut((x) => x.opacity = v, commit: false));
      case 'fsize':
        if (l == null) break;
        return _slider('الحجم', l.fontSize, 8, 400, (v) => _mut((x) => x.fontSize = v, commit: false), digits: 0);
      case 'lh':
        if (l == null) break;
        return _slider('ارتفاع السطر', l.lineHeight, 0.6, 3, (v) => _mut((x) => x.lineHeight = v, commit: false));
      case 'filters':
        return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: 'layer', part: 'image');
      case 'dfilters':
        return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: 'color');
      case 'bg':
      case 'bgcolor':
        return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: 'bg');
      case 'layers':
        return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: 'layers');
      case 'add':
        return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: 'add');
      default:
        if (t.startsWith('p:')) {
          return EditorPanel(controller: ec, images: widget.images, onEditNewText: widget.onEditText, only: 'layer', part: t.substring(2));
        }
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(builder: (context, st) {
      final l = st.selected;
      final inTool = _tool != null;
      return Column(children: [
        inTool ? _topTool() : _topMain(),
        Expanded(
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: DotsPainter())),
            Positioned.fill(child: CanvasView(images: widget.images, controller: ec, onEditText: widget.onEditText)),
            if (_addMenu && !inTool) _addMenuW(),
            if (_colorMenu && !inTool && l != null)
              _floating(al: Alignment.bottomLeft, [
                for (final p in const [('لون واحد', 'solid'), ('تدرج', 'grad'), ('نمط', 'pattern'), ('تلبيس', 'fill')])
                  _item(Icons.color_lens_outlined, p.$1, () {
                    setState(() => _colorMenu = false);
                    _open('p:color');
                  }),
              ]),
          ]),
        ),
        SafeArea(
          top: false,
          child: inTool
              ? Container(
                  height: 290,
                  color: const Color(0xFF2B2B2B),
                  child: SingleChildScrollView(child: _toolBody(l)),
                )
              : _shapes
                  ? _shapesRow()
                  : _bottomBar(l),
        ),
      ]);
    });
  }
}
