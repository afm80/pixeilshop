import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Layer;
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';
import 'templates.dart';
import 'util.dart';
import 'ui.dart';
import 'fonts_page.dart';
import 'fill_pages.dart';
import 'curve.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

const kFonts = [
  'Cairo', 'Tajawal', 'Almarai', 'Amiri', 'Lalezar', 'Reem Kufi', 'Changa', 'El Messiri', 'Harmattan',
  'Aref Ruqaa', 'Noto Kufi Arabic', 'Rakkas', 'Mada', 'Markazi Text', 'Katibeh', 'Jomhuria',
  'Bebas Neue', 'Pacifico', 'Playfair Display', 'Lobster', 'Montserrat', 'Oswald', 'Anton',
  'Dancing Script', 'Permanent Marker', 'Righteous',
];
const kSwatches = [
  Colors.white, Colors.black, Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF4CD964),
  Color(0xFF009688), Color(0xFF00BCD4), Color(0xFF2196F3), Color(0xFF673AB7), Color(0xFFE91E63), Color(0xFF795548), Color(0xFF9E9E9E),
];
const kEmoji = ['😀', '😍', '🔥', '✨', '💖', '⭐', '🌈', '☀️', '🌙', '🎉', '🎵', '👑', '💎', '🌸', '🍀', '🦋', '⚡', '❤️',
  '👍', '🎨', '📌', '🚀', '🌴', '☕', '😎', '🥳', '💯', '🎁', '📷', '🏆'];
const kRatios = {'1:1': 1.0, '4:5': .8, '3:4': .75, '2:3': .6667, '4:3': 1.3333, '9:16': .5625, '16:9': 1.7778};

final kStickerGroups = <String, List<String>>{
  'وجوه': '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 😉 😍 🥰 😘 😋 😎 🤩 🥳 😏 😢 😭 😡 🤔 😴 🤯 😱 🙄 😬 👍 👏 🙏'.split(' '),
  'قلوب ونجوم': '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💖 💗 💓 💞 💕 💘 ⭐ 🌟 ✨ 💫 ⚡ 🔥 💥 🌈 👑 💎'.split(' '),
  'طبيعة': '🌸 🌹 🌺 🌻 🌼 🌷 🍀 🌿 🌴 🌵 🍁 🌙 ☀️ ⛅ 🌧️ ❄️ 🌊 🌍 🏔️ 🌲'.split(' '),
  'حيوانات': '🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🦅 🦋 🐝 🐢 🐬'.split(' '),
  'طعام': '🍎 🍌 🍇 🍓 🍉 🍕 🍔 🍟 🌮 🍩 🍰 🎂 🍫 ☕ 🍵 🥤 🍦'.split(' '),
  'أنشطة': '⚽ 🏀 🏈 ⚾ 🎾 🏐 🎮 🎯 🎵 🎤 🎧 🎸 🎨 📷 🎬 🏆 🥇 🎉 🎁 🚀'.split(' '),
  'زخارف': '﷽ ❁ ✦ ❖ ✿ ❀ ✺ ☪ ۞ ۩ ❝ ❞ ✓ ✔ ➤ ♛ ♚ ✪ ☘ ♠ ♥ ♦ ♣ ★ ☆ ✂ ☎'.split(' '),
};

class ShapeP extends CustomPainter {
  ShapeP(this.l);
  final Layer l;
  @override
  void paint(Canvas c, Size s) {
    final p = Path(), w = s.width, h = s.height;
    switch (l.shape) {
      case 'circle': p.addOval(Offset.zero & s);
      case 'tri': p..moveTo(w / 2, 0)..lineTo(w, h)..lineTo(0, h)..close();
      case 'star':
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? .5 : .22, a = i * pi / 5 - pi / 2;
          final o = Offset(w / 2 + cos(a) * r * w, h / 2 + sin(a) * r * h);
          i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        p.close();
      case 'heart':
        p..moveTo(w / 2, h * .9)..cubicTo(-w * .2, h * .45, w * .15, -h * .1, w / 2, h * .3)
          ..cubicTo(w * .85, -h * .1, w * 1.2, h * .45, w / 2, h * .9);
      default: p.addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(l.radius)));
    }
    final fill = Paint()..color = l.color;
    if (l.grad) fill.shader = layerGradient(l).createShader(Offset.zero & s);
    c.drawPath(p, fill);
    if (l.strokeW > 0) {
      c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = l.strokeW..color = l.stroke..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(covariant ShapeP o) => true;
}

class EditorPage extends StatefulWidget {
  const EditorPage(this.doc, this.id, {super.key});
  final Doc doc;
  final String id;
  @override
  State<EditorPage> createState() => _EditorState();
}

class _EditorState extends State<EditorPage> {
  late Doc d = widget.doc;
  Layer? sel;
  String tool = '';
  final key = GlobalKey();
  final tc = TransformationController();
  final hist = <String>[];
  int hi = -1;
  double k = 1, _s0 = 1, _r0 = 0;
  bool _touch = false; // لمس عنصر: عطّل تحريك/تكبير اللوحة
  Offset _hc = Offset.zero;
  double _rx = 0, _ry = 0;
  double _hd0 = 1, _ha0 = 0, _hs0 = 1, _hr0 = 0;

  @override
  void initState() {
    super.initState();
    push(save: false);
  }

  void push({bool save = true}) {
    if (hi < hist.length - 1) hist.removeRange(hi + 1, hist.length);
    hist.add(jsonEncode(d.toJson()));
    if (hist.length > 60) hist.removeAt(0);
    hi = hist.length - 1;
    if (save) Store.save(widget.id, d);
    setState(() {});
  }

  void jump(int i) {
    if (i < 0 || i >= hist.length) return;
    hi = i;
    d = Doc.fromJson(jsonDecode(hist[i]));
    sel = null;
    tool = '';
    Store.save(widget.id, d);
    setState(() {});
  }

  void add(Layer l) {
    d.layers.add(l);
    sel = l;
    tool = '';
    push();
  }

  void snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  // ---------- رسم الطبقات ----------
  List<double> mat(Layer l) => mat2(l.bright, l.contrast, l.sat);

  List<double> mat2(double bright, double contrast, double sat) {
    final s = sat, c = contrast, t = (1 - c) * 127.5 + bright * 255;
    final sr = (1 - s) * .2126, sg = (1 - s) * .7152, sb = (1 - s) * .0722;
    return [(sr + s) * c, sg * c, sb * c, 0, t, sr * c, (sg + s) * c, sb * c, 0, t, sr * c, sg * c, (sb + s) * c, 0, t, 0, 0, 0, 1, 0];
  }

  Widget textW(Layer l) {
    final w = textCore(l);
    if (!l.tbg) return w;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: l.size * .4, vertical: l.size * .2),
      decoration: BoxDecoration(color: l.tbgColor, borderRadius: BorderRadius.circular(l.tbgR)),
      child: w,
    );
  }

  Widget textCore(Layer l) {
    TextStyle st({Paint? fg, Color? col, List<Shadow>? sh}) => gf(l.font,
        textStyle: TextStyle(fontSize: l.size, fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: l.spacing, height: l.lh, color: fg == null ? col : null, foreground: fg, shadows: sh));
    Widget t(TextStyle s, [Offset o = Offset.zero]) =>
        Transform.translate(offset: o, child: Text(l.text, textAlign: const [TextAlign.left, TextAlign.center, TextAlign.right][l.align.clamp(0, 2)], style: s));
    if (l.curve.abs() > .01) return CustomPaint(size: CurvePainter.sizeOf(l, st), painter: CurvePainter(l, st));
    return Stack(alignment: Alignment.center, children: [
      if (l.depth > 0) for (double i = l.depth; i > 0; i -= 2) t(st(col: l.shadow), Offset(i, i)),
      if (l.strokeW > 0)
        t(st(fg: Paint()..style = PaintingStyle.stroke..strokeWidth = l.strokeW..strokeJoin = StrokeJoin.round..color = l.stroke)),
      if (l.grad) ...[
        if (l.shadowBlur > 0) t(st(col: Colors.transparent, sh: [Shadow(color: l.shadow, blurRadius: l.shadowBlur)])),
        ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (r) => layerGradient(l).createShader(r), child: t(st(col: Colors.white))),
      ] else
        t(st(col: l.color, sh: l.shadowBlur > 0 ? [Shadow(color: l.shadow, blurRadius: l.shadowBlur)] : null)),
    ]);
  }

  Widget imageW(Layer l) {
    Widget w = SizedBox(width: l.w, height: l.h, child: Image.file(File(l.path!), fit: BoxFit.cover, cacheWidth: 1400));
    w = ColorFiltered(colorFilter: ColorFilter.matrix(mat(l)), child: w);
    if (l.blur > 0) w = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: l.blur, sigmaY: l.blur), child: w);
    return ClipRRect(borderRadius: BorderRadius.circular(l.radius), child: w);
  }

  Widget body(Layer l) => switch (l.type) {
        LT.text => textW(l),
        LT.image => imageW(l),
        LT.shape => SizedBox(width: l.w, height: l.h, child: CustomPaint(painter: ShapeP(l))),
      };

  Future<void> openFill(Layer l, {required bool grad}) async {
    final tmp = Layer.fromJson(l.toJson(), fresh: true)..x = 0..y = 0..rot = 0..scale = 1..opacity = 1..flip = false;
    final r = await Navigator.push<Layer>(context, MaterialPageRoute(
        builder: (_) => grad ? GradientPage(tmp, body) : FillPage(tmp, body)));
    if (r == null) return;
    l..color = r.color..grad = r.grad..radial = r.radial..g1 = r.g1..g2 = r.g2..gAngle = r.gAngle;
    tool = '';
    push();
  }

  Widget handle(Layer l, double hs, {required IconData icon, VoidCallback? onTap, bool resize = true, required BuildContext box}) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (!resize) return;
        final rb = box.findRenderObject() as RenderBox;
        _hc = rb.localToGlobal(rb.size.center(Offset.zero));
        final v = e.position - _hc;
        _hd0 = max(v.distance, 1);
        _ha0 = v.direction;
        _hs0 = l.scale;
        _hr0 = l.rot;
      },
      onPointerMove: (e) {
        if (!resize) return;
        final v = e.position - _hc;
        setState(() {
          l.scale = (_hs0 * v.distance / _hd0).clamp(.1, 8.0);
          l.rot = _hr0 + (v.direction - _ha0);
        });
      },
      onPointerUp: (e) {
        if (resize) { push(); } else { onTap?.call(); }
      },
      child: Container(
        width: hs, height: hs,
        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.black, size: hs * .62),
      ),
    );
  }

  Widget layerW(Layer l) {
    Widget c = body(l);
    c = Opacity(opacity: l.opacity, child: c);
    final selected = l == sel && !l.locked;
    if (l == sel) c = DecoratedBox(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3 / k)), child: c);
    final m = k * tc.value.getMaxScaleOnAxis() * l.scale;
    final hs = (46 / m).clamp(20.0, 600.0);
    Widget inner = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() { sel = l; tool = ''; }),
      onDoubleTap: () { if (l.type == LT.text) { setState(() => sel = l); run('edit'); } },
      onScaleStart: (_) { setState(() => sel = l); _s0 = l.scale; _r0 = l.rot; _rx = l.x; _ry = l.y; },
      onScaleUpdate: (u) {
        final mm = k * tc.value.getMaxScaleOnAxis();
        setState(() {
          _rx += u.focalPointDelta.dx / mm;
          _ry += u.focalPointDelta.dy / mm;
          l.x = _rx.abs() < 8 ? 0 : _rx;
          l.y = _ry.abs() < 8 ? 0 : _ry;
          if (u.pointerCount > 1) { l.scale = (_s0 * u.scale).clamp(.1, 8.0); l.rot = _r0 + u.rotation; }
        });
      },
      onScaleEnd: (_) => push(),
      child: c,
    );
    if (selected) {
      inner = Builder(builder: (bx) => Stack(children: [
        Padding(padding: EdgeInsets.all(hs / 2), child: inner),
        Positioned(left: 0, top: 0, child: handle(l, hs, icon: Icons.close, resize: false, box: bx,
            onTap: () { d.layers.remove(l); sel = null; tool = ''; push(); })),
        Positioned(right: 0, top: 0, child: handle(l, hs, icon: Icons.open_in_full, box: bx)),
        Positioned(left: 0, bottom: 0, child: handle(l, hs, icon: Icons.open_in_full, box: bx)),
        Positioned(right: 0, bottom: 0, child: handle(l, hs, icon: Icons.rotate_right, box: bx)),
      ]));
    }
    final w = Listener(
      onPointerDown: (_) { if (!_touch) setState(() => _touch = true); },
      onPointerUp: (_) { if (_touch) setState(() => _touch = false); },
      onPointerCancel: (_) { if (_touch) setState(() => _touch = false); },
      child: IgnorePointer(
        ignoring: l.locked,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..translate(l.x, l.y)..rotateZ(l.rot)..scale(l.scale * (l.flip ? -1 : 1), l.scale, 1)..multiply(Matrix4.skewX(l.skew)),
          child: inner,
        ),
      ),
    );
    return l.blend == 0 ? w : BlendBox(mode: kBlends[l.blend].$2, child: w);
  }

  Widget bgW() {
    final b = d.bg;
    if (b.kind == 2 && b.path != null) return SizedBox.expand(child: Image.file(File(b.path!), fit: BoxFit.cover, cacheWidth: 1600));
    if (b.kind == 1) {
      final a = b.angle * pi / 180;
      return DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(-cos(a), -sin(a)), end: Alignment(cos(a), sin(a)), colors: [b.c1, b.c2])),
        child: const SizedBox.expand());
    }
    return ColoredBox(color: b.c1, child: const SizedBox.expand());
  }

  Widget fxWrap(Widget c) {
    if (d.bright != 0 || d.contrast != 1 || d.sat != 1) c = ColorFiltered(colorFilter: ColorFilter.matrix(mat2(d.bright, d.contrast, d.sat)), child: c);
    if (d.blur > 0) c = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: d.blur, sigmaY: d.blur), child: c);
    if (d.flip) c = Transform.flip(flipX: true, child: c);
    if (d.frameW > 0) {
      c = Stack(children: [
        Positioned.fill(child: c),
        Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: d.frameColor, width: d.frameW))))),
      ]);
    }
    if (d.opacity < 1) c = Opacity(opacity: d.opacity, child: c);
    return ClipRRect(borderRadius: BorderRadius.circular(d.radius), child: c);
  }

  Widget canvas(BoxConstraints bc) {
    k = min(bc.maxWidth / d.w, bc.maxHeight / d.h) * .94;
    return InteractiveViewer(
      transformationController: tc, minScale: .6, maxScale: 5, panEnabled: !_touch, scaleEnabled: !_touch,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: d.w * k, height: d.h * k,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: d.w, height: d.h,
                child: fxWrap(
                  Stack(alignment: Alignment.center, children: [
                    Positioned.fill(child: GestureDetector(onTap: () => setState(() { sel = null; tool = ''; }), child: bgW())),
                    for (final l in d.layers) if (!l.hidden) layerW(l),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- الأدوات ----------
  List<(IconData, String, String)> toolsFor() {
    final l = sel;
    if (l == null) {
      return [
        (Icons.add, 'إضافة', 'add'), (Icons.format_color_fill, 'اللون', 'bgc'), (Icons.gradient, 'تدرج', 'bgg'), (Icons.image, 'صورة', 'bgi'),
        (Icons.border_outer, 'إطار', 'frame'), (Icons.rounded_corner, 'الزوايا', 'bradius'), (Icons.opacity, 'الشفافية', 'bop'),
        (Icons.tune, 'فلاتر', 'bfilter'), (Icons.flip, 'قلب', 'bflip'), (Icons.aspect_ratio, 'الحجم', 'size'),
      ];
    }
    final common = [
      (Icons.opacity, 'الشفافية', 'op'), (Icons.open_with, 'تحريك دقيق', 'nudge'), (Icons.flip, 'قلب', 'flip'), (Icons.format_italic, 'إنحناء', 'skew'), (Icons.layers, 'وضع الدمج', 'blend'), (Icons.copy, 'نسخ', 'dup'),
      (Icons.flip_to_front, 'للأمام', 'up'), (Icons.flip_to_back, 'للخلف', 'dn'), (Icons.lock_outline, 'قفل', 'lock'), (Icons.delete_outline, 'حذف', 'del'),
    ];
    return switch (l.type) {
      LT.text => [(Icons.palette, 'اللون', 'fill'), (Icons.gradient, 'تدرج', 'grad'), (Icons.font_download, 'الخطوط', 'font'), (Icons.border_style, 'إحاطة', 'stroke'),
          (Icons.blur_on, 'الظل', 'shadow'), (Icons.view_in_ar, 'العمق', 'depth'), (Icons.format_bold, 'تحديد', 'bold'), (Icons.waves, 'تقويس', 'curve'),
          (Icons.format_line_spacing, 'ارتفاع السطر', 'lh'), (Icons.format_size, 'الحجم', 'tsize'), (Icons.edit, 'تعديل', 'edit'), (Icons.format_color_fill, 'خلفية النص', 'tbg'), ...common],
      LT.image => [(Icons.tune, 'فلاتر', 'filter'), (Icons.rounded_corner, 'الزوايا', 'radius'),
          (Icons.auto_fix_high, 'إزالة الخلفية', 'rmbg'), ...common],
      LT.shape => [(Icons.palette, 'اللون', 'fill'), (Icons.gradient, 'تدرج', 'grad'), (Icons.border_style, 'الحد', 'stroke'), (Icons.aspect_ratio, 'الحجم', 'ssize'), ...common],
    };
  }

  Future<void> run(String id) async {
    final l = sel;
    switch (id) {
      case 'dup':
        if (l != null) add(Layer.fromJson(l.toJson(), fresh: true)..x += 40..y += 40);
        return;
      case 'up':
        if (l != null) { final i = d.layers.indexOf(l); if (i < d.layers.length - 1) d.layers..removeAt(i)..insert(i + 1, l); push(); }
        return;
      case 'dn':
        if (l != null) { final i = d.layers.indexOf(l); if (i > 0) d.layers..removeAt(i)..insert(i - 1, l); push(); }
        return;
      case 'lock':
        if (l != null) { l.locked = true; sel = null; tool = ''; push(); snack('تم القفل. افتحه من قائمة الطبقات'); }
        return;
      case 'del':
        d.layers.remove(l); sel = null; tool = ''; push();
        return;
      case 'flip':
        if (l != null) { l.flip = !l.flip; push(); }
        return;
      case 'font':
        final f = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => FontsPage(current: l!.font, sample: l.text)));
        if (f != null) { l!.font = f; tool = ''; push(); }
        return;
      case 'add':
        addSheet();
        return;
      case 'bflip':
        d.flip = !d.flip;
        push();
        return;
      case 'fill':
        if (l != null) await openFill(l, grad: false);
        return;
      case 'grad':
        if (l != null) await openFill(l, grad: true);
        return;
      case 'bold':
        if (l != null) { l.bold = !l.bold; push(); }
        return;
      case 'edit':
        final t = await askText(context, 'تعديل النص', l!.text, multi: true);
        if (t != null && t.isNotEmpty) { l.text = t; push(); }
        return;
      case 'rmbg':
        await removeBg(l!);
        return;
      case 'bgi':
        final p = await pickImg();
        if (p != null) { d.bg..kind = 2..path = p.path; push(); }
        return;
    }
    setState(() => tool = tool == id ? '' : id);
  }

  Widget sld(String n, double v, double a, double b, void Function(double) f) => Row(children: [
        SizedBox(width: 78, child: Text(n, style: const TextStyle(fontSize: 12, color: Colors.white70))),
        Expanded(child: Slider(value: v.clamp(a, b), min: a, max: b, onChanged: (x) => setState(() => f(x)), onChangeEnd: (_) => push())),
      ]);

  Future<Color?> eyedrop() async {
    final s = sel;
    setState(() => sel = null);
    await WidgetsBinding.instance.endOfFrame;
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final im = await b.toImage(pixelRatio: 1);
    final bd = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
    setState(() => sel = s);
    if (!mounted) return null;
    return Navigator.push<Color>(context, MaterialPageRoute(builder: (_) => EyedropPage(im, bd!)));
  }

  Widget colors(Color cur, void Function(Color) f) {
    void set(Color? c) { if (c != null) { setState(() => f(c)); push(); } }
    Widget ib(IconData i, VoidCallback t) => IconButton(onPressed: t, icon: Icon(i));
    return SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        ib(Icons.colorize, () async => set(await eyedrop())),
        ib(Icons.palette, () async => set(await pickColorDialog(context, cur))),
        for (final c in kSwatches)
          GestureDetector(
            onTap: () => set(c),
            child: Container(width: 34, height: 34, margin: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c == cur ? Colors.white : Colors.white24, width: 2))),
          ),
      ]),
    );
  }

  Widget panel() {
    final l = sel;
    if (l == null && !{'bgc', 'bgg', 'size', 'frame', 'bradius', 'bop', 'bfilter'}.contains(tool)) return const SizedBox.shrink();
    Widget? w;
    switch (tool) {
      case 'font':
        w = SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(padding: const EdgeInsets.all(6), child: FilterChip(label: const Text('غامق'), selected: l!.bold, onSelected: (v) { l.bold = v; push(); })),
          for (final f in kFonts)
            Padding(padding: const EdgeInsets.all(6),
                child: ChoiceChip(label: Text('$f  أبجد', style: GoogleFonts.getFont(f)), selected: l.font == f, onSelected: (_) { l.font = f; push(); })),
        ]));
      case 'color': w = colors(l!.color, (c) => l.color = c);
      case 'stroke': w = Column(children: [sld('السماكة', l!.strokeW, 0, 40, (v) => l.strokeW = v), colors(l.stroke, (c) => l.stroke = c)]);
      case 'shadow': w = Column(children: [sld('التمويه', l!.shadowBlur, 0, 80, (v) => l.shadowBlur = v), colors(l.shadow, (c) => l.shadow = c)]);
      case 'depth': w = Column(children: [sld('العمق', l!.depth, 0, 80, (v) => l.depth = v), colors(l.shadow, (c) => l.shadow = c)]);
      case 'skew': w = sld('إنحناء', l!.skew, -.8, .8, (v) => l.skew = v);
      case 'blend': w = SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < kBlends.length; i++)
            Padding(padding: const EdgeInsets.all(6),
                child: ChoiceChip(label: Text(kBlends[i].$1), selected: l!.blend == i, onSelected: (_) { l.blend = i; push(); })),
        ]));
      case 'lh': w = sld('ارتفاع السطر', l!.lh, .7, 2.5, (v) => l.lh = v);
      case 'tsize': w = Column(children: [sld('حجم الخط', l!.size, 20, 500, (v) => l.size = v), sld('التباعد', l.spacing, -10, 60, (v) => l.spacing = v)]);
      case 'op': w = Column(children: [
          sld('الشفافية', l!.opacity, .05, 1, (v) => l.opacity = v),
          sld('التدوير', l.rot * 180 / pi, -180, 180, (v) => l.rot = v * pi / 180),
          sld('التكبير', l.scale, .1, 6, (v) => l.scale = v)]);
      case 'filter': w = Column(children: [
          sld('السطوع', l!.bright, -.6, .6, (v) => l.bright = v), sld('التباين', l.contrast, .5, 2, (v) => l.contrast = v),
          sld('التشبع', l.sat, 0, 2, (v) => l.sat = v), sld('ضبابية', l.blur, 0, 14, (v) => l.blur = v)]);
      case 'radius': w = sld('انحناء', l!.radius, 0, 400, (v) => l.radius = v);
      case 'ssize': w = Column(children: [
          sld('العرض', l!.w, 40, 1400, (v) => l.w = v), sld('الارتفاع', l.h, 40, 1400, (v) => l.h = v),
          if (l.shape == 'rect') sld('الزوايا', l.radius, 0, 400, (v) => l.radius = v)]);
      case 'frame': w = Column(children: [sld('السماكة', d.frameW, 0, 150, (v) => d.frameW = v), colors(d.frameColor, (c) => d.frameColor = c)]);
      case 'bradius': w = sld('الزوايا', d.radius, 0, min(d.w, d.h) / 2, (v) => d.radius = v);
      case 'bop': w = sld('الشفافية', d.opacity, .05, 1, (v) => d.opacity = v);
      case 'bfilter': w = Column(children: [
          sld('السطوع', d.bright, -.6, .6, (v) => d.bright = v), sld('التباين', d.contrast, .5, 2, (v) => d.contrast = v),
          sld('التشبع', d.sat, 0, 2, (v) => d.sat = v), sld('ضبابية', d.blur, 0, 14, (v) => d.blur = v)]);
      case 'tbg': w = Column(children: [
          Row(children: [FilterChip(label: const Text('تفعيل الخلفية'), selected: l!.tbg, onSelected: (v) { l.tbg = v; push(); })]),
          sld('الانحناء', l.tbgR, 0, 100, (v) => l.tbgR = v),
          colors(l.tbgColor, (c) { l.tbg = true; l.tbgColor = c; })]);
      case 'nudge': w = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final e in <(IconData, double, double)>[(Icons.arrow_upward, 0, -6), (Icons.arrow_downward, 0, 6), (Icons.arrow_back, -6, 0), (Icons.arrow_forward, 6, 0)])
            IconButton(iconSize: 34, icon: Icon(e.$1, color: kAccent), onPressed: () { l!.x += e.$2; l.y += e.$3; push(); }),
        ]);
      case 'curve': w = sld('تقويس', l!.curve, -1, 1, (v) => l.curve = v);
      case 'bgc': w = colors(d.bg.c1, (c) { d.bg..kind = 0..c1 = c; });
      case 'bgg': w = Column(children: [
          colors(d.bg.c1, (c) { d.bg..kind = 1..c1 = c; }), colors(d.bg.c2, (c) { d.bg..kind = 1..c2 = c; }),
          sld('الزاوية', d.bg.angle, 0, 360, (v) { d.bg..kind = 1..angle = v; })]);
      case 'size': w = Wrap(spacing: 8, children: [
          for (final e in kRatios.entries)
            ChoiceChip(label: Text(e.key), selected: (d.w / d.h - e.value).abs() < .01,
                onSelected: (_) { d.w = 1080; d.h = (1080 / e.value).roundToDouble(); push(); }),
        ]);
    }
    if (w == null) return const SizedBox.shrink();
    return Container(color: const Color(0xFF202020), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: w);
  }

  // ---------- إضافة ----------
  Future<void> addImage() async {
    final p = await pickImg();
    if (p == null) return;
    final w = min(d.w * .7, p.w);
    add(Layer(LT.image)..path = p.path..w = w..h = w * p.h / p.w);
  }

  void stickers() => showModalBottomSheet(
        context: context, isScrollControlled: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * .6,
          child: DefaultTabController(
            length: kStickerGroups.length,
            child: Column(children: [
              TabBar(isScrollable: true, labelColor: kAccent, indicatorColor: kAccent, tabs: [for (final k in kStickerGroups.keys) Tab(text: k)]),
              Expanded(
                child: TabBarView(children: [
                  for (final g in kStickerGroups.values)
                    GridView.count(
                      crossAxisCount: 6, padding: const EdgeInsets.all(12),
                      children: [
                        for (final e in g)
                          InkWell(
                            onTap: () { Navigator.pop(ctx); add(Layer(LT.text)..text = e..size = 240); },
                            child: Center(child: Text(e, style: const TextStyle(fontSize: 30))),
                          ),
                      ],
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );

  void shapes() => showModalBottomSheet(context: context, builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(spacing: 14, runSpacing: 14, children: [
          for (final s in const {'rect': 'مربع', 'circle': 'دائرة', 'tri': 'مثلث', 'star': 'نجمة', 'heart': 'قلب'}.entries)
            ActionChip(label: Text(s.value), onPressed: () { Navigator.pop(ctx); add(Layer(LT.shape)..shape = s.key..w = 500..h = 500); }),
        ])));

  void templatesSheet() => showModalBottomSheet(context: context, builder: (ctx) => GridView.count(
        crossAxisCount: 3, padding: const EdgeInsets.all(12), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .8,
        children: [for (final t in kTpls) InkWell(
            onTap: () { Navigator.pop(ctx); d = t.build(); sel = null; tool = ''; push(); },
            child: Container(alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: t.build().bg.c1,
                    gradient: t.build().bg.kind == 1 ? LinearGradient(colors: [t.build().bg.c1, t.build().bg.c2], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null),
                child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)]))))]));

  void layersSheet() => showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final ls = d.layers.reversed.toList();
        void ch(VoidCallback f) { f(); push(); setS(() {}); }
        return SizedBox(height: MediaQuery.of(ctx).size.height * .6, child: ls.isEmpty
            ? const Center(child: Text('لا توجد طبقات بعد'))
            : ReorderableListView(
                onReorder: (o, n) {
                  final t = d.layers.length;
                  if (n > o) n--;
                  ch(() { final it = d.layers.removeAt(t - 1 - o); d.layers.insert(t - 1 - n, it); });
                },
                children: [for (final l in ls) ListTile(
                  key: ValueKey(l.id), selected: l == sel,
                  title: Text(l.type == LT.text ? l.text.split('\n').first : l.type == LT.image ? 'صورة' : 'شكل', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () { setState(() => sel = l); Navigator.pop(ctx); },
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(l.hidden ? Icons.visibility_off : Icons.visibility), onPressed: () => ch(() => l.hidden = !l.hidden)),
                    IconButton(icon: Icon(l.locked ? Icons.lock : Icons.lock_open), onPressed: () => ch(() => l.locked = !l.locked)),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ch(() { d.layers.remove(l); if (sel == l) sel = null; })),
                  ]),
                )]));
      }));

  // ---------- إزالة الخلفية عبر الإنترنت (remove.bg) ----------
  Future<void> removeBg(Layer l) async {
    final p = await SharedPreferences.getInstance();
    var key = p.getString('rbkey');
    if (key == null || key.isEmpty) {
      if (!mounted) return;
      key = await askText(context, 'مفتاح remove.bg API (مجاني من remove.bg/api)', '');
      if (key == null || key.trim().isEmpty) return;
      await p.setString('rbkey', key.trim());
    }
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final req = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'))
        ..headers['X-Api-Key'] = key.trim()
        ..fields['size'] = 'auto'
        ..files.add(await http.MultipartFile.fromPath('image_file', l.path!));
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) throw 'الخدمة رفضت الطلب (${res.statusCode})، تأكد من المفتاح والرصيد';
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/rb_${DateTime.now().microsecondsSinceEpoch}.png')..writeAsBytesSync(res.bodyBytes);
      l.path = f.path;
      push();
    } catch (e) {
      snack('تعذرت إزالة الخلفية: $e');
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  // ---------- التصدير ----------
  Future<Uint8List> render({int size = 1024, bool jpg = false}) async {
    final s = sel;
    setState(() { sel = null; tool = ''; });
    await WidgetsBinding.instance.endOfFrame;
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final im = await b.toImage(pixelRatio: size / (max(d.w, d.h) * k));
    final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    setState(() => sel = s);
    final png = bd!.buffer.asUint8List();
    if (!jpg) return png;
    return Uint8List.fromList(img.encodeJpg(img.decodePng(png)!, quality: 92));
  }

  /// نافذة "خيارات الحفظ": الامتداد + الأبعاد
  void saveDialog({required bool share}) {
    var jpg = false;
    var size = 1024;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Dialog(
          backgroundColor: kPanel, shape: const RoundedRectangleBorder(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
                child: Text(share ? 'خيارات المشاركة' : 'خيارات الحفظ', style: const TextStyle(color: kAccent, fontSize: 17))),
            Container(width: double.infinity, color: kBg, padding: const EdgeInsets.all(14), child: const Text('الامتداد', textAlign: TextAlign.center)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final e in {'JPEG': true, 'PNG': false}.entries)
                GestureDetector(
                  onTap: () => set(() => jpg = e.value),
                  child: Container(color: jpg == e.value ? kAccent : null, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                      child: Text(e.key, style: TextStyle(fontSize: 17, color: jpg == e.value ? Colors.black : Colors.white))),
                ),
            ]),
            Container(width: double.infinity, color: kBg, padding: const EdgeInsets.all(14), child: const Text('الأبعاد', textAlign: TextAlign.center)),
            for (final n in const [1024, 720, 1280, 1536, 1920, 2048])
              InkWell(
                onTap: () => set(() => size = n),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  child: Row(children: [
                    Expanded(child: Text(d.w >= d.h ? '$n X ${(n * d.h / d.w).round()}' : '${(n * d.w / d.h).round()} X $n', textAlign: TextAlign.center)),
                    Icon(size == n ? Icons.radio_button_checked : Icons.radio_button_off, color: size == n ? kAccent : Colors.white54),
                  ]),
                ),
              ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final bytes = await render(size: size, jpg: jpg);
                  if (share) {
                    final dir = await getTemporaryDirectory();
                    final f = File('${dir.path}/pixeilshop_${DateTime.now().millisecondsSinceEpoch}.${jpg ? 'jpg' : 'png'}')..writeAsBytesSync(bytes);
                    await Share.shareXFiles([XFile(f.path)]);
                  } else {
                    try { await Gal.putImageBytes(bytes); snack('تم الحفظ في المعرض'); } catch (e) { snack('تعذر الحفظ: $e'); }
                  }
                },
                child: const Text('موافق', style: TextStyle(color: kAccent)),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: kAccent))),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<String?> thumb(String id) async {
    try {
      final b = await render(size: 240);
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/thumb_$id.png')..writeAsBytesSync(b);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _confirm(String t) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kPanel, content: Text(t),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('موافق', style: TextStyle(color: kAccent))),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: kAccent))),
          ],
        ),
      ) ??
      false;

  /// نافذة "حفظ التصميم": قائمة التصاميم المحفوظة + تصميم جديد
  Future<void> saveDesignDialog() async {
    await Store.save(widget.id, d, thumb: await thumb(widget.id));
    var items = await Store.all();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> reload() async {
            items = await Store.all();
            set(() {});
          }

          return Dialog(
            backgroundColor: kPanel, insetPadding: const EdgeInsets.all(16), shape: const RoundedRectangleBorder(),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * .7,
              child: Column(children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.close, color: kAccent, size: 30), onPressed: () => Navigator.pop(ctx)),
                    const Spacer(),
                    const Text('حفظ التصميم', style: TextStyle(fontSize: 17)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ]),
                ),
                ListTile(
                  title: const Text('تصميم جديد'), trailing: const Icon(Icons.library_add_outlined, color: kAccent),
                  onTap: () async {
                    final id = DateTime.now().microsecondsSinceEpoch.toString();
                    await Store.save(id, d, name: 'تصميم ${items.length + 1}', thumb: await thumb(id));
                    await reload();
                    snack('تم حفظ نسخة جديدة');
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView(children: [
                    for (var n = 0; n < items.length; n++)
                      Builder(builder: (_) {
                        final it = items[n];
                        final id = it['id'] as String;
                        final tp = it['thumb'] as String?;
                        final name = (it['name'] as String?) ?? 'تصميم ${items.length - n}';
                        return ListTile(
                          leading: SizedBox(
                            width: 52, height: 52,
                            child: tp != null && File(tp).existsSync()
                                ? Image.file(File(tp), fit: BoxFit.cover)
                                : const Icon(Icons.image_outlined, color: Colors.white38),
                          ),
                          title: Text(name + (id == widget.id ? '  •' : ''), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(
                              child: const Text('التفاصيل', style: TextStyle(color: kAccent, fontSize: 12)),
                              onPressed: () async {
                                final nm = await askText(ctx, 'اسم التصميم', name);
                                if (nm != null && nm.trim().isNotEmpty) { await Store.rename(id, nm.trim()); await reload(); }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.save_outlined, color: Colors.white),
                              onPressed: () async {
                                if (id != widget.id && !await _confirm('استبدال هذا التصميم بالتصميم الحالي؟')) return;
                                await Store.save(id, d, thumb: await thumb(id));
                                await reload();
                                snack('تم الحفظ');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white),
                              onPressed: () async {
                                if (!await _confirm('حذف هذا التصميم؟')) return;
                                await Store.delete(id);
                                await reload();
                              },
                            ),
                          ]),
                        );
                      }),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void exitDialog() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kPanel,
          title: const Text('هل أنت متأكد من رغبتك بالخروج؟', style: TextStyle(color: kAccent, fontSize: 17)),
          content: const Text('نشكرك لاستخدامك Pixeilshop.'),
          actions: [
            TextButton(onPressed: () => SystemNavigator.pop(), child: const Text('خروج', style: TextStyle(color: kAccent))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: kAccent))),
          ],
        ),
      );

  void addSheet() => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(children: [
            for (final (i, t, f) in <(IconData, String, VoidCallback)>[
              (Icons.title, 'نص', () => add(Layer(LT.text))),
              (Icons.image_outlined, 'صورة', addImage),
              (Icons.emoji_emotions_outlined, 'ملصق', stickers),
              (Icons.category_outlined, 'شكل', shapes),
              (Icons.dashboard_outlined, 'قوالب', templatesSheet),
            ])
              SizedBox(width: 90, child: InkWell(
                onTap: () { Navigator.pop(ctx); f(); },
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(children: [Icon(i, color: kAccent, size: 30), const SizedBox(height: 6), Text(t, style: const TextStyle(fontSize: 12))])),
              )),
          ]),
        ),
      );

  void zoom(double f) {
    final ns = (tc.value.getMaxScaleOnAxis() * f).clamp(.6, 5.0);
    tc.value = Matrix4.identity()..scale(ns);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ts = toolsFor();
    Widget ib(IconData i, VoidCallback? f) => IconButton(onPressed: f, icon: Icon(i, color: f == null ? const Color(0xFF8A6D00) : kAccent, size: 28));
    Widget counter(IconData i, int n, VoidCallback? f) => InkWell(
          onTap: f,
          child: SizedBox(width: 52, height: 52, child: Stack(alignment: Alignment.center, children: [
            Icon(i, size: 40, color: f == null ? const Color(0xFF8A6D00) : kAccent),
            Text('$n', style: const TextStyle(fontSize: 11)),
          ])),
        );
    final top = Container(
      color: kPanel, height: 56,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          PopupMenuButton<String>(
            color: kPanel, icon: const Icon(Icons.more_vert, color: kAccent, size: 28),
            onSelected: (v) async {
              switch (v) {
                case 'new': Navigator.pop(context);
                case 'save': saveDesignDialog();
                case 'img': saveDialog(share: false);
                case 'share': saveDialog(share: true);
                case 'set':
                  final p = await SharedPreferences.getInstance();
                  if (!mounted) return;
                  final k2 = await askText(context, 'مفتاح remove.bg API', p.getString('rbkey') ?? '');
                  if (k2 != null) await p.setString('rbkey', k2.trim());
                case 'exit': exitDialog();
              }
            },
            itemBuilder: (_) => [
              for (final (v, t, i) in const [
                ('new', 'تصميم جديد', Icons.edit_note), ('save', 'حفظ التصميم', Icons.save_outlined),
                ('img', 'حفظ الصورة', Icons.photo_outlined), ('share', 'مشاركة الصورة', Icons.share_outlined),
                ('set', 'إعدادات التطبيق', Icons.settings_outlined), ('exit', 'خروج', Icons.logout),
              ])
                PopupMenuItem(value: v, child: Row(children: [Icon(i, color: kAccent), const SizedBox(width: 14), Text(t)])),
            ],
          ),
          ib(Icons.layers_outlined, layersSheet),
          ib(Icons.zoom_in, () => zoom(1.3)),
          ib(Icons.zoom_out, () => zoom(1 / 1.3)),
          const Spacer(),
          counter(Icons.rotate_left, hi, hi > 0 ? () => jump(hi - 1) : null),
          counter(Icons.rotate_right, hist.length - 1 - hi, hi < hist.length - 1 ? () => jump(hi + 1) : null),
          ib(Icons.add_box_outlined, addSheet),
        ]),
      ),
    );
    Widget toolBtn(IconData i, String n, VoidCallback f, bool on) => InkWell(
          onTap: f,
          child: Container(
            width: 76, color: on ? kAccent : null,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, color: on ? Colors.black : kAccent, size: 28),
              const SizedBox(height: 4),
              Text(n, style: TextStyle(fontSize: 11, color: on ? Colors.black : Colors.white)),
            ]),
          ),
        );
    return Scaffold(
      body: DotBg(
        child: SafeArea(
          child: Column(children: [
            top,
            Expanded(
              child: Stack(children: [
                LayoutBuilder(builder: (_, bc) => canvas(bc)),
                if (sel?.type == LT.text)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6), height: 52,
                      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        InkWell(
                          onTap: () => setState(() { sel = null; tool = ''; }),
                          child: Container(width: 54, height: 52, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.close, color: Colors.black, size: 30)),
                        ),
                        TextButton(onPressed: () => run('tsize'), child: Text('${sel!.size.round()}', style: const TextStyle(color: Colors.white, fontSize: 18))),
                        IconButton(onPressed: () => run('fill'), icon: const Icon(Icons.text_fields, color: Colors.white)),
                        IconButton(onPressed: () => run('edit'), icon: const Icon(Icons.title, color: Colors.white)),
                        IconButton(
                          onPressed: () { sel!.align = (sel!.align + 1) % 3; push(); },
                          icon: Icon([Icons.format_align_left, Icons.format_align_center, Icons.format_align_right][sel!.align.clamp(0, 2)], color: Colors.white),
                        ),
                        IconButton(onPressed: () => run('dup'), icon: const Icon(Icons.copy, color: Colors.white)),
                      ]),
                    ),
                  ),
              ]),
            ),
            panel(),
            Container(
              color: kPanel, height: 68,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                if (sel != null) toolBtn(Icons.arrow_back, 'رجوع', () => setState(() { sel = null; tool = ''; }), false),
                for (final (i, n, id) in ts) toolBtn(i, n, () => run(id), tool == id),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
