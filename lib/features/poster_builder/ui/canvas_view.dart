import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/image_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/poster_painter.dart';
import '../../../core/utils/text_metrics.dart';
import '../bloc/canvas_bloc.dart';
import '../model/doc.dart';
import '../model/layer.dart';

/// حالة أدوات المحرر المشتركة (الممحاة، التبويب الحالي).
class EditorController extends ChangeNotifier {
  String? eraserLayerId;
  double eraserRadius = 0.04; // نسبة من عرض الطبقة
  int tab = 0;

  void startEraser(String id) {
    eraserLayerId = id;
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

  void setTab(int t) {
    tab = t;
    notifyListeners();
  }
}

enum _Mode { none, drag, handle, erase }

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
  Offset _startFocal = Offset.zero, _startFocalLocal = Offset.zero;
  double _x0 = 0, _y0 = 0, _s0 = 1, _r0 = 0, _d0 = 1, _a0 = 0;

  CanvasBloc get _bloc => context.read<CanvasBloc>();

  Layer? _hit(Doc doc, Offset p, double pad) {
    for (final l in doc.layers.reversed) {
      if (l.hidden || l.locked) continue;
      final lp = l.docToLocal(p);
      final s = TextMetrics.size(l);
      if (lp.dx.abs() <= s.width / 2 + pad && lp.dy.abs() <= s.height / 2 + pad) return l;
    }
    return null;
  }

  Offset _handlePos(Layer l) {
    final s = TextMetrics.size(l);
    return l.localToDoc(Offset(s.width / 2, s.height / 2));
  }

  void _snapshot(Layer l, Offset focalDoc) {
    _startFocal = focalDoc;
    _x0 = l.x;
    _y0 = l.y;
    _s0 = l.scale;
    _r0 = l.rotation;
  }

  void _onStart(ScaleStartDetails d, double vs) {
    final st = _bloc.state;
    final p = d.localFocalPoint / vs;
    _moved = false;
    _pc = d.pointerCount;
    _startFocalLocal = d.localFocalPoint;
    final ec = widget.controller;

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
    if (sel != null && !sel.locked) {
      final hp = _handlePos(sel);
      if ((hp * vs - d.localFocalPoint).distance < 30) {
        _mode = _Mode.handle;
        _target = sel.id;
        _snapshot(sel, p);
        final v = p - Offset(sel.x, sel.y);
        _d0 = math.max(v.distance, 1);
        _a0 = v.direction;
        _bloc.add(const CheckpointRequested());
        return;
      }
    }

    final hit = (d.pointerCount >= 2 && sel != null && !sel.locked) ? sel : _hit(st.doc, p, 6 / vs);
    if (hit == null) {
      _mode = _Mode.none;
      return;
    }
    _hadSelBefore = hit.id == st.selectedId;
    if (!_hadSelBefore) _bloc.add(LayerSelected(hit.id));
    _target = hit.id;
    _mode = _Mode.drag;
    _snapshot(hit, p);
  }

  void _onUpdate(ScaleUpdateDetails d, double vs) {
    final st = _bloc.state;
    final p = d.localFocalPoint / vs;

    if (_mode == _Mode.erase) {
      final l = st.doc.byId(widget.controller.eraserLayerId);
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
      final v = p - Offset(l.x, l.y);
      final ns = (_s0 * v.distance / _d0).clamp(0.05, 20.0).toDouble();
      final nr = _r0 + (v.direction - _a0);
      _moved = true;
      _bloc.add(LayerMutated((x) {
        x.scale = ns;
        x.rotation = nr;
      }, id: l.id));
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
    }
    final delta = p - _startFocal;
    final nx = _x0 + delta.dx, ny = _y0 + delta.dy;
    final two = _pc >= 2;
    final ns = (_s0 * d.scale).clamp(0.05, 20.0).toDouble();
    final nr = _r0 + d.rotation;
    _bloc.add(LayerMutated((x) {
      x.x = nx;
      x.y = ny;
      if (two) {
        x.scale = ns;
        x.rotation = nr;
      }
    }, id: l.id));
  }

  void _onEnd(ScaleEndDetails d) {
    final wasMode = _mode;
    _mode = _Mode.none;
    if (wasMode == _Mode.none && !_moved) {
      _bloc.add(const LayerSelected(null));
    } else if (wasMode == _Mode.drag && !_moved && _hadSelBefore) {
      final l = _bloc.state.doc.byId(_target);
      if (l != null && l.type == LayerType.text) widget.onEditText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => BlocBuilder<CanvasBloc, CanvasState>(
        builder: (context, st) {
          return LayoutBuilder(builder: (context, cons) {
            final doc = st.doc;
            final aw = math.max(40.0, cons.maxWidth - 24), ah = math.max(40.0, cons.maxHeight - 24);
            final vs = math.min(aw / doc.w, ah / doc.h);
            final w = doc.w * vs, h = doc.h * vs;
            final sel = st.selected;
            return Center(
              child: Container(
                width: w,
                height: h,
                decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 18)]),
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
                      if (sel != null && !sel.hidden)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _SelectionPainter(sel, vs, widget.controller.eraserLayerId == sel.id, st.revision),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.layer, this.vs, this.erasing, this.revision);
  final Layer layer;
  final double vs;
  final bool erasing;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final s = TextMetrics.size(layer);
    final hw = s.width / 2, hh = s.height / 2;
    final pts = [Offset(-hw, -hh), Offset(hw, -hh), Offset(hw, hh), Offset(-hw, hh)].map((o) => layer.localToDoc(o) * vs).toList();
    final path = Path()..addPolygon(pts, true);
    final color = erasing ? AppColors.danger : AppColors.accent;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color,
    );
    if (!layer.locked && !erasing) {
      final hp = pts[2];
      canvas.drawCircle(hp, 11, Paint()..color = Colors.white);
      canvas.drawCircle(
        hp,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
      final tp = TextPainter(
        text: const TextSpan(text: '⤡', style: TextStyle(fontSize: 14, color: Colors.black)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, hp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) => true;
}
