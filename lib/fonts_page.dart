import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui.dart';

/// يرجع الخط المطلوب، وإن لم يوجد في الحزمة يرجع Cairo بدل أن ينهار التطبيق
TextStyle gf(String name, {TextStyle? textStyle}) {
  try {
    return GoogleFonts.getFont(name, textStyle: textStyle);
  } catch (_) {
    return GoogleFonts.getFont('Cairo', textStyle: textStyle);
  }
}

const kArabicFonts = <String, List<String>>{
  'إعلانية': ['Lalezar', 'Changa', 'Cairo', 'Tajawal', 'Almarai', 'Mada', 'El Messiri', 'Rakkas', 'Harmattan', 'Alexandria', 'Readex Pro', 'IBM Plex Sans Arabic', 'Noto Sans Arabic', 'Baloo Bhaijaan 2'],
  'نسخ و ثلث': ['Amiri', 'Markazi Text', 'Scheherazade New', 'Lateef', 'Noto Naskh Arabic', 'Amiri Quran'],
  'رقعة وفارسي': ['Aref Ruqaa', 'Aref Ruqaa Ink', 'Katibeh', 'Noto Nastaliq Urdu', 'Vazirmatn', 'Lemonada', 'Gulzar'],
  'ديواني وكوفي': ['Reem Kufi', 'Reem Kufi Fun', 'Noto Kufi Arabic', 'Kufam', 'Jomhuria', 'Mirza'],
};

const kEnglishFonts = <String, List<String>>{
  'عصرية': ['Montserrat', 'Oswald', 'Anton', 'Bebas Neue', 'Righteous', 'Poppins', 'Raleway'],
  'خطية': ['Pacifico', 'Lobster', 'Dancing Script', 'Great Vibes', 'Satisfy', 'Permanent Marker'],
  'كلاسيكية': ['Playfair Display', 'Merriweather', 'Cinzel', 'Abril Fatface', 'Lora'],
};

/// شاشة الخطوط (عربي / إنجليزي مع تصنيفات). ترجع اسم الخط عند ✓
class FontsPage extends StatefulWidget {
  const FontsPage({super.key, required this.current, required this.sample});
  final String current, sample;
  @override
  State<FontsPage> createState() => _FontsState();
}

class _FontsState extends State<FontsPage> {
  late String cur = widget.current;
  bool arabic = true;
  late String cat;

  Map<String, List<String>> get set => arabic ? kArabicFonts : kEnglishFonts;

  @override
  void initState() {
    super.initState();
    arabic = !kEnglishFonts.values.any((l) => l.contains(widget.current));
    cat = set.entries.firstWhere((e) => e.value.contains(widget.current), orElse: () => set.entries.first).key;
  }

  Widget tab(String t, bool on, VoidCallback f) => Expanded(
        child: InkWell(
          onTap: f,
          child: Container(
            height: 54, alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? const Color(0xFF333333) : null, border: on ? const Border(bottom: BorderSide(color: Colors.white24)) : null),
            child: Text(t, style: const TextStyle(fontSize: 14)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final list = set[cat] ?? const <String>[];
    final sample = widget.sample.trim().isEmpty ? (arabic ? 'اكتب هنا' : 'Write here') : widget.sample.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ');
    return Scaffold(
      body: DotBg(
        child: SafeArea(
          child: Column(children: [
            Container(
              height: 56, color: kPanel,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.close, color: kAccent, size: 30), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  const Text('Fonts', style: TextStyle(color: kAccent, fontSize: 17)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.check, color: kAccent, size: 30), onPressed: () => Navigator.pop(context, cur)),
                ]),
              ),
            ),
            Container(
              color: kPanel,
              child: Row(children: [
                tab('إنجليزي', !arabic, () => setState(() { arabic = false; cat = set.keys.first; })),
                tab('عربي', arabic, () => setState(() { arabic = true; cat = set.keys.first; })),
              ]),
            ),
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final c in set.keys)
                  InkWell(
                    onTap: () => setState(() => cat = c),
                    child: Container(
                      alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 18),
                      color: cat == c ? const Color(0xFF333333) : null,
                      child: Text(c, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final f = list[i], on = f == cur;
                  return InkWell(
                    onTap: () => setState(() => cur = f),
                    child: Container(
                      height: 78, color: on ? kAccent : kPanel, margin: const EdgeInsets.only(bottom: 1),
                      child: Row(children: [
                        SizedBox(width: 44, child: Center(child: Text('${i + 1}', style: TextStyle(color: on ? Colors.black : Colors.white70)))),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(sample, maxLines: 1,
                                    style: gf(f, textStyle: TextStyle(fontSize: 30, color: on ? Colors.black : Colors.white))),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
