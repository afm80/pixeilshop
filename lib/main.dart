import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'editor.dart';
import 'model.dart';
import 'util.dart';
import 'color_bg.dart';
import 'ui.dart';
import 'user_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await UserFonts.init(); } catch (_) {}
  runApp(const App());
}

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
          appBarTheme: const AppBarTheme(backgroundColor: kPanel, elevation: 0),
          bottomSheetTheme: const BottomSheetThemeData(backgroundColor: kPanel),
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

const _ratios = <(String, double, double, IconData)>[
  ('مربع', 1080, 1080, Icons.crop_square),
  ('بوست 4:5', 1080, 1350, Icons.crop_portrait),
  ('ستوري 9:16', 1080, 1920, Icons.smartphone),
  ('أفقي 16:9', 1920, 1080, Icons.crop_landscape),
];

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> saved = [];
  int tab = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final s = await Store.all();
    if (mounted) setState(() => saved = s);
  }

  Future<void> open(Doc d, {String? id, String startTool = '', bool autoRmbg = false}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => EditorPage(d, id ?? DateTime.now().microsecondsSinceEpoch.toString(), startTool: startTool, autoRmbg: autoRmbg),
    ));
    refresh();
  }

  Doc photoDoc(Pic p) {
    final k = 1536 / max(p.w, p.h);
    final s = k < 1 ? k : 1.0;
    return Doc((p.w * s).roundToDouble(), (p.h * s).roundToDouble(), Bg(kind: 2, path: p.path), []);
  }

  Future<void> colorBg() async {
    final d = await Navigator.push<Doc>(context, MaterialPageRoute(builder: (_) => const ColorBgPage()));
    if (d != null && mounted) open(d);
  }

  void blank([double w = 1080, double h = 1080]) => open(Doc(w, h, Bg(c1: Colors.white), []));

  Future<void> fromGallery() async {
    final p = await pickImg();
    if (p != null && mounted) open(photoDoc(p));
  }

  // ---- الاستوديو ----
  Future<void> enhance({ImageSource source = ImageSource.gallery}) async {
    final p = await pickImg(source: source);
    if (p != null && mounted) open(photoDoc(p), startTool: 'bfilter');
  }

  Future<void> cutout() async {
    final p = await pickImg();
    if (p == null || !mounted) return;
    final s = 900 / max(p.w, p.h);
    open(
      Doc(1080, 1080, Bg(c1: Colors.white), [Layer(LT.image)..path = p.path..w = p.w * s..h = p.h * s]),
      autoRmbg: true,
    );
  }

  void resizePhoto() => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (n, w, h, i) in _ratios)
                ActionChip(
                  avatar: Icon(i, size: 18, color: kAccent), label: Text(n),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final p = await pickImg();
                    if (p != null && mounted) open(Doc(w, h, Bg(kind: 2, path: p.path), []));
                  },
                ),
            ]),
          ),
        ),
      );

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

  // ---- عناصر مشتركة ----
  Widget card({required IconData icon, required String title, String? sub, required VoidCallback onTap, bool primary = false}) {
    final fg = primary ? Colors.black : Colors.white;
    return Material(
      color: primary ? kAccent : kCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 30, color: primary ? Colors.black : kAccent),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(fontSize: 12, color: primary ? Colors.black87 : Colors.white60)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget grid(List<Widget> kids, {double ratio = 1.3}) => GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: ratio, children: kids,
      );

  Widget title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70)),
      );

  Widget thumb(Map<String, dynamic> s) {
    final t = s['thumb'] as String?;
    return t != null && File(t).existsSync()
        ? Image.file(File(t), fit: BoxFit.cover)
        : const Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 36));
  }

  String nameOf(Map<String, dynamic> s) =>
      (s['name'] as String?) ?? DateTime.fromMillisecondsSinceEpoch(s['ts'] as int).toString().substring(0, 16);

  void openSaved(Map<String, dynamic> s) => open(Doc.fromJson(Map<String, dynamic>.from(s['doc'])), id: s['id'] as String);

  // ---- الأقسام ----
  Widget designsTab() => ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 130,
          child: card(icon: Icons.add_circle_outline, title: 'تصميم جديد', sub: 'صفحة فارغة بيضاء ١٠٨٠ × ١٠٨٠', primary: true, onTap: blank),
        ),
        title('ابدأ من'),
        grid([
          card(icon: Icons.palette_outlined, title: 'خلفية ملونة', sub: 'لون أو تدرج', onTap: colorBg),
          card(icon: Icons.photo_outlined, title: 'من صورتك', sub: 'صمّم فوق صورة', onTap: fromGallery),
        ]),
        title('المقاسات'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (n, w, h, i) in _ratios)
            ActionChip(avatar: Icon(i, size: 18, color: kAccent), label: Text(n), onPressed: () => blank(w, h)),
        ]),
        if (saved.isNotEmpty) ...[
          title('آخر أعمالك'),
          SizedBox(
            height: 130,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final s in saved.take(8))
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: GestureDetector(
                    onTap: () => openSaved(s),
                    child: ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 110, child: ColoredBox(color: kCard, child: thumb(s)))),
                  ),
                ),
            ]),
          ),
        ],
      ]);

  Widget studioTab() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('استوديو الصور', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('اختر صورة وحسّنها في خطوات سريعة', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 16),
        grid([
          card(icon: Icons.auto_fix_high, title: 'تحسين وفلاتر', sub: 'فلاتر وإضاءة وألوان', primary: true, onTap: enhance),
          card(icon: Icons.content_cut, title: 'إزالة الخلفية', sub: 'عزل الشخص أو المنتج', onTap: cutout),
          card(icon: Icons.aspect_ratio, title: 'تغيير المقاس', sub: 'ستوري، بوست، أفقي', onTap: resizePhoto),
          card(icon: Icons.edit_note, title: 'نص على صورة', sub: 'اكتب فوق صورتك', onTap: fromGallery),
        ]),
        const SizedBox(height: 14),
        const Text('إزالة الخلفية تتم عبر خدمة remove.bg وتحتاج إنترنت ومفتاحاً مجانياً يُطلب منك مرة واحدة.',
            style: TextStyle(fontSize: 12, color: Colors.white38)),
      ]);

  Widget cameraTab() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kCard, border: Border.all(color: kAccent, width: 4)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => enhance(source: ImageSource.camera),
                child: const Icon(Icons.camera_alt_rounded, size: 64, color: kAccent),
              ),
            ),
            const SizedBox(height: 22),
            const Text('التقط صورة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('تُفتح الصورة مباشرة مع الفلاتر والتعديلات', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => enhance(),
              icon: const Icon(Icons.photo_library_outlined, color: kAccent),
              label: const Text('أو اختر من المعرض'),
            ),
          ]),
        ),
      );

  Widget projectsTab() => saved.isEmpty
      ? const Center(child: Text('لا توجد مشاريع محفوظة بعد', style: TextStyle(color: Colors.white54)))
      : GridView.count(
          crossAxisCount: 2, padding: const EdgeInsets.all(16), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .85,
          children: [
            for (final s in saved)
              GestureDetector(
                onTap: () => openSaved(s),
                child: Container(
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: thumb(s)),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10, end: 2),
                      child: Row(children: [
                        Expanded(child: Text(nameOf(s), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white54),
                          onPressed: () async { await Store.delete(s['id'] as String); await refresh(); },
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final pages = [designsTab(), studioTab(), cameraTab(), projectsTab()];
    return Scaffold(
      body: DotBg(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                Image.asset('assets/logo.png', height: 34, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                const SizedBox(width: 10),
                const Text('Pixeilshop', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kAccent)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: exitDialog),
              ]),
            ),
            Expanded(child: pages[tab]),
          ]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: kPanel,
        indicatorColor: kAccent.withOpacity(.2),
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize, color: kAccent), label: 'تصاميم'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome, color: kAccent), label: 'استوديو'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt, color: kAccent), label: 'كاميرا'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder, color: kAccent), label: 'مشاريعي'),
        ],
      ),
    );
  }
}
