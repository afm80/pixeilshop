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
  Tpl('رمضان', () => _g(const Color(0xFF1A237E), const Color(0xFF4A148C), 90,
      [_t('🌙', sz: 300, y: -380), _t('رمضان كريم', f: 'Reem Kufi', sz: 240, c: const Color(0xFFFFD54F), sh: 30, sc: const Color(0xFFFFD54F)),
       _t('كل عام وأنتم بخير', sz: 80, y: 330, b: false)])),
  Tpl('عيد الأضحى', () => _g(const Color(0xFF004D40), const Color(0xFF00897B), 90,
      [_t('عيد أضحى مبارك', f: 'Lalezar', sz: 210, sh: 24), _t('تقبل الله طاعتكم', f: 'Amiri', sz: 90, y: 330, c: const Color(0xFFFFE082))])),
  Tpl('جمعة مباركة', () => _g(const Color(0xFF263238), const Color(0xFF455A64), 90,
      [_t('جمعة مباركة', f: 'Aref Ruqaa', sz: 260, c: const Color(0xFFFFD54F)), _t('اللهم صل وسلم على نبينا محمد', f: 'Amiri', sz: 80, y: 330)])),
  Tpl('دعاء', () => _c(const Color(0xFF102027), [
        _t('﷽', f: 'Amiri', sz: 240, y: -420, c: const Color(0xFFD4AF37)),
        _t('اللهم اجعل هذا اليوم\nخيراً وبركة علينا', f: 'Amiri', sz: 110, c: Colors.white)])),
  Tpl('حكمة', () => _c(const Color(0xFFFFF8E1), [
        _t('❝', f: 'Amiri', sz: 300, y: -420, c: const Color(0xFFFF8F00)),
        _t('من جدّ وجد\nومن زرع حصد', f: 'Aref Ruqaa', sz: 170, c: const Color(0xFF3E2723))])),
  Tpl('صباح الخير', () => _g(const Color(0xFFFFB300), const Color(0xFFFF6F00), 90,
      [_t('☀️', sz: 340, y: -300), _t('صباح الخير', f: 'Lalezar', sz: 250, sh: 20), _t('يوم سعيد', sz: 80, y: 330, b: false)])),
  Tpl('مساء الخير', () => _g(const Color(0xFF283593), const Color(0xFF6A1B9A), 90,
      [_t('🌙', sz: 280, y: -300), _t('مساء الخير', f: 'Reem Kufi', sz: 230, sh: 20)])),
  Tpl('تخرج', () => _c(Colors.black, [
        _t('🎓', sz: 300, y: -330), _t('مبروك التخرج', f: 'Lalezar', sz: 220, c: const Color(0xFFD4AF37)),
        _t('بداية طريق النجاح', sz: 80, y: 300, c: Colors.white70, b: false)])),
  Tpl('عرض عربي', () => _g(const Color(0xFFD50000), const Color(0xFFFF5252), 90,
      [_t('تخفيضات', f: 'Lalezar', sz: 300, dp: 30, sc: const Color(0xFF7F0000)), _t('تصل إلى 70%', sz: 130, y: 300),
       _t('لفترة محدودة', sz: 70, y: 480, b: false)])),
  Tpl('افتتاح', () => _g(const Color(0xFF0D47A1), const Color(0xFF42A5F5), 90,
      [_t('افتتاح قريباً', f: 'Lalezar', sz: 230, sh: 24), _t('ترقبونا', f: 'Aref Ruqaa', sz: 130, y: 280, c: const Color(0xFFFFEE58))])),
  Tpl('شكر', () => _c(const Color(0xFFFCE4EC), [
        _t('شكراً لكم', f: 'Aref Ruqaa', sz: 260, c: const Color(0xFFAD1457)), _t('💖', sz: 200, y: 320)])),
  Tpl('اسم / توقيع', () => _g(const Color(0xFF212121), const Color(0xFF000000), 90,
      [_t('اسمك هنا', f: 'Lalezar', sz: 280, sh: 40, sc: const Color(0xFF00E5FF), c: Colors.white),
       _t('@username', f: 'Montserrat', sz: 60, y: 260, sp: 6, b: false)])),
];
