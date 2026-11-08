import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/export_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/poster_painter.dart';
import '../../../core/utils/text_metrics.dart';
import '../bloc/canvas_bloc.dart';
import '../model/doc.dart';
import '../model/layer.dart';

/// حالة أدوات المحرر المشتركة (الممحاة، الأقسام المفتوحة، العرض، الفرشاة، التحديد المتعدد...).
class EditorController extends ChangeNotifier {
  String? eraserLayerId;
  double eraserRadius = 0.04; // نسبة من عرض الطبقة
  final Set<String> _open = {'add'};

  // ── العرض (تكبير/تحريك/شبكة)
  double zoom = 1;
  Offset pan = Offset.zero;
  Size viewport = Size.zero;
  bool showGrid = false, snap = false;

  // ── الفرشاة
  bool brushOn = false, brushErase = false, brushDashed = false;
  int brushColor = 0xFFFFFFFF;
  double brushWidth = 14, brushOpacity = 1;

  // ── التحديد المتعدد (للتجميع)
  bool multiMode = false;
  final Set<String> multi = {};

  // ── قطّارة الألوان: عند ضبطها ينتظر التطبيق ضغطة على التصميم لأخذ اللون
  void Function(int color)? picker;

  bool isOpen(String id) => _open.contains(id);

  void toggle(String id) {
    if (!_open.remove(id)) _open.add(id);
    notifyListeners();
  }

  /// يفتح قسماً بدون إغلاق الباقي.
  void show(String id) {
    if (_open.add(id)) notifyListeners();
  }

  /// يفتح قسماً واحداً ويطوي الباقي.
  void openOnly(String id) {
    _open
      ..clear()
      ..add(id);
    notifyListeners();
  }

  /// تعديل حقول ثم إشعار المستمعين.
  void update(VoidCallback f) {
    f();
    notifyListeners();
  }

  void startEraser(String id) {
    eraserLayerId = id;
    brushOn = false;
    notifyListeners();
  }

  void stopEraser() {
    eraserLayerId = null;
    notifyListeners();
  }

  void setRadius(double r) {
    eraserRadius = r;
    notifyListeners();
  }

  void setView(double z, Offset p) {
    zoom = z.clamp(1.0, 6.0).toDouble();
    if (zoom <= 1.001) {
      zoom = 1;
      pan = Offset.zero;
    } else {
      final mx = viewport.width * zoom / 2, my = viewport.height * zoom / 2;
      pan = Offset(p.dx.clamp(-mx, mx).toDouble(), p.dy.clamp(-my, my).toDouble());
    }
    notifyListeners();
  }

  void resetView() => setView(1, Offset.zero);

  /// الأداة المفتوحة حالياً (شاشة كاملة). عندها تُخفى مقابض التحديد ويُعطَّل اللمس إلا للقطّارة.
  String? tool;
  /// يطلب فتح أداة من الشريط العائم فوق اللوحة.
  void Function(String tool)? openTool;

  void setTool(String? t) {
    tool = t;
    notifyListeners();
  }

  void startPicker(void Function(int color) cb) {
    picker = cb;
    brushOn = false;
    eraserLayerId = null;
    notifyListeners();
  }

  void stopPicker() {
    picker = null;
    notifyListeners();
  }
}

/// مقابض التحديد (بإحداثيات لوحة العرض): (النوع، الموضع).
/// del=حذف، s1/s2=تكبير، rot=تدوير، l/r/t/b=تغيير العرض أو الارتفاع وحده.
List<(String, Offset)> _handleList(Layer l, double vs) {
  if (l.locked || l.type == LayerType.draw) return const [];
  final sz = TextMetrics.size(l);
  final hw = sz.width / 2, hh = sz.height / 2;
  Offset p(double x, double y) => l.localToDoc(Offset(x, y)) * vs;
  final isText = l.type == LayerType.text;
  return [
    ('del', p(-hw, -hh)),
    (isText ? 'edit' : 's1', p(hw, -hh)),
    ('rot', p(hw, hh)),
    ('s2', p(-hw, hh)),
    ('r', p(hw, 0)),
    if (!isText) ('l', p(-hw, 0)),
    if (!isText) ('b', p(0, hh)),
    if (!isText) ('t', p(0, -hh)),
  ];
}

enum _Mode { none, drag, handle, erase, view, brush, pick }

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.images, required this.controller, required this.onEditText});
  final ImageStore images;
  final EditorController controller;
  final VoidCallback onEditText;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  _Mode _mode = _Mode.none;
  String? _target;
  bool _moved = false, _hadSelBefore = false;
  int _pc = 1;
  Offset _startFocal = Offset.zero, _startFocalLocal = Offset.zero, _startFocalGlobal = Offset.zero;
  double _x0 = 0, _y0 = 0, _s0 = 1, _r0 = 0, _d0 = 1, _a0 = 0;
  double _zoom0 = 1;
  Offset _pan0 = Offset.zero;
  Offset? _pickPoint; // موضع القطّارة (إحداثيات محلية للوحة)
  Offset _lastBrush = Offset.zero;
  double _lastVs = 1;
  String _hk = '';
  Layer? _e0;

  /// لقطة أولية لأعضاء المجموعة: id -> [x, y, scale, rotation]
  final Map<String, List<double>> _g0 = {};

  EditorController get ec => widget.controller;
  CanvasBloc get _bloc => context.read<CanvasBloc>();

  // ───────────── اختيار الطبقات ─────────────

  static bool _nearStroke(Layer l, Offset lp, double pad) {
    for (final s in l.strokes) {
      if (s.erase) continue;
      final r = s.width / 2 + pad;
      final n = s.pts.length ~/ 2;
      for (int i = 0; i < n; i++) {
        final a = Offset(s.pts[2 * i], s.pts[2 * i + 1]);
        if (i == n - 1) {
          if ((a - lp).distance <= r) return true;
          continue;
        }
        final b = Offset(s.pts[2 * i + 2], s.pts[2 * i + 3]);
        final ab = b - a;
        final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
        final ap = lp - a;
        final t = len2 == 0 ? 0.0 : ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0).toDouble();
        if ((a + ab * t - lp).distance <= r) return true;
      }
    }
    return false;
  }

  Layer? _hit(Doc doc, Offset p, double pad) {
    for (final l in doc.layers.reversed) {
      if (l.hidden || l.locked) continue;
      final lp = l.docToLocal(p);
      if (l.type == LayerType.draw) {
        if (_nearStroke(l, lp, pad)) return l;
        continue;
      }
      final s = TextMetrics.size(l);
      if (lp.dx.abs() <= s.width / 2 + pad && lp.dy.abs() <= s.height / 2 + pad) return l;
    }
    return null;
  }

  List<Layer> _members(Doc doc, Layer l) {
    final g = l.groupId;
    if (g == null) return [l];
    return doc.layers.where((x) => x.groupId == g && !x.locked).toList();
  }

  void _snapshot(Layer l, Offset focalDoc) {
    _startFocal = focalDoc;
    _x0 = l.x;
    _y0 = l.y;
    _s0 = l.scale;
    _r0 = l.rotation;
    _g0.clear();
    for (final m in _members(_bloc.state.doc, l)) {
      _g0[m.id] = [m.x, m.y, m.scale, m.rotation];
    }
  }

  /// يطبّق تحويلاً على الطبقة وكل أعضاء مجموعتها دفعة واحدة (حدث واحد).
  /// المحور = موضع الطبقة الهدف عند بدء اللمس: إزاحة ثم تدوير/تكبير حول المحور.
  void _applyTransform(double dx, double dy, double k, double dr) {
    final c = math.cos(dr), s = math.sin(dr);
    final px = _x0, py = _y0;
    final snap = Map<String, List<double>>.from(_g0);
    _bloc.add(DocMutated((doc) {
      snap.forEach((id, v) {
        final l = doc.byId(id);
        if (l == null) return;
        final vx = v[0] - px, vy = v[1] - py;
        l.x = px + dx + (vx * c - vy * s) * k;
        l.y = py + dy + (vx * s + vy * c) * k;
        l.scale = (v[2] * k).clamp(0.05, 20.0).toDouble();
        l.rotation = v[3] + dr;
      });
    }));
  }

  // ───────────── الشبكة والمغناطيس ─────────────

  static double gridStep(Doc d) => math.max(d.w, d.h) / 24;

  double _snapVal(double v, double center, double step) {
    if ((v - center).abs() < step * 0.2) return center;
    return (v / step).round() * step;
  }

  // ───────────── بدء اللمس ─────────────

  void _onStart(ScaleStartDetails d, double vs) {
    final st = _bloc.state;
    final p = d.localFocalPoint / vs;
    _moved = false;
    _pc = d.pointerCount;
    _startFocalLocal = d.localFocalPoint;
    _startFocalGlobal = d.focalPoint;
    _zoom0 = ec.zoom;
    _pan0 = ec.pan;

    // قطّارة الألوان
    if (ec.picker != null) {
      _mode = _Mode.pick;
      setState(() => _pickPoint = d.localFocalPoint);
      return;
    }

    // لمستان على الخلفية أو في وضع الرسم = تكبير/تحريك العرض
    final selNow = st.selected;
    if (d.pointerCount >= 2 && (ec.brushOn || selNow == null || selNow.locked)) {
      _mode = _Mode.view;
      return;
    }

    // الفرشاة
    if (ec.brushOn) {
      _startBrush(st, p);
      return;
    }

    // الممحاة اليدوية لطبقة صورة
    if (ec.eraserLayerId != null) {
      final l = st.doc.byId(ec.eraserLayerId);
      if (l != null && d.pointerCount == 1) {
        _mode = _Mode.erase;
        final lp = l.docToLocal(p);
        _bloc.add(StrokeStarted(l.id, ec.eraserRadius, lp.dx / l.w, lp.dy / l.w));
        return;
      }
    }

    final sel = st.selected;
    if (sel != null && !sel.locked && sel.type != LayerType.draw) {
      String? best;
      var bd = 32 / ec.zoom;
      for (final h in _handleList(sel, vs)) {
        final dist = (h.$2 - d.localFocalPoint).distance;
        if (dist < bd) {
          bd = dist;
          best = h.$1;
        }
      }
      if (best != null) {
        _mode = _Mode.handle;
        _hk = best;
        _target = sel.id;
        _snapshot(sel, p);
        _e0 = sel.clone();
        final v = p - Offset(sel.x, sel.y);
        _d0 = math.max(v.distance, 1);
        _a0 = v.direction;
        if (best != 'del' && best != 'edit') _bloc.add(const CheckpointRequested());
        return;
      }
    }

    final hit = (d.pointerCount >= 2 && sel != null && !sel.locked) ? sel : _hit(st.doc, p, 6 / vs / ec.zoom);
    if (hit == null) {
      // لمسة واحدة على فراغ: تحريك العرض إن كان مكبّراً، وإلا إلغاء التحديد عند الرفع
      _mode = ec.zoom > 1 ? _Mode.view : _Mode.none;
      return;
    }
    _hadSelBefore = hit.id == st.selectedId;
    if (!_hadSelBefore) {
      _bloc.add(LayerSelected(hit.id));
    }
    _target = hit.id;
    _mode = _Mode.drag;
    _snapshot(hit, p);
  }

  void _startBrush(CanvasState st, Offset p) {
    _mode = _Mode.brush;
    final doc = st.doc;
    final a = ((ec.brushOpacity.clamp(0.05, 1.0) * 255).round() << 24) | (ec.brushColor & 0x00FFFFFF);
    final l = st.selected;
    _lastBrush = p;
    if (l == null || l.type != LayerType.draw || l.locked) {
      // طبقة رسم جديدة بحجم التصميم (الضربة الأولى داخلها فتكون خطوة تراجع واحدة)
      final nl = Layer.create(LayerType.draw, name: 'رسم')
        ..x = doc.w / 2
        ..y = doc.h / 2
        ..w = doc.w
        ..h = doc.h;
      nl.strokes.add(BrushStroke(
        color: a,
        width: ec.brushWidth,
        dashed: ec.brushDashed,
        pts: [p.dx - doc.w / 2, p.dy - doc.h / 2],
      ));
      _target = nl.id;
      _bloc.add(LayerAdded(nl));
      return;
    }
    final lp = l.docToLocal(p);
    _target = l.id;
    _bloc.add(BrushStrokeStarted(
      l.id,
      BrushStroke(
        color: a,
        width: ec.brushWidth / l.scale,
        erase: ec.brushErase,
        dashed: ec.brushDashed,
        pts: [lp.dx, lp.dy],
      ),
    ));
  }

  // ───────────── التحريك ─────────────

  void _onUpdate(ScaleUpdateDetails d, double vs) {
    final st = _bloc.state;
    final p = d.localFocalPoint / vs;

    if (_mode == _Mode.pick) {
      setState(() => _pickPoint = d.localFocalPoint);
      return;
    }

    if (_mode == _Mode.view) {
      if ((d.focalPoint - _startFocalGlobal).distance > 4 || (d.scale - 1).abs() > 0.02) _moved = true;
      if (_moved) ec.setView(_zoom0 * d.scale, _pan0 + (d.focalPoint - _startFocalGlobal));
      return;
    }

    if (_mode == _Mode.brush) {
      final l = st.doc.byId(_target);
      if (l == null) return;
      if ((p - _lastBrush).distance < 1.2) return;
      _lastBrush = p;
      final lp = l.docToLocal(p);
      _bloc.add(BrushStrokeExtended(l.id, lp.dx, lp.dy));
      return;
    }

    if (_mode == _Mode.erase) {
      final l = st.doc.byId(ec.eraserLayerId);
      if (l == null) return;
      final lp = l.docToLocal(p);
      _bloc.add(StrokeExtended(l.id, lp.dx / l.w, lp.dy / l.w));
      return;
    }
    if (_mode == _Mode.none) {
      if (d.focalPointDelta.distance > 0 || (d.scale - 1).abs() > 0.01) _moved = true;
      return;
    }
    final l = st.doc.byId(_target);
    if (l == null) return;

    if (_mode == _Mode.handle) {
      if (_hk == 'del' || _hk == 'edit') return;
      _moved = true;
      if (_hk == 's1' || _hk == 's2') {
        final v = p - Offset(l.x, l.y);
        final k = (_s0 * v.distance / _d0).clamp(0.05, 20.0).toDouble() / _s0;
        _applyTransform(0, 0, k, 0);
      } else if (_hk == 'rot') {
        final v = p - Offset(l.x, l.y);
        _applyTransform(0, 0, 1, v.direction - _a0);
      } else {
        final e = _e0;
        if (e == null) return;
        final lp = e.docToLocal(p);
        final s0 = TextMetrics.size(e);
        var nw = s0.width, nh = s0.height;
        var cx = 0.0, cy = 0.0;
        switch (_hk) {
          case 'r':
            nw = math.max(24.0, lp.dx + s0.width / 2);
            cx = (nw - s0.width) / 2;
            break;
          case 'l':
            nw = math.max(24.0, s0.width / 2 - lp.dx);
            cx = -(nw - s0.width) / 2;
            break;
          case 'b':
            nh = math.max(24.0, lp.dy + s0.height / 2);
            cy = (nh - s0.height) / 2;
            break;
          case 't':
            nh = math.max(24.0, s0.height / 2 - lp.dy);
            cy = -(nh - s0.height) / 2;
            break;
        }
        final c = e.localToDoc(Offset(cx, cy));
        final horiz = _hk == 'l' || _hk == 'r';
        _bloc.add(LayerMutated((x) {
          x.x = c.dx;
          x.y = c.dy;
          if (horiz) {
            x.w = nw;
          } else {
            x.h = nh;
          }
        }, id: l.id));
      }
      return;
    }

    if (d.pointerCount != _pc) {
      _pc = d.pointerCount;
      _snapshot(l, p);
    }
    if (!_moved) {
      final slop = (d.localFocalPoint - _startFocalLocal).distance;
      if (slop < 6 && (d.scale - 1).abs() < 0.02 && d.rotation.abs() < 0.03) return;
      _moved = true;
      _bloc.add(const CheckpointRequested());
      // إعادة ضبط نقطة البدء عند تجاوز عتبة اللمس: يبدأ العنصر الحركة من مكانه بدون قفزة
      if (_pc < 2) _snapshot(l, p);
    }
    final delta = p - _startFocal;
    var dx = delta.dx, dy = delta.dy;
    final two = _pc >= 2;
    if (!two && ec.snap) {
      final step = gridStep(st.doc);
      dx = _snapVal(_x0 + dx, st.doc.w / 2, step) - _x0;
      dy = _snapVal(_y0 + dy, st.doc.h / 2, step) - _y0;
    }
    final k = two ? (_s0 * d.scale).clamp(0.05, 20.0).toDouble() / _s0 : 1.0;
    final dr = two ? d.rotation : 0.0;
    _applyTransform(dx, dy, k, dr);
  }

  void _onEnd(ScaleEndDetails d) {
    final wasMode = _mode;
    _mode = _Mode.none;
    if (wasMode == _Mode.pick) {
      final pt = _pickPoint;
      setState(() => _pickPoint = null);
      if (pt != null) _samplePick(pt);
      return;
    }
    if (wasMode == _Mode.brush) return;
    if (wasMode == _Mode.handle) {
      if (_hk == 'del' && !_moved) _bloc.add(const LayerRemoved());
      if (_hk == 'edit' && !_moved) widget.onEditText();
      return;
    }
    if ((wasMode == _Mode.none || wasMode == _Mode.view) && !_moved) {
      _bloc.add(const LayerSelected(null));
    } else if (wasMode == _Mode.drag && !_moved && _hadSelBefore) {
      final l = _bloc.state.doc.byId(_target);
      if (l != null && l.type == LayerType.text && l.font != 'MaterialIcons') widget.onEditText();
    }
  }

  /// يأخذ لون البكسل الظاهر في التصميم عند النقطة (إحداثيات محلية للوحة).
  Future<void> _samplePick(Offset localPt) async {
    final cb = ec.picker;
    ec.stopPicker();
    if (cb == null) return;
    try {
      final doc = _bloc.state.doc;
      final vs = _lastVs;
      final img = await ExportService.render(doc, widget.images, scale: 0.6);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null || vs <= 0) return;
      final k = img.width / doc.w;
      final x = ((localPt.dx / vs) * k).round().clamp(0, img.width - 1).toInt();
      final y = ((localPt.dy / vs) * k).round().clamp(0, img.height - 1).toInt();
      final i = (y * img.width + x) * 4;
      final r = bd.getUint8(i), g = bd.getUint8(i + 1), b = bd.getUint8(i + 2);
      cb(0xFF000000 | (r << 16) | (g << 8) | b);
    } catch (_) {}
  }

  // ───────────── البناء ─────────────

  Widget _roundBtn(IconData icon, VoidCallback onTap, {bool on = false, String? tip}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tip ?? '',
        child: Material(
          color: on ? AppColors.accent : Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap, {bool yellow = false, bool white = false}) => InkWell(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 40,
          color: yellow ? AppColors.accent2 : Colors.transparent,
          child: Icon(icon, size: 22, color: yellow ? Colors.black : (white ? Colors.white : AppColors.accent2)),
        ),
      );

  Widget _statusChip(String text, VoidCallback onClose) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Material(
          color: AppColors.accent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                const SizedBox(width: 6),
                const Icon(Icons.close, size: 14, color: Colors.white),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ec,
      builder: (context, _) => BlocBuilder<CanvasBloc, CanvasState>(
        builder: (context, st) {
          return LayoutBuilder(builder: (context, cons) {
            ec.viewport = Size(cons.maxWidth, cons.maxHeight);
            final doc = st.doc;
            final aw = math.max(40.0, cons.maxWidth - 24), ah = math.max(40.0, cons.maxHeight - 24);
            final vs = math.min(aw / doc.w, ah / doc.h);
            _lastVs = vs;
            final w = doc.w * vs, h = doc.h * vs;
            final sel = st.selected;
            final gid = sel?.groupId;
            final others = gid == null
                ? const <Layer>[]
                : doc.layers.where((x) => x.groupId == gid && x.id != sel!.id && !x.hidden).toList();
            final canvas = Container(
              width: w,
              height: h,
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 18)]),
              child: IgnorePointer(
                ignoring: ec.tool != null && ec.picker == null,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) => _onStart(d, vs),
                onScaleUpdate: (d) => _onUpdate(d, vs),
                onScaleEnd: _onEnd,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: PosterPainter(doc: doc, images: widget.images, revision: st.revision)),
                    ),
                    if (ec.showGrid)
                      Positioned.fill(
                        child: IgnorePointer(child: CustomPaint(painter: _GridPainter(gridStep(doc) * vs, ec.zoom))),
                      ),
                    if (sel != null && !sel.hidden && ec.tool == null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SelectionPainter(sel, others, vs, ec.eraserLayerId == sel.id, st.revision, ec.zoom),
                          ),
                        ),
                      ),
                    if (_pickPoint != null)
                      Positioned(
                        left: _pickPoint!.dx - 16,
                        top: _pickPoint!.dy - 16,
                        child: const IgnorePointer(child: Icon(Icons.add_circle_outline, size: 32, color: Colors.white)),
                      ),
                  ],
                ),
              ),
              ),
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: Center(
                      child: Transform.translate(
                        offset: ec.pan,
                        child: Transform.scale(scale: ec.zoom, child: canvas),
                      ),
                    ),
                  ),
                ),
                if (sel != null && !sel.locked && !ec.brushOn && ec.picker == null && ec.tool == null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Material(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _miniBtn(Icons.close, () => _bloc.add(const LayerSelected(null)), yellow: true),
                              _miniBtn(Icons.open_with, () => ec.openTool?.call('pos')),
                              if (sel.type == LayerType.text) ...[
                                InkWell(
                                  onTap: () => ec.openTool?.call('fsize'),
                                  child: SizedBox(
                                    width: 44,
                                    height: 40,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('${sel.fontSize.round()}', style: const TextStyle(fontSize: 10.5, color: Colors.white)),
                                        const Icon(Icons.text_fields, size: 18, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                                _miniBtn(
                                  sel.align == 0 ? Icons.format_align_left : (sel.align == 2 ? Icons.format_align_right : Icons.format_align_center),
                                  () => _bloc.add(LayerMutated((x) => x.align = (x.align + 1) % 3, id: sel.id, commit: true)),
                                  white: true,
                                ),
                                _miniBtn(Icons.format_bold, () => _bloc.add(LayerMutated((x) => x.bold = !x.bold, id: sel.id, commit: true)), white: true),
                                _miniBtn(Icons.format_italic, () => _bloc.add(LayerMutated((x) => x.italic = !x.italic, id: sel.id, commit: true)), white: true),
                              ],
                              _miniBtn(Icons.copy, () => _bloc.add(const LayerDuplicated()), white: true),
                              if (sel.type != LayerType.text)
                                _miniBtn(Icons.fullscreen, () {
                                  final z = TextMetrics.size(sel);
                                  final k = math.min(doc.w / z.width, doc.h / z.height);
                                  _bloc.add(LayerMutated((x) {
                                    x.x = doc.w / 2;
                                    x.y = doc.h / 2;
                                    x.rotation = 0;
                                    x.scale = k;
                                  }, id: sel.id, commit: true));
                                }, white: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (ec.picker != null)
                  _statusChip('اضغط على التصميم لالتقاط لون', ec.stopPicker)
                else if (ec.brushOn)
                  _statusChip('الفرشاة مفعّلة — إنهاء', () => ec.update(() => ec.brushOn = false)),
              ],
            );
          });
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.step, this.zoom);
  final double step, zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 0.8 / zoom;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final c = Paint()
      ..color = const Color(0xAAFF5C6C)
      ..strokeWidth = 1.2 / zoom;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), c);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), c);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.step != step || old.zoom != zoom;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.layer, this.others, this.vs, this.erasing, this.revision, this.zoom);
  final Layer layer;
  final List<Layer> others;
  final double vs;
  final bool erasing;
  final int revision;
  final double zoom;

  List<Offset> _corners(Layer l) {
    final s = TextMetrics.size(l);
    final hw = s.width / 2, hh = s.height / 2;
    return [Offset(-hw, -hh), Offset(hw, -hh), Offset(hw, hh), Offset(-hw, hh)].map((o) => l.localToDoc(o) * vs).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final color = erasing ? AppColors.danger : AppColors.accent;
    // أعضاء المجموعة الآخرون: إطار خفيف
    for (final o in others) {
      canvas.drawPath(
        Path()..addPolygon(_corners(o), true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / zoom
          ..color = color.withValues(alpha: 0.45),
      );
    }
    final pts = _corners(layer);
    canvas.drawPath(
      Path()..addPolygon(pts, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / zoom
        ..color = color,
    );
    if (!erasing) {
      const dark = Color(0xFF262626);
      final yellow = AppColors.accent2;
      for (final h in _handleList(layer, vs)) {
        final kind = h.$1;
        final c = h.$2;
        final fillP = Paint()..color = dark;
        final lineP = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / zoom
          ..color = yellow;
        if (kind == 'l' || kind == 'r' || kind == 't' || kind == 'b') {
          final wide = kind == 't' || kind == 'b';
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(layer.rotation);
          final r = Rect.fromCenter(center: Offset.zero, width: (wide ? 22 : 9) / zoom, height: (wide ? 9 : 22) / zoom);
          canvas.drawRect(r, fillP);
          canvas.drawRect(r, lineP);
          canvas.restore();
        } else {
          final isDel = kind == 'del';
          final r = Rect.fromCenter(center: c, width: 24 / zoom, height: 24 / zoom);
          canvas.drawRect(r, Paint()..color = isDel ? yellow : dark);
          canvas.drawRect(r, lineP);
          final ic = isDel ? Icons.close : (kind == 'rot' ? Icons.sync : (kind == 'edit' ? Icons.title : Icons.open_in_full));
          final tp = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(ic.codePoint),
              style: TextStyle(fontFamily: ic.fontFamily, package: ic.fontPackage, fontSize: 17 / zoom, color: isDel ? Colors.black : yellow),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) => true;
}
