import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/font_service.dart';
import '../../../core/theme/app_theme.dart';

/// شاشة اختيار الخط: تبويبات (خطوطي / عربي / إنجليزي) وقائمة مرقّمة بمعاينة كل خط.
/// تعيد اسم الخط المختار أو null.
Future<String?> showFontPicker(BuildContext context, String current) {
  return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _FontPicker(current: current)));
}

class _FontPicker extends StatefulWidget {
  const _FontPicker({required this.current});
  final String current;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  Future<void> _upload() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null) return;
    final fam = await FontService.addCustom(path);
    if (!mounted) return;
    if (fam == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف يجب أن يكون ttf أو otf')));
    } else {
      setState(() {});
    }
  }

  Widget _list(List<String> fonts, String sample, {Widget? header}) {
    return ListView.builder(
      itemCount: fonts.length + (header == null ? 0 : 1),
      itemBuilder: (context, i) {
        if (header != null && i == 0) return header;
        final idx = header == null ? i : i - 1;
        final f = fonts[idx];
        final sel = f == widget.current;
        return InkWell(
          onTap: () async {
            await FontService.ensure(f);
            if (context.mounted) Navigator.pop(context, f);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
            child: Row(
              children: [
                SizedBox(width: 30, child: Text('${idx + 1}', style: TextStyle(color: sel ? AppColors.accent : AppColors.muted))),
                Expanded(
                  child: Text(
                    sample,
                    style: FontService.style(f, size: 24, color: sel ? AppColors.accent : AppColors.text),
                  ),
                ),
                Text(f, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = FontService.custom;
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الخطوط'),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            tabs: [Tab(text: 'خطوطي'), Tab(text: 'عربي'), Tab(text: 'إنجليزي')],
          ),
        ),
        body: TabBarView(
          children: [
            _list(
              mine,
              'نص تجريبي Abc',
              header: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                  onPressed: _upload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('إضافة خط من جهازك (ttf / otf)'),
                ),
              ),
            ),
            _list(FontService.arabic, 'أبجد هوز حطي 123'),
            _list(FontService.latin, 'Abcdef Ghij 123'),
          ],
        ),
      ),
    );
  }
}
