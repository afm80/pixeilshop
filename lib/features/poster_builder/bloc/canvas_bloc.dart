import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/font_service.dart';
import '../model/doc.dart';
import '../model/layer.dart';

// ───────────────────────────── الأحداث ─────────────────────────────

sealed class CanvasEvent {
  const CanvasEvent();
}

class CanvasLoaded extends CanvasEvent {
  const CanvasLoaded(this.doc);
  final Doc doc;
}

class LayerAdded extends CanvasEvent {
  const LayerAdded(this.layer);
  final Layer layer;
}

/// "اضف نص 'عرض خاص'" ← CanvasBloc.addTextLayer('عرض خاص')
class TextLayerAdded extends CanvasEvent {
  const TextLayerAdded(this.text, {this.font, this.color, this.fontSize, this.width, this.bold});
  final String text;
  final String? font;
  final int? color;
  final double? fontSize;
  final double? width; // عرض الصندوق؛ الافتراضي 80% من التصميم
  final bool? bold;
}

class ShapeLayerAdded extends CanvasEvent {
  const ShapeLayerAdded(this.kind, {this.color});
  final ShapeKind kind;
  final int? color;
}

class ImageLayerAdded extends CanvasEvent {
  const ImageLayerAdded(this.path, this.width, this.height);
  final String path;
  final int width, height;
}

class LayerSelected extends CanvasEvent {
  const LayerSelected(this.id);
  final String? id;
}

/// تعديل طبقة. [commit] = حفظ نقطة تراجع قبل التعديل. [id] = null يعني المحددة.
class LayerMutated extends CanvasEvent {
  const LayerMutated(this.apply, {this.id, this.commit = false});
  final void Function(Layer l) apply;
  final String? id;
  final bool commit;
}

class DocMutated extends CanvasEvent {
  const DocMutated(this.apply, {this.commit = false});
  final void Function(Doc d) apply;
  final bool commit;
}

class CheckpointRequested extends CanvasEvent {
  const CheckpointRequested();
}

class LayerRemoved extends CanvasEvent {
  const LayerRemoved([this.id]);
  final String? id;
}

class LayerDuplicated extends CanvasEvent {
  const LayerDuplicated([this.id]);
  final String? id;
}

class LayerZMoved extends CanvasEvent {
  const LayerZMoved(this.id, {this.toFront = false, this.toBack = false, this.delta = 0});
  final String id;
  final bool toFront, toBack;
  final int delta;
}

class LayerReordered extends CanvasEvent {
  const LayerReordered(this.oldIndex, this.newIndex);
  final int oldIndex, newIndex; // فهارس في قائمة الطبقات الفعلية
}

class UndoRequested extends CanvasEvent {
  const UndoRequested();
}

class RedoRequested extends CanvasEvent {
  const RedoRequested();
}

class ImageReplaced extends CanvasEvent {
  const ImageReplaced(this.id, this.result);
  final String id;
  final ImageResult result;
}

class StrokeStarted extends CanvasEvent {
  const StrokeStarted(this.id, this.r, this.x, this.y);
  final String id;
  final double r, x, y; // x,y محلية مقسومة على عرض الطبقة
}

class StrokeExtended extends CanvasEvent {
  const StrokeExtended(this.id, this.x, this.y);
  final String id;
  final double x, y;
}

class FontsReady extends CanvasEvent {
  const FontsReady();
}

// ───────────────────────────── الحالة ─────────────────────────────

class CanvasState extends Equatable {
  const CanvasState({required this.doc, this.selectedId, this.revision = 0, this.canUndo = false, this.canRedo = false});
  final Doc doc;
  final String? selectedId;
  final int revision;
  final bool canUndo, canRedo;

  Layer? get selected => doc.byId(selectedId);

  CanvasState copyWith({Doc? doc, Object? selectedId = _keep, int? revision, bool? canUndo, bool? canRedo}) => CanvasState(
        doc: doc ?? this.doc,
        selectedId: identical(selectedId, _keep) ? this.selectedId : selectedId as String?,
        revision: revision ?? this.revision,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );

  @override
  List<Object?> get props => [selectedId, revision, canUndo, canRedo, doc.id];
}

const Object _keep = Object();

// ───────────────────────────── البلوك ─────────────────────────────

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  CanvasBloc(Doc doc) : super(CanvasState(doc: doc)) {
    on<CanvasLoaded>((e, emit) {
      _undo.clear();
      _redo.clear();
      emit(CanvasState(doc: e.doc, revision: state.revision + 1));
      _watchFonts();
    });
    on<LayerAdded>((e, emit) {
      _checkpoint();
      state.doc.layers.add(e.layer);
      _emit(emit, selectedId: e.layer.id);
    });
    on<TextLayerAdded>((e, emit) {
      _checkpoint();
      final d = state.doc;
      final l = Layer.create(LayerType.text, name: 'نص');
      l.text = e.text;
      l.x = d.w / 2;
      l.y = d.h / 2;
      l.w = e.width ?? d.w * 0.8;
      l.fontSize = e.fontSize ?? d.w * 0.09;
      if (e.bold != null) l.bold = e.bold!;
      if (e.font != null) l.font = e.font!;
      if (e.color != null) l.color = e.color!;
      d.layers.add(l);
      FontService.preload([l.font]);
      _emit(emit, selectedId: l.id);
      _watchFonts();
    });
    on<ShapeLayerAdded>((e, emit) {
      _checkpoint();
      final d = state.doc;
      final l = Layer.create(LayerType.shape, name: 'شكل');
      l.shape = e.kind;
      l.x = d.w / 2;
      l.y = d.h / 2;
      final s = d.w * 0.35;
      l.w = e.kind == ShapeKind.line ? d.w * 0.5 : s;
      l.h = e.kind == ShapeKind.line ? 40 : s;
      l.color = e.color ?? 0xFF8B6CFF;
      d.layers.add(l);
      _emit(emit, selectedId: l.id);
    });
    on<ImageLayerAdded>((e, emit) {
      _checkpoint();
      final d = state.doc;
      final l = Layer.create(LayerType.image, name: 'صورة');
      l.path = e.path;
      final k = math.min(d.w * 0.85 / e.width, d.h * 0.85 / e.height);
      l.w = e.width * k;
      l.h = e.height * k;
      l.x = d.w / 2;
      l.y = d.h / 2;
      d.layers.add(l);
      _emit(emit, selectedId: l.id);
    });
    on<LayerSelected>((e, emit) {
      emit(state.copyWith(selectedId: e.id, revision: state.revision + 1));
    });
    on<LayerMutated>((e, emit) {
      final l = state.doc.byId(e.id ?? state.selectedId);
      if (l == null) return;
      if (e.commit) _checkpoint();
      e.apply(l);
      if (l.type == LayerType.text) {
        FontService.preload([l.font]);
        _watchFonts();
      }
      _emit(emit);
    });
    on<DocMutated>((e, emit) {
      if (e.commit) _checkpoint();
      e.apply(state.doc);
      _emit(emit);
    });
    on<CheckpointRequested>((e, emit) {
      _checkpoint();
      _emit(emit);
    });
    on<LayerRemoved>((e, emit) {
      final id = e.id ?? state.selectedId;
      if (id == null) return;
      final i = state.doc.indexOf(id);
      if (i < 0) return;
      _checkpoint();
      state.doc.layers.removeAt(i);
      _emit(emit, selectedId: state.selectedId == id ? null : state.selectedId);
    });
    on<LayerDuplicated>((e, emit) {
      final l = state.doc.byId(e.id ?? state.selectedId);
      if (l == null) return;
      _checkpoint();
      final c = l.clone(newId: true);
      c.x += 40;
      c.y += 40;
      state.doc.layers.insert(state.doc.indexOf(l.id) + 1, c);
      _emit(emit, selectedId: c.id);
    });
    on<LayerZMoved>((e, emit) {
      final layers = state.doc.layers;
      final i = state.doc.indexOf(e.id);
      if (i < 0) return;
      _checkpoint();
      final l = layers.removeAt(i);
      int n;
      if (e.toFront) {
        n = layers.length;
      } else if (e.toBack) {
        n = 0;
      } else {
        n = (i + e.delta).clamp(0, layers.length).toInt();
      }
      layers.insert(n, l);
      _emit(emit);
    });
    on<LayerReordered>((e, emit) {
      final layers = state.doc.layers;
      if (e.oldIndex < 0 || e.oldIndex >= layers.length) return;
      _checkpoint();
      final l = layers.removeAt(e.oldIndex);
      layers.insert(e.newIndex.clamp(0, layers.length).toInt(), l);
      _emit(emit);
    });
    on<UndoRequested>((e, emit) {
      if (_undo.isEmpty) return;
      _redo.add(jsonEncode(state.doc.toJson()));
      _restore(_undo.removeLast(), emit);
    });
    on<RedoRequested>((e, emit) {
      if (_redo.isEmpty) return;
      _undo.add(jsonEncode(state.doc.toJson()));
      _restore(_redo.removeLast(), emit);
    });
    on<ImageReplaced>((e, emit) {
      final l = state.doc.byId(e.id);
      if (l == null) return;
      _checkpoint();
      final r = e.result;
      // نحافظ على موضع العنصر المرئي: المنطقة المقصوصة تبقى في مكانها
      final oldW = l.w, oldH = l.h;
      final cx = ((r.normLeft + r.normWidth / 2) - 0.5) * oldW;
      final cy = ((r.normTop + r.normHeight / 2) - 0.5) * oldH;
      final shift = l.localToDoc(Offset(cx, cy));
      l.x = shift.dx;
      l.y = shift.dy;
      l.w = oldW * r.normWidth;
      l.h = oldH * r.normHeight;
      l.path = r.path;
      l.erase = [];
      _emit(emit);
    });
    on<StrokeStarted>((e, emit) {
      final l = state.doc.byId(e.id);
      if (l == null) return;
      _checkpoint();
      l.erase.add(EraseStroke(e.r, [e.x, e.y]));
      _emit(emit);
    });
    on<StrokeExtended>((e, emit) {
      final l = state.doc.byId(e.id);
      if (l == null || l.erase.isEmpty) return;
      l.erase.last.pts.addAll([e.x, e.y]);
      _emit(emit);
    });
    on<FontsReady>((e, emit) {
      FontService.epoch++;
      _emit(emit);
    });
    _watchFonts();
  }

  final List<String> _undo = [];
  final List<String> _redo = [];
  bool _watching = false;

  void _checkpoint() {
    _undo.add(jsonEncode(state.doc.toJson()));
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _emit(Emitter<CanvasState> emit, {Object? selectedId = _keep}) {
    emit(state.copyWith(
      selectedId: selectedId,
      revision: state.revision + 1,
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    ));
  }

  void _restore(String json, Emitter<CanvasState> emit) {
    final d = Doc.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    final sel = d.indexOf(state.selectedId ?? '') >= 0 ? state.selectedId : null;
    emit(CanvasState(
      doc: d,
      selectedId: sel,
      revision: state.revision + 1,
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    ));
  }

  /// يعيد رسم اللوحة عند اكتمال تحميل خطوط جوجل.
  void _watchFonts() {
    if (_watching) return;
    _watching = true;
    FontService.preload(state.doc.layers.where((l) => l.type == LayerType.text).map((l) => l.font)).then((_) {
      _watching = false;
      if (!isClosed) add(const FontsReady());
    });
  }

  // اختصارات برمجية (تُستدعى من المساعد الذكي وغيره)
  void addTextLayer(String text) => add(TextLayerAdded(text));
}
