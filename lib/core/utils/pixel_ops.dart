import 'dart:math' as math;
import 'dart:typed_data';

/// عمليات بكسلات نقية (بدون dart:ui) لتُنفَّذ داخل Isolate عبر compute().

// ───────────────────────── تطبيق قناع (إزالة خلفية) ─────────────────────────

class MaskJob {
  MaskJob(this.rgba, this.w, this.h, this.mask, this.mw, this.mh, {this.lo = 0.3, this.hi = 0.7});
  final Uint8List rgba;
  final int w, h;
  final Float32List mask;
  final int mw, mh;
  final double lo, hi;
}

class MaskOut {
  MaskOut(this.rgba, this.w, this.h, this.left, this.top, this.srcW, this.srcH);
  final Uint8List rgba; // مقصوصة على حدود العنصر
  final int w, h; // أبعاد القصّ
  final int left, top; // موضع القصّ في الصورة الأصلية
  final int srcW, srcH; // أبعاد الصورة الأصلية
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0).toDouble();
  return t * t * (3 - 2 * t);
}

/// نسبة البكسلات الأمامية في القناع (للتحقق من نجاحه).
double maskCoverage(Float32List m) {
  if (m.isEmpty) return 0;
  int n = 0;
  for (int i = 0; i < m.length; i += 7) {
    if (m[i] > 0.5) n++;
  }
  return n / ((m.length + 6) ~/ 7);
}

MaskOut applyMask(MaskJob j) {
  final w = j.w, h = j.h, mw = j.mw, mh = j.mh;
  final alpha = Uint8List(w * h);
  final same = mw == w && mh == h;
  for (int y = 0; y < h; y++) {
    double fy = 0;
    int y0 = 0, y1 = 0;
    if (!same) {
      fy = ((y + 0.5) * mh / h - 0.5).clamp(0.0, mh - 1.0).toDouble();
      y0 = fy.floor();
      y1 = math.min(y0 + 1, mh - 1);
      fy -= y0;
    }
    for (int x = 0; x < w; x++) {
      double v;
      if (same) {
        v = j.mask[y * w + x];
      } else {
        double fx = ((x + 0.5) * mw / w - 0.5).clamp(0.0, mw - 1.0).toDouble();
        final x0 = fx.floor();
        final x1 = math.min(x0 + 1, mw - 1);
        fx -= x0;
        final a = j.mask[y0 * mw + x0] * (1 - fx) + j.mask[y0 * mw + x1] * fx;
        final b = j.mask[y1 * mw + x0] * (1 - fx) + j.mask[y1 * mw + x1] * fx;
        v = a * (1 - fy) + b * fy;
      }
      alpha[y * w + x] = (_smooth(j.lo, j.hi, v) * 255).round();
    }
  }

  // تنعيم خفيف للحواف (3x3)
  final soft = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int s = 0, n = 0;
      for (int dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (int dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          s += alpha[yy * w + xx];
          n++;
        }
      }
      soft[y * w + x] = s ~/ n;
    }
  }

  int minX = w, minY = h, maxX = -1, maxY = -1;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (soft[y * w + x] > 12) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) {
    minX = 0;
    minY = 0;
    maxX = w - 1;
    maxY = h - 1;
  }
  final padX = ((maxX - minX) * 0.02).round() + 2;
  final padY = ((maxY - minY) * 0.02).round() + 2;
  minX = math.max(0, minX - padX);
  minY = math.max(0, minY - padY);
  maxX = math.min(w - 1, maxX + padX);
  maxY = math.min(h - 1, maxY + padY);
  final cw = maxX - minX + 1, ch = maxY - minY + 1;

  final out = Uint8List(cw * ch * 4);
  for (int y = 0; y < ch; y++) {
    for (int x = 0; x < cw; x++) {
      final si = (y + minY) * w + (x + minX);
      final o = (y * cw + x) * 4;
      out[o] = j.rgba[si * 4];
      out[o + 1] = j.rgba[si * 4 + 1];
      out[o + 2] = j.rgba[si * 4 + 2];
      out[o + 3] = soft[si];
    }
  }
  return MaskOut(out, cw, ch, minX, minY, w, h);
}

// ───────────────────── إزالة خلفية بالألوان (بدون ML) ─────────────────────

class FloodJob {
  FloodJob(this.rgba, this.w, this.h, this.tolerance);
  final Uint8List rgba;
  final int w, h;
  final double tolerance;
}

int _median(List<int> v) {
  v.sort();
  return v[v.length ~/ 2];
}

/// يعيد قناعاً (1 = عنصر أمامي، 0 = خلفية) بملء الفيضان من الحواف.
Float32List floodMask(FloodJob j) {
  final w = j.w, h = j.h;
  final rs = <int>[], gs = <int>[], bs = <int>[];
  void sample(int x, int y) {
    final i = (y * w + x) * 4;
    rs.add(j.rgba[i]);
    gs.add(j.rgba[i + 1]);
    bs.add(j.rgba[i + 2]);
  }

  for (int x = 0; x < w; x += 3) {
    sample(x, 0);
    sample(x, h - 1);
  }
  for (int y = 0; y < h; y += 3) {
    sample(0, y);
    sample(w - 1, y);
  }
  final br = _median(rs), bg = _median(gs), bb = _median(bs);
  final tol2 = j.tolerance * j.tolerance;

  bool isBg(int idx) {
    final i = idx * 4;
    final dr = j.rgba[i] - br, dg = j.rgba[i + 1] - bg, db = j.rgba[i + 2] - bb;
    return dr * dr + dg * dg + db * db <= tol2;
  }

  final visited = Uint8List(w * h);
  final queue = Int32List(w * h);
  int head = 0, tail = 0;
  void push(int idx) {
    if (visited[idx] == 1 || !isBg(idx)) return;
    visited[idx] = 1;
    queue[tail++] = idx;
  }

  for (int x = 0; x < w; x++) {
    push(x);
    push((h - 1) * w + x);
  }
  for (int y = 0; y < h; y++) {
    push(y * w);
    push(y * w + w - 1);
  }
  while (head < tail) {
    final idx = queue[head++];
    final x = idx % w, y = idx ~/ w;
    if (x > 0) push(idx - 1);
    if (x < w - 1) push(idx + 1);
    if (y > 0) push(idx - w);
    if (y < h - 1) push(idx + w);
  }
  final out = Float32List(w * h);
  for (int i = 0; i < out.length; i++) {
    out[i] = visited[i] == 1 ? 0.0 : 1.0;
  }
  return out;
}

// ─────────────────────────── فلاتر كرتونية (Fallback) ───────────────────────────

class CartoonJob {
  CartoonJob(this.rgba, this.w, this.h, this.style, this.strength);
  final Uint8List rgba;
  final int w, h;
  final int style; // 0 كوميك، 1 رسم رصاص
  final double strength; // 0..1
}

Uint8List boxBlurRgb(Uint8List src, int w, int h, int r) {
  if (r <= 0) return Uint8List.fromList(src);
  final tmp = Uint8List(src.length);
  final out = Uint8List(src.length);
  final win = 2 * r + 1;
  for (int y = 0; y < h; y++) {
    final row = y * w * 4;
    for (int c = 0; c < 3; c++) {
      int sum = 0;
      for (int k = -r; k <= r; k++) {
        final xx = k < 0 ? 0 : (k >= w ? w - 1 : k);
        sum += src[row + xx * 4 + c];
      }
      for (int x = 0; x < w; x++) {
        tmp[row + x * 4 + c] = sum ~/ win;
        final xo = x - r, xi = x + r + 1;
        sum -= src[row + (xo < 0 ? 0 : xo) * 4 + c];
        sum += src[row + (xi >= w ? w - 1 : xi) * 4 + c];
      }
    }
  }
  for (int x = 0; x < w; x++) {
    for (int c = 0; c < 3; c++) {
      int sum = 0;
      for (int k = -r; k <= r; k++) {
        final yy = k < 0 ? 0 : (k >= h ? h - 1 : k);
        sum += tmp[(yy * w + x) * 4 + c];
      }
      for (int y = 0; y < h; y++) {
        out[(y * w + x) * 4 + c] = sum ~/ win;
        final yo = y - r, yi = y + r + 1;
        sum -= tmp[((yo < 0 ? 0 : yo) * w + x) * 4 + c];
        sum += tmp[((yi >= h ? h - 1 : yi) * w + x) * 4 + c];
      }
    }
  }
  for (int i = 3; i < out.length; i += 4) {
    out[i] = 255;
  }
  return out;
}

Uint8List cartoonize(CartoonJob j) {
  final w = j.w, h = j.h;
  final n = w * h;
  final blurR = math.max(1, (math.max(w, h) / 400).round());
  var sm = boxBlurRgb(j.rgba, w, h, blurR);
  sm = boxBlurRgb(sm, w, h, blurR);

  final luma = Uint8List(n);
  for (int i = 0; i < n; i++) {
    luma[i] = ((sm[i * 4] * 54 + sm[i * 4 + 1] * 183 + sm[i * 4 + 2] * 19) >> 8).clamp(0, 255).toInt();
  }
  final out = Uint8List(n * 4);

  if (j.style == 1) {
    // رسم رصاص: dodge(gray, blur(invert(gray)))
    final inv = Uint8List(n * 4);
    for (int i = 0; i < n; i++) {
      final v = 255 - luma[i];
      inv[i * 4] = v;
      inv[i * 4 + 1] = v;
      inv[i * 4 + 2] = v;
      inv[i * 4 + 3] = 255;
    }
    var b = boxBlurRgb(inv, w, h, math.max(3, (math.max(w, h) / 90).round()));
    b = boxBlurRgb(b, w, h, math.max(2, (math.max(w, h) / 140).round()));
    for (int i = 0; i < n; i++) {
      final g = luma[i];
      final bl = b[i * 4];
      int v = bl >= 255 ? 255 : math.min(255, (g * 255) ~/ (255 - bl));
      v = (g + (v - g) * (0.6 + 0.4 * j.strength)).round().clamp(0, 255).toInt();
      out[i * 4] = v;
      out[i * 4 + 1] = v;
      out[i * 4 + 2] = v;
      out[i * 4 + 3] = 255;
    }
    return out;
  }

  // كوميك: تبسيط ألوان + خطوط حواف
  final levels = 6 + ((1 - j.strength) * 6).round();
  final step = 255.0 / (levels - 1);
  final edgeThr = 70 - 30 * j.strength;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final i = y * w + x;
      // سوبل
      double gx = 0, gy = 0;
      if (x > 0 && x < w - 1 && y > 0 && y < h - 1) {
        final a = luma[i - w - 1], b = luma[i - w], c = luma[i - w + 1];
        final d = luma[i - 1], f = luma[i + 1];
        final g = luma[i + w - 1], hh = luma[i + w], k = luma[i + w + 1];
        gx = (c + 2 * f + k) - (a + 2 * d + g).toDouble();
        gy = (g + 2 * hh + k) - (a + 2 * b + c).toDouble();
      }
      final mag = math.sqrt(gx * gx + gy * gy);
      double r = sm[i * 4].toDouble(), g2 = sm[i * 4 + 1].toDouble(), b2 = sm[i * 4 + 2].toDouble();
      final lm = 0.299 * r + 0.587 * g2 + 0.114 * b2;
      r = lm + (r - lm) * 1.3;
      g2 = lm + (g2 - lm) * 1.3;
      b2 = lm + (b2 - lm) * 1.3;
      r = (r.clamp(0.0, 255.0) / step).round() * step;
      g2 = (g2.clamp(0.0, 255.0) / step).round() * step;
      b2 = (b2.clamp(0.0, 255.0) / step).round() * step;
      final k = mag > edgeThr ? 0.2 : 1.0;
      out[i * 4] = (r * k).round().clamp(0, 255).toInt();
      out[i * 4 + 1] = (g2 * k).round().clamp(0, 255).toInt();
      out[i * 4 + 2] = (b2 * k).round().clamp(0, 255).toInt();
      out[i * 4 + 3] = 255;
    }
  }
  return out;
}
