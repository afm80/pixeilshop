import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/media_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../camera/camera_page.dart';
import '../poster_builder/model/doc.dart';
import '../poster_builder/model/layer.dart';
import '../poster_builder/ui/editor_page.dart';
import 'new_design_page.dart';
import '../templates/templates_page.dart';
import 'saved_page.dart';

const _tileColor = Color(0xFF252525);
const _orange = Color(0xFFF39B00);

/// شاشة البداية: الشعار والاسم، مربعا (التصميم / الكامرة) وزر التصاميم المحفوظة.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _menu = false;

  void _go(Widget page) {
    setState(() => _menu = false);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _fromGallery() async {
    setState(() => _menu = false);
    final m = await MediaService.pick();
    if (m == null || !mounted) return;
    final k = math.min(1.0, StorageService.maxImport / math.max(m.w, m.h));
    final w = (m.w * k).roundToDouble(), h = (m.h * k).roundToDouble();
    final d = Doc.blank(name: 'صورة', w: w, h: h);
    d.layers.add(Layer.create(LayerType.image, name: 'صورة')
      ..path = m.path
      ..x = w / 2
      ..y = h / 2
      ..w = w
      ..h = h);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(doc: d)));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final cw = math.min(sw * 0.86, 360.0);
    const gap = 10.0;
    final tile = (cw - gap) / 2;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF080808), Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
          ),
        ),
        child: Stack(
        children: [
          if (_menu) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _menu = false))),
          Center(
            child: SingleChildScrollView(
              child: SizedBox(
                width: cw,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/brand.png', width: cw * 0.78, fit: BoxFit.contain),
                      const SizedBox(height: 44),
                      Row(
                        children: [
                          SizedBox(
                            width: tile,
                            height: tile,
                            child: Stack(
                              children: [
                                _Tile(icon: Icons.palette_outlined, label: 'تصميم جديد', onTap: () => setState(() => _menu = !_menu)),
                                if (_menu)
                                  Positioned.fill(
                                    child: _DesignMenu(
                                      onGallery: _fromGallery,
                                      onColored: () => _go(const NewDesignPage(colored: true)),
                                      onBlank: () => _go(const NewDesignPage(colored: false)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(width: tile, height: tile, child: _Tile(icon: Icons.photo_camera_outlined, label: 'الكامرة', onTap: () => _go(const CameraPage()))),
                        ],
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        width: cw,
                        height: 62,
                        child: _Tile(icon: Icons.dashboard_customize_outlined, label: 'قوالب جاهزة', size: 17, row: true, onTap: () => _go(const TemplatesPage())),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        width: cw,
                        height: 62,
                        child: _Tile(icon: Icons.folder_open_outlined, label: 'تصاميم محفوظة', size: 17, row: true, onTap: () => _go(const SavedPage())),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('https://afm80.github.io/net'), mode: LaunchMode.externalApplication),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text('Alfaham Net', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.onTap, this.icon, this.size = 24, this.row = false});
  final String label;
  final IconData? icon;
  final bool row;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _orange.withValues(alpha: 0.28)),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E2E2E), Color(0xFF1E1E1E)]),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
          onTap: onTap,
          child: Center(
            child: Flex(
              direction: row ? Axis.horizontal : Axis.vertical,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, color: _orange, size: row ? 24 : 52),
                const SizedBox(width: 10, height: 10),
                Text(label, style: TextStyle(color: _orange, fontSize: size, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        ),
      );
}

/// القائمة المنبثقة فوق مربع التصميم.
class _DesignMenu extends StatelessWidget {
  const _DesignMenu({required this.onGallery, required this.onColored, required this.onBlank});
  final VoidCallback onGallery, onColored, onBlank;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, VoidCallback on) => Expanded(
          child: InkWell(
            onTap: on,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(icon, color: _orange, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 13))),
              ]),
            ),
          ),
        );
    return Material(
      color: _tileColor,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        item(Icons.image_outlined, 'من الاستوديو', onGallery),
        const Divider(height: 1, color: Colors.white10),
        item(Icons.palette_outlined, 'خلفية ملونة', onColored),
        const Divider(height: 1, color: Colors.white10),
        item(Icons.draw_outlined, 'تصميم فارغ', onBlank),
      ]),
    );
  }
}
