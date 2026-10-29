import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'editor.dart';
import 'model.dart';
import 'templates.dart';
import 'util.dart';
import 'color_bg.dart';
import 'ui.dart';
import 'package:flutter/services.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pixeilshop',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kAccent, onPrimary: Colors.black, surface: kPanel),
          textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF202020), elevation: 0),
          bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF202020)),
        ),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> saved = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final s = await Store.all();
    if (mounted) setState(() => saved = s);
  }

  Future<void> open(Doc d, [String? id]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(d, id ?? DateTime.now().microsecondsSinceEpoch.toString())));
    refresh();
  }

  Future<void> colorBg() async {
    final d = await Navigator.push<Doc>(context, MaterialPageRoute(builder: (_) => const ColorBgPage()));
    if (d != null && mounted) open(d);
  }

  void blank() => open(Doc(1024, 1024, Bg(c1: Colors.white), []));

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

  Future<void> fromGallery() async {
    final p = await pickImg();
    if (p == null) return;
    final k = 1536 / (p.w > p.h ? p.w : p.h);
    final s = k < 1 ? k : 1.0;
    open(Doc((p.w * s).roundToDouble(), (p.h * s).roundToDouble(), Bg(kind: 2, path: p.path), []));
  }

  void templates() => showModalBottomSheet(
        context: context,
        builder: (ctx) => GridView.count(
          crossAxisCount: 3, padding: const EdgeInsets.all(12), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .8,
          children: [
            for (final t in kTpls)
              InkWell(
                onTap: () { Navigator.pop(ctx); open(t.build()); },
                child: Container(alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.build().bg.c1, borderRadius: BorderRadius.circular(8),
                        gradient: t.build().bg.kind == 1 ? LinearGradient(colors: [t.build().bg.c1, t.build().bg.c2]) : null),
                    child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)]))),
              ),
          ],
        ),
      );

  void savedSheet() => showModalBottomSheet(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => saved.isEmpty
              ? const SizedBox(height: 160, child: Center(child: Text('لا توجد تصاميم محفوظة بعد')))
              : ListView(children: [
                  for (final s in saved)
                    ListTile(
                      leading: SizedBox(
                        width: 48, height: 48,
                        child: s['thumb'] != null && File(s['thumb'] as String).existsSync()
                            ? Image.file(File(s['thumb'] as String), fit: BoxFit.cover)
                            : const Icon(Icons.image_outlined),
                      ),
                      title: Text((s['name'] as String?) ?? DateTime.fromMillisecondsSinceEpoch(s['ts'] as int).toString().substring(0, 16)),
                      subtitle: Text('${(s['doc']['ls'] as List).length} طبقة'),
                      onTap: () { Navigator.pop(ctx); open(Doc.fromJson(Map<String, dynamic>.from(s['doc'])), s['id'] as String); },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async { await Store.delete(s['id'] as String); await refresh(); set(() {}); },
                      ),
                    ),
                ]),
        ),
      );

  bool expanded = false;
  Color tint = Colors.white;
  static const _strip = [
    Colors.white, Color(0xFFFF6F61), Color(0xFFF44336), Color(0xFFFF0055), Color(0xFFE91E63), Color(0xFF9C27B0),
    Color(0xFF673AB7), Color(0xFF3F51B5), Color(0xFF2196F3), Color(0xFF00BCD4), Color(0xFF009688),
    Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFCDDC39),
  ];

  @override
  Widget build(BuildContext context) {
    Widget box({required Widget child, VoidCallback? onTap}) => Material(
          color: kPanel,
          child: InkWell(onTap: onTap, child: child),
        );
    Widget bigTile(IconData i, String t, VoidCallback f) => box(
          onTap: f,
          child: SizedBox(height: 125, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 44, color: kAccent), const SizedBox(height: 10), Text(t, style: const TextStyle(fontSize: 15)),
          ])),
        );
    Widget opt(IconData i, String t, VoidCallback f) => Expanded(
          child: InkWell(
            onTap: f,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Icon(i, color: kAccent, size: 22), const SizedBox(width: 12), Text(t, style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: DotBg(
        child: SafeArea(
          child: Column(children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                BarBtn(Icons.more_vert, 'خيارات', exitDialog),
                Expanded(
                  child: SizedBox(
                    height: 66,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                      for (final k in _strip)
                        GestureDetector(
                          onTap: () => setState(() => tint = k),
                          child: Container(
                            width: 52, margin: const EdgeInsets.fromLTRB(3, 13, 3, 13),
                            decoration: BoxDecoration(color: k, borderRadius: BorderRadius.circular(6),
                                border: tint == k ? Border.all(color: kAccent, width: 3) : null),
                          ),
                        ),
                    ]),
                  ),
                ),
                BarBtn(Icons.movie_outlined, 'شروحات', () => showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(backgroundColor: kPanel, content: Text('الشروحات قريباً')),
                    )),
              ]),
            ),
            const Spacer(flex: 2),
            ColorFiltered(
              colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
              child: Image.asset('assets/logo.png', width: 300),
            ),
            const Spacer(flex: 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  SizedBox(
                    height: 125,
                    child: Row(children: [
                      Expanded(
                        child: expanded
                            ? box(child: Column(children: [
                                opt(Icons.photo_outlined, 'من الاستوديو', () { setState(() => expanded = false); fromGallery(); }),
                                const Divider(height: 1, color: Colors.white10),
                                opt(Icons.palette_outlined, 'خلفية ملونة', () { setState(() => expanded = false); colorBg(); }),
                                const Divider(height: 1, color: Colors.white10),
                                opt(Icons.crop_portrait, 'تصميم فارغ', () { setState(() => expanded = false); blank(); }),
                              ]))
                            : bigTile(Icons.edit_note, 'تصميم جديد', () => setState(() => expanded = true)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(child: bigTile(Icons.brush_outlined, 'قوالب', templates)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  box(
                    onTap: savedSheet,
                    child: const SizedBox(height: 100, width: double.infinity, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.folder_open, color: kAccent, size: 34), SizedBox(width: 14), Text('تصاميم محفوظة', style: TextStyle(fontSize: 15)),
                    ])),
                  ),
                ]),
              ),
            ),
            const Padding(padding: EdgeInsets.all(12), child: Text('نسخة رقم 1.0', style: TextStyle(color: kAccent, fontSize: 13))),
            const Spacer(flex: 3),
          ]),
        ),
      ),
    );
  }
}
