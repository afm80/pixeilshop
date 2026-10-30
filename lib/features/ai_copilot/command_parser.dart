import '../../core/services/tflite_service.dart';
import '../../core/utils/arabic.dart';
import '../poster_builder/model/layer.dart';

/// أوامر المساعد الذكي (تُحلَّل محلياً بالـ Regex بدون أي خادم).
sealed class CopilotCommand {
  const CopilotCommand();
}

class RemoveBackgroundCmd extends CopilotCommand {
  const RemoveBackgroundCmd();
}

class AddTextCmd extends CopilotCommand {
  const AddTextCmd(this.text);
  final String text;
}

class AddShapeCmd extends CopilotCommand {
  const AddShapeCmd(this.kind);
  final ShapeKind kind;
}

class StyleCmd extends CopilotCommand {
  const StyleCmd(this.kind);
  final StyleKind kind;
}

class FilterCmd extends CopilotCommand {
  const FilterCmd(this.preset);
  final int preset; // 0 = إزالة الفلتر
}

enum AdjustParam { brightness, contrast, saturation, temperature, vignette, fade }

class AdjustCmd extends CopilotCommand {
  const AdjustCmd(this.param, this.amount, {required this.relative});
  final AdjustParam param;
  final double amount; // 0..1 (نسبة)، موجب/سالب إن كانت نسبية
  final bool relative;
}

class ShadowCmd extends CopilotCommand {
  const ShadowCmd(this.on);
  final bool on;
}

class UndoCmd extends CopilotCommand {
  const UndoCmd();
}

class RedoCmd extends CopilotCommand {
  const RedoCmd();
}

class DeleteLayerCmd extends CopilotCommand {
  const DeleteLayerCmd();
}

class DuplicateCmd extends CopilotCommand {
  const DuplicateCmd();
}

class FlipCmd extends CopilotCommand {
  const FlipCmd();
}

class ZOrderCmd extends CopilotCommand {
  const ZOrderCmd({required this.front});
  final bool front;
}

class ExportCmd extends CopilotCommand {
  const ExportCmd();
}

class BgColorCmd extends CopilotCommand {
  const BgColorCmd(this.color);
  final int color;
}

class TextColorCmd extends CopilotCommand {
  const TextColorCmd(this.color);
  final int color;
}

class UnknownCmd extends CopilotCommand {
  const UnknownCmd(this.text);
  final String text;
}

class CommandParser {
  static const _removeVerbs = [
    'ازل', 'ازاله', 'احذف', 'حذف', 'شيل', 'امسح', 'افصل', 'اعزل', 'عزل', 'قص', 'بدون', //
    'remove', 'delete', 'erase', 'cut', 'clear', 'without',
  ];

  static const _colors = <String, int>{
    'احمر': 0xFFE53935, 'حمراء': 0xFFE53935, 'red': 0xFFE53935,
    'ازرق': 0xFF1E88E5, 'زرقاء': 0xFF1E88E5, 'blue': 0xFF1E88E5,
    'اخضر': 0xFF43A047, 'خضراء': 0xFF43A047, 'green': 0xFF43A047,
    'اصفر': 0xFFFDD835, 'صفراء': 0xFFFDD835, 'yellow': 0xFFFDD835,
    'برتقالي': 0xFFFB8C00, 'برتقاليه': 0xFFFB8C00, 'orange': 0xFFFB8C00,
    'بنفسجي': 0xFF8E24AA, 'ارجواني': 0xFF8E24AA, 'بنفسجيه': 0xFF8E24AA, 'purple': 0xFF8E24AA,
    'وردي': 0xFFEC407A, 'زهري': 0xFFEC407A, 'ورديه': 0xFFEC407A, 'pink': 0xFFEC407A,
    'ابيض': 0xFFFFFFFF, 'بيضاء': 0xFFFFFFFF, 'white': 0xFFFFFFFF,
    'اسود': 0xFF111111, 'سوداء': 0xFF111111, 'black': 0xFF111111,
    'ذهبي': 0xFFFFC107, 'ذهبيه': 0xFFFFC107, 'gold': 0xFFFFC107,
    'رمادي': 0xFF9E9E9E, 'رماديه': 0xFF9E9E9E, 'gray': 0xFF9E9E9E, 'grey': 0xFF9E9E9E,
    'بني': 0xFF795548, 'brown': 0xFF795548,
    'سماوي': 0xFF00BCD4, 'cyan': 0xFF00BCD4, 'turquoise': 0xFF00BCD4,
    'فضي': 0xFFC0C0C0, 'silver': 0xFFC0C0C0,
  };

  /// (فهرس الفلتر في ColorMatrices.presets) ← كلمات تدل عليه
  static const _filters = <int, List<String>>{
    1: ['سينمايي', 'سينما', 'cinematic', 'cinema', 'movie'],
    2: ['دافي', 'دافيه', 'warm'],
    3: ['بارد', 'بارده', 'cool', 'cold'],
    5: ['نوار', 'noir'],
    6: ['سيبيا', 'sepia'],
    7: ['قديم', 'قديمه', 'كلاسيك', 'كلاسيكي', 'فينتج', 'vintage', 'retro', 'ريترو'],
    8: ['حيوي', 'حيويه', 'vivid', 'زاهي'],
    9: ['مطفي', 'matte', 'ماط'],
    10: ['ذهبي', 'ذهبيه', 'golden', 'غروب'],
    11: ['سايبر', 'cyber', 'نيون', 'neon'],
    12: ['باستيل', 'pastel'],
    13: ['دراما', 'درامي', 'دراميه', 'dramatic', 'drama'],
  };

  static Set<String> _stems(String n) {
    final out = <String>{};
    for (final t in n.split(RegExp(r'[^؀-ۿa-z0-9&]+'))) {
      if (t.isEmpty) continue;
      out.add(t);
      for (final p in ['وال', 'بال', 'لل', 'ال', 'و', 'ب', 'ل']) {
        if (t.startsWith(p) && t.length > p.length + 1) out.add(t.substring(p.length));
      }
    }
    return out;
  }

  static int? _findColor(Set<String> stems) {
    for (final e in _colors.entries) {
      if (stems.contains(e.key)) return e.value;
    }
    return null;
  }

  static CopilotCommand parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return const UnknownCmd('');
    final n = normalizeKeepLength(raw);
    final stems = _stems(n);
    bool has(List<String> w) => w.any(stems.contains);
    bool phrase(List<String> p) => p.any(n.contains);

    // ── إضافة نص ──
    final quoted = RegExp(
      r'''(?:اضف|ضيف|اكتب|اضافه|add|write|insert|type)\s*(?:نص|كلمه|عباره|جمله|text|word)?\s*[«»"“”'‘’](.+?)[«»"“”'‘’]''',
    ).firstMatch(n);
    if (quoted != null) {
      final e = quoted.end - 1;
      final t = raw.substring(e - quoted.group(1)!.length, e).trim();
      if (t.isNotEmpty) return AddTextCmd(t);
    }
    final unquoted = RegExp(r'(?:اضف|ضيف|اكتب|add|write|type)\s+(?:نص|كلمه|عباره|جمله|text|word)\s+(.+)$').firstMatch(n);
    if (unquoted != null) {
      final t = raw.substring(unquoted.end - unquoted.group(1)!.length).trim();
      if (t.isNotEmpty) return AddTextCmd(t);
    }
    if (RegExp(r'^(?:اضف|ضيف|add)\s+(?:نص|text)\s*$').hasMatch(n)) return const AddTextCmd('اكتب هنا');

    final color = _findColor(stems);
    final hasBg = has(['خلفيه', 'background', 'bg']);
    final removeVerb = has(_removeVerbs);

    // ── ألوان ──
    if (hasBg && !removeVerb && color != null) return BgColorCmd(color);
    if (color != null &&
        (phrase(['لون النص', 'لون الكلام', 'لون الخط', 'text color', 'font color', 'color of text']) ||
            (has(['نص', 'text', 'الكلام', 'الكتابه']) && !has(['اضف', 'ضيف', 'add'])))) {
      return TextColorCmd(color);
    }

    // ── إزالة الخلفية ──
    if ((hasBg && removeVerb) || has(['تفريغ', 'فرغ', 'rmbg']) || phrase(['transparent background', 'خلفيه شفافه'])) {
      return const RemoveBackgroundCmd();
    }

    // ── الظل ──
    if (has(['ظل', 'ظلال', 'shadow', 'shadows'])) {
      final off = removeVerb || has(['الغ', 'الغاء', 'no']);
      return ShadowCmd(!off);
    }

    // ── إزالة الفلتر ──
    if (phrase(['بدون فلتر', 'ازل الفلتر', 'احذف الفلتر', 'الغ الفلتر', 'الغاء الفلتر', 'no filter', 'remove filter', 'بدون تاثير'])) {
      return const FilterCmd(0);
    }

    // ── أنماط التحويل (أنمي/كرتون) ──
    if (has(['انمي', 'انيمي', 'anime'])) return const StyleCmd(StyleKind.anime);
    if (has(['كرتون', 'كارتون', 'cartoon', 'toon'])) return const StyleCmd(StyleKind.cartoon);
    if (has(['كوميك', 'comic'])) return const StyleCmd(StyleKind.comic);
    if (has(['سكتش', 'sketch', 'رصاص', 'pencil'])) return const StyleCmd(StyleKind.sketch);

    // ── تراجع / إعادة ──
    if (has(['تراجع', 'الغاء', 'ارجع', 'undo'])) return const UndoCmd();
    if (has(['اعاده', 'redo', 'تقدم'])) return const RedoCmd();

    // ── تصدير ──
    if (has(['احفظ', 'حفظ', 'صدر', 'تصدير', 'نزل', 'حمل', 'export', 'save', 'download'])) return const ExportCmd();

    // ── ضبط الألوان ──
    final adj = _parseAdjust(n, has);
    if (adj != null) return adj;

    // ── فلاتر جاهزة ──
    if (phrase(['اسود وابيض', 'ابيض واسود', 'اسود و ابيض', 'ابيض و اسود', 'black and white', 'black & white', 'b&w']) ||
        has(['bw', 'grayscale', 'رمادي', 'رماديه'])) {
      return const FilterCmd(4);
    }
    for (final e in _filters.entries) {
      if (has(e.value)) return FilterCmd(e.key);
    }

    // ── أشكال ──
    if (has(['اضف', 'ضيف', 'ارسم', 'add', 'draw', 'insert', 'اضافه'])) {
      if (has(['دايره', 'دائره', 'circle', 'oval'])) return const AddShapeCmd(ShapeKind.circle);
      if (has(['مربع', 'square', 'مستطيل', 'rectangle', 'rect', 'box'])) return const AddShapeCmd(ShapeKind.rect);
      if (has(['نجمه', 'star'])) return const AddShapeCmd(ShapeKind.star);
      if (has(['مثلث', 'triangle'])) return const AddShapeCmd(ShapeKind.triangle);
      if (has(['معين', 'diamond'])) return const AddShapeCmd(ShapeKind.diamond);
      if (has(['خط', 'line'])) return const AddShapeCmd(ShapeKind.line);
    }

    // ── ترتيب الطبقات ──
    if (phrase(['للامام', 'الى الامام', 'قدام', 'فوق الكل', 'to front', 'bring to front'])) return const ZOrderCmd(front: true);
    if (phrase(['للخلف', 'الى الخلف', 'ورا', 'to back', 'send to back'])) return const ZOrderCmd(front: false);

    if (has(['كرر', 'انسخ', 'ضاعف', 'duplicate', 'copy', 'clone'])) return const DuplicateCmd();
    if (has(['اقلب', 'قلب', 'عكس', 'flip', 'mirror'])) return const FlipCmd();
    if (removeVerb) return const DeleteLayerCmd();

    return UnknownCmd(raw);
  }

  static CopilotCommand? _parseAdjust(String n, bool Function(List<String>) has) {
    AdjustParam? param;
    int dir = 0;
    if (has(['سطوع', 'اضاءه', 'انارة', 'اناره', 'brightness', 'bright', 'exposure'])) param = AdjustParam.brightness;
    if (has(['افتح', 'اضوء', 'brighter', 'lighten'])) {
      param = AdjustParam.brightness;
      dir = 1;
    }
    if (has(['اغمق', 'اظلم', 'darker', 'darken'])) {
      param = AdjustParam.brightness;
      dir = -1;
    }
    if (has(['تباين', 'contrast', 'كونتراست'])) param = AdjustParam.contrast;
    if (has(['تشبع', 'saturation', 'vibrance'])) param = AdjustParam.saturation;
    if (has(['حراره', 'دفء', 'دفا', 'temperature', 'warmth'])) param = AdjustParam.temperature;
    if (has(['فينيت', 'vignette'])) param = AdjustParam.vignette;
    if (has(['بهتان', 'fade'])) param = AdjustParam.fade;
    if (param == null) return null;

    if (dir == 0) {
      final up = has(['زد', 'زيد', 'ارفع', 'اكثر', 'عزز', 'زياده', 'increase', 'raise', 'more', 'higher', 'boost', 'up']);
      final down = has(['قلل', 'خفض', 'انقص', 'اقل', 'نقص', 'decrease', 'reduce', 'lower', 'less', 'down']);
      if (up && !down) dir = 1;
      if (down && !up) dir = -1;
    }
    final numM = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(n);
    final double? pct = numM == null ? null : (double.parse(numM.group(1)!) / 100).clamp(0.0, 1.0).toDouble();
    if (dir != 0) return AdjustCmd(param, dir * (pct ?? 0.15), relative: true);
    if (pct != null) return AdjustCmd(param, pct, relative: false);
    return AdjustCmd(param, 0.15, relative: true);
  }
}
