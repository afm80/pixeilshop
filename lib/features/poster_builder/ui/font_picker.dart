import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/font_service.dart';
import '../../../core/theme/app_theme.dart';

/// شاشة اختيار الخط: ✕ / عنوان / ✓ ، تبويبات (خطوطي · عربي · إنجليزي) وتبويبات فرعية للعربي،
/// وقائمة مرقّمة تُعلَّم فيها الخط المختار بخلفية صفراء. تعيد اسم الخط عند ✓ أو null.
Future<String?> showFontPicker(BuildContext context, String current) {
  return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _FontPicker(current: current)));
}

const _yellow = Color(0xFFFFC400);

/// تصنيف الخطوط العربية.
const Map<String, List<String>> _arabicGroups = {
  'إعلانية': ['Lalezar', 'Changa', 'Marhey', 'Rakkas', 'Lemonada', 'Readex Pro'],
  'نسخ و ثلث': ['Amiri', 'Harmattan', 'Mada'],
  'رقعة وفارسي': ['Aref Ruqaa', 'Katibeh'],
  'ديواني وكوفي': ['Reem Kufi', 'Noto Kufi Arabic', 'Jomhuria'],
  'أخرى': ['Cairo', 'Tajawal', 'Almarai', 'El Messiri', 'IBM Plex Sans Arabic'],
};

class _FontPicker extends StatefulWidget {
  const _FontPicker({required this.current});
  final String current;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  late String _sel = widget.current;
  String _group = _arabicGroups.keys.first;

  Future<void> _upload() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null) return;
    final fam = await FontService.addCustom(path);
    if (!mounted) return;
    if (fam == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف يجب أن يكون ttf أو otf')));
    } else {
      setState(() => _sel = fam);
    }
  }

  Widget _list(List<String> fonts, String sample, {Widget? header}) {
    return Column(
      children: [
        if (header != null) header,
        Expanded(
          child: ListView.builder(
            itemCount: fonts.length,
            itemBuilder: (context, i) {
              final f = fonts[i];
              final sel = f == _sel;
              return InkWell(
                onTap: () async {
                  await FontService.ensure(f);
                  if (mounted) setState(() => _sel = f);
                },
                child: Container(
                  height: 76,
                  color: sel ? _yellow : Colors.transparent,
                  decoration: sel ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Center(child: Text('${i + 1}', style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 15))),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              sample,
                              style: FontService.style(f, size: 28, color: sel ? Colors.black : Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _subTabs() {
    return Container(
      height: 46,
      color: const Color(0xFF2B2B2B),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final g in _arabicGroups.keys)
              InkWell(
                onTap: () => setState(() => _group = g),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _group == g ? const Color(0xFF3A3A3A) : null,
                    border: Border(bottom: BorderSide(color: _group == g ? Colors.white : Colors.transparent, width: 2)),
                  ),
                  child: Text(g, style: const TextStyle(fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fonts = (_arabicGroups[_group] ?? const <String>[]).where(FontService.arabic.contains).toList();
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        backgroundColor: const Color(0xFF212121),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 56,
                color: const Color(0xFF252525),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _yellow, size: 32)),
                      const Expanded(child: Center(child: Text('Fonts', style: TextStyle(color: _yellow, fontSize: 17)))),
                      IconButton(onPressed: () => Navigator.pop(context, _sel), icon: const Icon(Icons.check, color: _yellow, size: 32)),
                    ],
                  ),
                ),
              ),
              Container(
                color: const Color(0xFF252525),
                child: const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [Tab(text: 'خطوطي'), Tab(text: 'عربي'), Tab(text: 'إنجليزي')],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _list(
                      FontService.custom,
                      'مرحبا  Abc',
                      header: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: _yellow, foregroundColor: Colors.black),
                          onPressed: _upload,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('إضافة خط من جهازك (ttf / otf)'),
                        ),
                      ),
                    ),
                    Column(children: [_subTabs(), Expanded(child: _list(fonts, 'مرحبا'))]),
                    _list(FontService.latin, 'How are you'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
