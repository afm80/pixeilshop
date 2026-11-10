import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/font_service.dart';
import '../../../core/services/user_fonts.g.dart';

/// شاشة اختيار الخط: ✕ / عنوان / ✓ ، ثلاثة تبويبات (خطوطي · عربي · إنجليزي) وقائمة مرقّمة واحدة لكل تبويب.
/// يُعلَّم الخط المختار بخلفية صفراء. تعيد اسم الخط عند ✓ أو null.
Future<String?> showFontPicker(BuildContext context, String current, {String sample = ''}) {
  return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _FontPicker(current: current, sample: sample)));
}

const _yellow = Color(0xFFFFC400);

List<String> _uniq(Iterable<String> a) {
  final seen = <String>{};
  return [for (final f in a) if (seen.add(f)) f];
}

class _FontPicker extends StatefulWidget {
  const _FontPicker({required this.current, required this.sample});
  final String current, sample;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  late String _sel = widget.current;

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
    final body = ListView.builder(
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
            decoration: BoxDecoration(
              color: sel ? _yellow : null,
              border: sel ? null : const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  SizedBox(width: 44, child: Center(child: Text('${i + 1}', style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 15)))),
                  Expanded(child: Center(child: Text(sample, maxLines: 1, overflow: TextOverflow.ellipsis, style: FontService.style(f, size: 26, color: sel ? Colors.black : Colors.white)))),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (header == null) return body;
    return Column(children: [header, Expanded(child: body)]);
  }

  @override
  Widget build(BuildContext context) {
    // خطوط المستخدم المدمجة أولاً (مرتّبة من السكربت) ثم المرفوعة من الجهاز ثم خطوط التطبيق
    final txt = widget.sample.trim().replaceAll('\n', ' ');
    final ar = _uniq([...kUserArabic, ...FontService.arabic]);
    final en = _uniq([...kUserLatin, ...FontService.latin]);
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
                child: TabBarView(children: [
                  FontService.custom.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('لا توجد خطوط مضافة'),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: _yellow, side: BorderSide.none, backgroundColor: const Color(0xFF2B2B2B)),
                              onPressed: _upload,
                              child: const Text('استعراض'),
                            ),
                          ]),
                        )
                      : _list(
                          FontService.custom,
                          txt.isEmpty ? 'مرحبا' : txt,
                          header: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: _upload, child: const Text('استعراض', style: TextStyle(color: _yellow))),
                          ),
                        ),
                  _list(ar, txt.isEmpty ? 'مرحبا' : txt),
                  _list(en, txt.isEmpty ? 'How are you' : txt),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
