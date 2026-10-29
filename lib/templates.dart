import 'package:flutter/material.dart';
import 'model.dart';

class Tpl {
  const Tpl(this.name, this.build);
  final String name;
  final Doc Function() build;
}

Layer _t(String s, {String f = 'Cairo', double sz = 120, Color c = Colors.white, double y = 0, double sp = 0,
        double sw = 0, Color st = Colors.black, double sh = 0, double dp = 0, Color sc = Colors.black, bool b = true}) =>
    Layer(LT.text)..text = s..font = f..size = sz..color = c..y = y..spacing = sp..strokeW = sw..stroke = st
      ..shadowBlur = sh..depth = dp..shadow = sc..bold = b;

Doc _g(Color a, Color b, double ang, List<Layer> l) => Doc(1080, 1350, Bg(kind: 1, c1: a, c2: b, angle: ang), l);
Doc _c(Color a, List<Layer> l) => Doc(1080, 1350, Bg(c1: a), l);

final List<Tpl> kTpls = [
  Tpl('غروب', () => _g(const Color(0xFFFF512F), const Color(0xFFDD2476), 90,
      [_t('Sunset\nVibes', f: 'Pacifico', sz: 230, sh: 30), _t('عِش اللحظة', sz: 70, y: 420, b: false)])),
  Tpl('نيون', () => _g(const Color(0xFF0F0C29), const Color(0xFF302B63), 90,
      [_t('NEON', f: 'Bebas Neue', sz: 420, c: const Color(0xFF00F5FF), sh: 50, sc: const Color(0xFF00F5FF)),
       _t('NIGHT SERIES', f: 'Montserrat', sz: 56, y: 330, sp: 14)])),
  Tpl('فخامة', () => _c(Colors.black, [
        _t('LUXURY', f: 'Playfair Display', sz: 210, c: const Color(0xFFD4AF37), sp: 12),
        _t('COLLECTION 2026', f: 'Montserrat', sz: 48, y: 200, sp: 10, c: Colors.white70, b: false)])),
  Tpl('اقتباس', () => _c(const Color(0xFFF2EEE3), [
        _t('لا تؤجل عمل اليوم\nإلى الغد', f: 'Amiri', sz: 130, c: const Color(0xFF1B1B1B))])),
  Tpl('عرض', () => _c(const Color(0xFFFF3D00), [
        _t('SALE', f: 'Anton', sz: 470, dp: 40, sc: const Color(0xFF7A1700)),
        _t('خصم حتى 50%', f: 'Cairo', sz: 90, y: 360)])),
  Tpl('مينيمال', () => _c(Colors.white, [
        _t('less\nis more', f: 'Montserrat', sz: 200, c: Colors.black)])),
  Tpl('قهوة', () => _g(const Color(0xFF3E2723), const Color(0xFF8D6E63), 90,
      [_t('☕', sz: 320, y: -120), _t('Coffee Time', f: 'Lobster', sz: 170, y: 160)])),
  Tpl('تهنئة', () => _g(const Color(0xFF0F5132), const Color(0xFF198754), 90,
      [_t('🌙', sz: 280, y: -330), _t('عيد مبارك', f: 'Reem Kufi', sz: 250, sh: 24)])),
];
