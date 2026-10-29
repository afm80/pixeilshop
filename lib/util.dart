import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';

class Pic {
  Pic(this.path, this.w, this.h);
  final String path;
  final double w, h;
}

/// اختيار صورة من المعرض ونسخها لمجلد التطبيق حتى لا تضيع.
Future<Pic?> pickImg() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
  if (x == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final ext = x.path.contains('.') ? x.path.split('.').last : 'jpg';
  final f = await File(x.path).copy('${dir.path}/img_${DateTime.now().microsecondsSinceEpoch}.$ext');
  final im = await decodeImageFromList(await f.readAsBytes());
  return Pic(f.path, im.width.toDouble(), im.height.toDouble());
}

/// حفظ تلقائي للتصاميم في SharedPreferences.
class Store {
  static const _k = 'designs';
  static Future<List<Map<String, dynamic>>> all() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_k) ?? []).map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  static Future<void> save(String id, Doc d, {String? name, String? thumb}) async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? [];
    final i = l.indexWhere((e) => jsonDecode(e)['id'] == id);
    final old = i >= 0 ? Map<String, dynamic>.from(jsonDecode(l[i])) : <String, dynamic>{};
    final m = jsonEncode({
      'id': id, 'ts': DateTime.now().millisecondsSinceEpoch, 'doc': d.toJson(),
      'name': name ?? old['name'], 'thumb': thumb ?? old['thumb'],
    });
    if (i >= 0) { l[i] = m; } else { l.insert(0, m); }
    await p.setStringList(_k, l);
  }

  static Future<void> rename(String id, String name) async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? [];
    final i = l.indexWhere((e) => jsonDecode(e)['id'] == id);
    if (i < 0) return;
    final m = Map<String, dynamic>.from(jsonDecode(l[i]))..['name'] = name;
    l[i] = jsonEncode(m);
    await p.setStringList(_k, l);
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? [];
    l.removeWhere((e) => jsonDecode(e)['id'] == id);
    await p.setStringList(_k, l);
  }
}

Future<String?> askText(BuildContext c, String title, String init, {bool multi = false}) {
  final t = TextEditingController(text: init);
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, autofocus: true, minLines: 1, maxLines: multi ? 5 : 1),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, t.text), child: const Text('موافق')),
      ],
    ),
  );
}

Future<Color?> pickColorDialog(BuildContext c, Color cur) {
  var v = cur;
  return showDialog<Color>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: SingleChildScrollView(
        child: ColorPicker(pickerColor: cur, onColorChanged: (x) => v = x, enableAlpha: false, labelTypes: const [], pickerAreaHeightPercent: .7),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, v), child: const Text('موافق')),
      ],
    ),
  );
}

/// القطّارة: تعرض لقطة من التصميم وتقرأ لون البكسل الذي تلمسه.
class EyedropPage extends StatefulWidget {
  const EyedropPage(this.img, this.data, {super.key});
  final ui.Image img;
  final ByteData data;
  @override
  State<EyedropPage> createState() => _EyeState();
}

class _EyeState extends State<EyedropPage> {
  Offset? p;
  Color c = Colors.white;

  void pick(Offset o, Size s) {
    final w = widget.img.width, h = widget.img.height;
    final x = (o.dx / s.width * w).clamp(0, w - 1).toInt();
    final y = (o.dy / s.height * h).clamp(0, h - 1).toInt();
    final i = (y * w + x) * 4, d = widget.data;
    setState(() {
      p = o;
      c = Color.fromARGB(d.getUint8(i + 3), d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('القطّارة'), actions: [
          TextButton(onPressed: () => Navigator.pop(context, c), child: const Text('تم')),
        ]),
        body: Center(
          child: AspectRatio(
            aspectRatio: widget.img.width / widget.img.height,
            child: LayoutBuilder(builder: (_, bc) {
              final s = bc.biggest;
              return GestureDetector(
                onPanDown: (d) => pick(d.localPosition, s),
                onPanUpdate: (d) => pick(d.localPosition, s),
                child: Stack(children: [
                  Positioned.fill(child: RawImage(image: widget.img, fit: BoxFit.fill)),
                  if (p != null)
                    Positioned(left: p!.dx - 30, top: p!.dy - 100,
                        child: Container(width: 60, height: 60,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)))),
                  if (p != null)
                    Positioned(left: p!.dx - 8, top: p!.dy - 8,
                        child: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                ]),
              );
            }),
          ),
        ),
      );
}
