import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_matrices.dart';
import '../poster_builder/ui/editor_page.dart';
import 'capture_preview_page.dart';

/// كاميرا بأسلوب سناب شات / قصص إنستغرام (تُفتح من مربع «الكامرة» في الشاشة الرئيسية):
/// معاينة ملء الشاشة، فلاتر مباشرة (تمرير أفقي في الشريط السفلي)، تبديل أمامي/خلفي،
/// فلاش، مؤقت، تكبير بالقرص، ضغطتان للتبديل، ولمسة للتركيز.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, this.active = true, this.bottomReserved = 0});

  /// false = الصفحة غير ظاهرة فتُغلق الكاميرا لتوفير البطارية.
  final bool active;

  /// مسافة سفلية محجوزة (لشريط التبويبات في الصفحة الرئيسية).
  final double bottomReserved;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  CameraController? _ctrl;
  bool _starting = false;
  String? _error;

  FlashMode _flash = FlashMode.off;
  int _timer = 0; // 0 / 3 / 10 ثوانٍ
  int _countdown = 0;
  bool _busy = false;

  double _minZoom = 1, _maxZoom = 1, _zoom = 1;
  final Map<int, Offset> _pointers = {};
  double _pinchStartDist = 0, _pinchStartZoom = 1;

  int _filter = 0;
  // عرض خانة الفلتر ثابت (66px) فتتجاور الدوائر بدل أن تتباعد على الشاشات العريضة
  late final PageController _filterCtrl = PageController(viewportFraction: _filterFraction());

  double _filterFraction() {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    final w = v.physicalSize.width / v.devicePixelRatio;
    return (66 / w).clamp(0.08, 0.3).toDouble();
  }

  Offset? _focusPos;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant CameraPage old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      widget.active ? _start() : _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stop();
    } else if (state == AppLifecycleState.resumed && widget.active) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _filterCtrl.dispose();
    final c = _ctrl;
    _ctrl = null;
    c?.dispose();
    super.dispose();
  }

  // ───────────────────────── تشغيل / إيقاف ─────────────────────────

  Future<void> _start() async {
    if (_starting || _ctrl != null) return;
    _starting = true;
    if (mounted) setState(() => _error = null);
    try {
      if (_cams.isEmpty) {
        _cams = await availableCameras();
        // الكاميرا الأمامية هي الافتراضية، فإن لم توجد نستخدم أول كاميرا متاحة
        final front = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _camIndex = front < 0 ? 0 : front;
      }
      if (_cams.isEmpty) throw CameraException('none', 'لا توجد كاميرا في هذا الجهاز');
      await _open(_camIndex);
    } on CameraException catch (e) {
      _error = _message(e);
    } catch (e) {
      _error = 'تعذر تشغيل الكاميرا: $e';
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _open(int index) async {
    final old = _ctrl;
    _ctrl = null;
    if (mounted) setState(() {});
    await old?.dispose();

    final c = CameraController(
      _cams[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = math.min(await c.getMaxZoomLevel(), 8.0);
      _zoom = 1.0.clamp(_minZoom, _maxZoom).toDouble();
      try {
        await c.setFlashMode(_flash);
      } catch (_) {}
    } catch (e) {
      await c.dispose();
      rethrow;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    _ctrl = c;
    _camIndex = index;
  }

  Future<void> _stop() async {
    final c = _ctrl;
    if (c == null) return;
    _ctrl = null;
    if (mounted) setState(() {});
    await c.dispose();
  }

  String _message(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'إذن الكاميرا مرفوض.\nفعّله من إعدادات الجهاز ثم أعد المحاولة.';
      default:
        return 'تعذر تشغيل الكاميرا${e.description == null ? '' : '\n${e.description}'}';
    }
  }

  // ───────────────────────── الأدوات ─────────────────────────

  bool get _isFront => _ctrl?.description.lensDirection == CameraLensDirection.front;

  Future<void> _flip() async {
    if (_cams.length < 2 || _busy || _starting) return;
    _starting = true;
    HapticFeedback.selectionClick();
    final next = _cams.indexWhere(
      (c) => c.lensDirection != _cams[_camIndex].lensDirection,
    );
    try {
      await _open(next < 0 ? (_camIndex + 1) % _cams.length : next);
    } catch (e) {
      _error = 'تعذر تبديل الكاميرا';
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    setState(() => _flash = next);
    try {
      await _ctrl?.setFlashMode(next);
    } catch (_) {}
  }

  void _cycleTimer() => setState(() => _timer = _timer == 0 ? 3 : (_timer == 3 ? 10 : 0));

  void _setZoom(double z) {
    final v = z.clamp(_minZoom, _maxZoom).toDouble();
    if ((v - _zoom).abs() < 0.01) return;
    _zoom = v;
    _ctrl?.setZoomLevel(v).catchError((_) {});
    setState(() {});
  }

  double _pointerDist() {
    final p = _pointers.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _focus(Offset local, Size size) {
    final c = _ctrl;
    if (c == null || size.isEmpty) return;
    final pt = Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));
    c.setFocusPoint(pt).catchError((_) {});
    c.setExposurePoint(pt).catchError((_) {});
    _focusTimer?.cancel();
    setState(() => _focusPos = local);
    _focusTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPos = null);
    });
  }

  Future<void> _capture() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      for (var i = _timer; i > 0; i--) {
        if (!mounted) return;
        setState(() => _countdown = i);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _countdown = 0);

      HapticFeedback.mediumImpact();
      final x = await c.takePicture();
      final m = await MediaService.importFile(x.path);
      try {
        await File(x.path).delete();
      } catch (_) {}
      if (!mounted) return;

      final mirror = c.description.lensDirection == CameraLensDirection.front;
      try {
        await c.pausePreview();
      } catch (_) {}
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CapturePreviewPage(photo: m, preset: _filter, mirror: mirror)),
      );
      try {
        await _ctrl?.resumePreview();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الالتقاط: $e')));
      }
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _countdown = 0;
      });
    }
  }

  Future<void> _fromGallery() async {
    final m = await MediaService.pick();
    if (m == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorPage(doc: docFromPhoto(m))));
  }

  // ───────────────────────── الواجهة ─────────────────────────

  Widget _preview(CameraController c) {
    final ps = c.value.previewSize;
    if (ps == null) return const SizedBox.shrink();
    // previewSize أفقي دائماً، والشاشة عمودية.
    Widget cam = CameraPreview(c);
    if (_filter != 0) {
      cam = ColorFiltered(colorFilter: ColorFilter.matrix(ColorMatrices.presets[_filter].matrix), child: cam);
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: ps.height, height: ps.width, child: cam),
      ),
    );
  }

  Widget _topBar() {
    if ((_zoom - 1).abs() <= 0.05) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
        child: Text('${_zoom.toStringAsFixed(1)}×', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// أيقونات عمودية على الجانب (قلب الكاميرا، الفلاش، المؤقت، الاستوديو).
  Widget _sideBar() {
    final flashIcon = _flash == FlashMode.off
        ? Icons.flash_off_rounded
        : (_flash == FlashMode.auto ? Icons.flash_auto_rounded : Icons.flash_on_rounded);
    final timerIcon = _timer == 0 ? Icons.timer_off_outlined : (_timer == 3 ? Icons.timer_3 : Icons.timer_10);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CamSideBtn(icon: Icons.flip_camera_ios_rounded, tip: 'قلب الكاميرا', onTap: _cams.length > 1 ? _flip : null),
          if (!_isFront) CamSideBtn(icon: flashIcon, tip: 'الفلاش', onTap: _cycleFlash, active: _flash != FlashMode.off),
          CamSideBtn(icon: timerIcon, tip: 'المؤقت', onTap: _cycleTimer, active: _timer != 0),
          CamSideBtn(icon: Icons.photo_library_rounded, tip: 'الاستوديو', onTap: _fromGallery),
        ],
      ),
    );
  }

  Widget _filterCarousel() {
    final presets = ColorMatrices.presets;
    return SizedBox(
      height: 72,
      child: PageView.builder(
        controller: _filterCtrl,
        itemCount: presets.length,
        onPageChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _filter = i);
        },
        itemBuilder: (_, i) {
          final p = presets[i];
          final sel = i == _filter;
          return GestureDetector(
            onTap: () => _filterCtrl.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: sel ? 60 : 46,
                height: sel ? 60 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [p.swatch1, p.swatch2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: sel ? Colors.white : Colors.white38, width: sel ? 3 : 1.5),
                ),
                child: i == 0 ? const Icon(Icons.block, color: Colors.white70, size: 20) : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _captureButton() => GestureDetector(
        onTap: _capture,
        child: AnimatedScale(
          scale: _busy ? 0.88 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
          ),
        ),
      );

  Widget _bottomBar() => Padding(
        padding: EdgeInsets.only(bottom: widget.bottomReserved + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: Text(
                _filter == 0 ? '' : ColorMatrices.presets[_filter].name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
              ),
            ),
            _filterCarousel(),
            const SizedBox(height: 10),
            _captureButton(),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 60, color: AppColors.muted),
              const SizedBox(height: 14),
              Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.5)),
              const SizedBox(height: 18),
              FilledButton(onPressed: _start, child: const Text('إعادة المحاولة')),
              const SizedBox(height: 8),
              TextButton(onPressed: _fromGallery, child: const Text('اختيار صورة من الاستوديو')),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    final ready = c != null && c.value.isInitialized;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_error != null && !ready)
              _errorView()
            else if (!ready)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else
              LayoutBuilder(
                builder: (context, box) => Listener(
                  onPointerDown: (e) {
                    _pointers[e.pointer] = e.position;
                    if (_pointers.length == 2) {
                      _pinchStartDist = _pointerDist();
                      _pinchStartZoom = _zoom;
                    }
                  },
                  onPointerMove: (e) {
                    if (!_pointers.containsKey(e.pointer)) return;
                    _pointers[e.pointer] = e.position;
                    if (_pointers.length == 2 && _pinchStartDist > 0) {
                      _setZoom(_pinchStartZoom * _pointerDist() / _pinchStartDist);
                    }
                  },
                  onPointerUp: (e) => _pointers.remove(e.pointer),
                  onPointerCancel: (e) => _pointers.remove(e.pointer),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _flip,
                    onTapUp: (d) => _focus(d.localPosition, box.biggest),
                    child: SizedBox.expand(child: _preview(c)),
                  ),
                ),
              ),
            if (_focusPos != null)
              Positioned(
                left: _focusPos!.dx - 32,
                top: _focusPos!.dy - 32,
                child: IgnorePointer(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.accent2, width: 2), borderRadius: BorderRadius.circular(32)),
                  ),
                ),
              ),
            if (ready) SafeArea(child: Align(alignment: Alignment.topCenter, child: _topBar())),
            if (ready) SafeArea(child: Align(alignment: Alignment.centerRight, child: _sideBar())),
            if (ready) SafeArea(child: Align(alignment: Alignment.bottomCenter, child: _bottomBar())),
            if (_countdown > 0)
              Center(
                child: IgnorePointer(
                  child: Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 16, color: Colors.black54)])),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CamBtn extends StatelessWidget {
  const _CamBtn({required this.icon, required this.onTap, this.size = 42});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white, size: size * 0.5)),
        ),
      );
}
