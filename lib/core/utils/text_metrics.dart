import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../features/poster_builder/model/layer.dart';
import '../services/font_service.dart';
import 'arabic.dart';

/// بناء TextPainter لطبقة نصية وقياس أبعاد الطبقات.
class TextMetrics {
  static final Map<int, Size> _cache = {};

  static TextPainter build(Layer l, {required bool stroke, bool whiteFill = false}) {
    final Paint? fg = stroke
        ? (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = l.strokeW * 2
          ..strokeJoin = StrokeJoin.round
          ..color = Color(l.strokeColor))
        : null;
    final style = FontService.style(
      l.font,
      size: l.fontSize,
      bold: l.bold,
      italic: l.italic,
      letterSpacing: l.letterSpacing,
      height: l.lineHeight,
      color: whiteFill ? const Color(0xFFFFFFFF) : Color(l.color),
      foreground: fg,
    );
    final txt = l.text.isEmpty ? ' ' : l.text;
    final align = l.align == 0 ? TextAlign.left : (l.align == 2 ? TextAlign.right : TextAlign.center);
    final tp = TextPainter(
      text: TextSpan(text: txt, style: style),
      textDirection: isRtlText(txt) ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      textAlign: align,
    );
    tp.layout(minWidth: l.w, maxWidth: l.w);
    return tp;
  }

  /// أبعاد الصندوق المحلي للطبقة (قبل scale).
  static Size size(Layer l) {
    switch (l.type) {
      case LayerType.text:
        final key = Object.hash(l.text, l.font, l.fontSize, l.bold, l.italic, l.letterSpacing, l.lineHeight, l.w,
            FontService.epoch);
        final c = _cache[key];
        if (c != null) return c;
        final tp = build(l, stroke: false);
        final s = Size(l.w, math.max(tp.height, 12));
        if (_cache.length > 400) _cache.clear();
        _cache[key] = s;
        return s;
      case LayerType.image:
      case LayerType.shape:
      case LayerType.draw:
        return Size(l.w, l.h);
    }
  }
}
