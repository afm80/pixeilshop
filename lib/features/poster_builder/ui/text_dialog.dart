import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// نافذة كتابة النص (نص جديد / تعديل): شريط علوي (✕ عنوان ✓) وحقل كتابة بخط سفلي أصفر.
/// تعيد النص عند ✓ أو null عند ✕.
Future<String?> showTextDialog(BuildContext context, {String initial = '', String title = 'نص جديد'}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _TextDialog(initial: initial, title: title),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.initial, required this.title});
  final String initial, title;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFC400);
    return Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: const Color(0xFF343434),
      insetPadding: const EdgeInsets.fromLTRB(14, 56, 14, 0),
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 52,
            color: const Color(0xFF252525),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: yellow, size: 30)),
                  Expanded(child: Center(child: Text(widget.title, style: const TextStyle(fontSize: 14)))),
                  IconButton(onPressed: () => Navigator.pop(context, _c.text), icon: const Icon(Icons.check, color: yellow, size: 30)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: TextField(
              controller: _c,
              autofocus: true,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'المس هنا للبدء بالكتابة',
                hintStyle: TextStyle(color: AppColors.muted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: yellow)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: yellow)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
