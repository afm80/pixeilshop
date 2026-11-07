import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/export_service.dart';
import '../../../core/services/image_store.dart';
import '../../../core/services/mlkit_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/tflite_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai_copilot/bloc/copilot_bloc.dart';
import '../../ai_copilot/command_executor.dart';
import '../../ai_copilot/command_parser.dart';
import '../../anime_morph/bloc/anime_bloc.dart';
import '../../background_remover/background_remover_service.dart';
import '../../background_remover/bloc/subject_segmentation_bloc.dart';
import '../bloc/canvas_bloc.dart';
import '../model/doc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';
import 'editor_panel.dart';
import 'editor_toolbar.dart';
import 'export_sheet.dart';

/// startTool: '' | 'rmbg' | 'anime' | 'grade'
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.doc, this.startTool = ''});
  final Doc doc;
  final String startTool;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final CanvasBloc canvas;
  late final SubjectSegmentationBloc remover;
  late final AnimeBloc anime;
  late final CopilotBloc copilot;
  late final CommandExecutor exec;
  final ImageStore images = ImageStore();
  final EditorController controller = EditorController();
  final ValueNotifier<String?> popup = ValueNotifier<String?>(null);
  Timer? _saveTimer;
  BuildContext? _innerContext;

  @override
  void initState() {
    super.initState();
    canvas = CanvasBloc(widget.doc);
    remover = SubjectSegmentationBloc(BackgroundRemoverService(MlKitService()));
    anime = AnimeBloc(TfliteService());
    copilot = CopilotBloc(SpeechService());
    exec = CommandExecutor(
      canvas: canvas,
      remover: remover,
      anime: anime,
      onExport: () {
        final c = _innerContext;
        if (c != null) showExportSheet(c, canvas.state.doc, images);
      },
    );
    images.ensureDoc(widget.doc);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.startTool) {
        case 'rmbg':
          _toast(exec.execute(const RemoveBackgroundCmd()));
          break;
        case 'anime':
          _toast(exec.execute(const StyleCmd(StyleKind.anime)));
          break;
        case 'grade':
          popup.value = 'color';
          break;
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    canvas.close();
    remover.close();
    anime.close();
    copilot.close();
    controller.dispose();
    popup.dispose();
    images.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted || msg.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  /// نفك الصورة الجديدة أولاً ثم نستبدلها، فلا يظهر إطار فارغ أو قفزة.
  Future<void> _replaceImage(String layerId, ImageResult result) async {
    await images.ensure(result.path);
    if (mounted) canvas.add(ImageReplaced(layerId, result));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      StorageService.save(canvas.state.doc);
    });
  }

  Future<void> _persistAndLeave() async {
    _saveTimer?.cancel();
    final doc = canvas.state.doc;
    try {
      await StorageService.save(doc);
      await ExportService.thumbnail(doc, images, doc.id);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _editSelectedText(BuildContext ctx) {
    final l = canvas.state.selected;
    if (l != null && l.type == LayerType.text) showTextEditor(ctx, l);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: canvas),
        BlocProvider.value(value: remover),
        BlocProvider.value(value: anime),
        BlocProvider.value(value: copilot),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<CanvasBloc, CanvasState>(
            listener: (context, st) {
              images.ensureDoc(st.doc);
              _scheduleSave();
              if (controller.eraserLayerId != null && st.selectedId != controller.eraserLayerId) {
                controller.stopEraser();
              }
            },
          ),
          BlocListener<SubjectSegmentationBloc, SubjectSegmentationState>(
            listenWhen: (a, b) => a.serial != b.serial,
            listener: (context, st) {
              if (st.status == RemoverStatus.success && st.result != null && st.layerId != null) {
                _replaceImage(st.layerId!, st.result!);
              }
              if (st.status != RemoverStatus.working) _toast(st.message);
            },
          ),
          BlocListener<AnimeBloc, AnimeState>(
            listenWhen: (a, b) => a.serial != b.serial,
            listener: (context, st) {
              if (st.status == AnimeStatus.success && st.result != null && st.layerId != null) {
                _replaceImage(st.layerId!, st.result!);
              }
              if (st.status != AnimeStatus.working) _toast(st.message);
            },
          ),
          BlocListener<CopilotBloc, CopilotState>(
            listenWhen: (a, b) => (b.command != null && a.serial != b.serial) || (b.error.isNotEmpty && a.error != b.error),
            listener: (context, st) {
              if (st.error.isNotEmpty) _toast(st.error);
              final c = st.command;
              if (c != null) _toast(exec.execute(c));
            },
          ),
        ],
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _persistAndLeave();
          },
          child: Builder(builder: (ctx) {
            _innerContext = ctx;
            return Scaffold(
              // لوحة المفاتيح (محرر النص) لا يجب أن تصغّر اللوحة فتقفز العناصر
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: _persistAndLeave),
                title: BlocBuilder<CanvasBloc, CanvasState>(
                  buildWhen: (a, b) => a.doc.name != b.doc.name,
                  builder: (context, st) => Text(st.doc.name, style: const TextStyle(fontSize: 16)),
                ),
                actions: [
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'تصغير', onPressed: () => controller.setView(controller.zoom / 1.25, controller.pan), icon: const Icon(Icons.zoom_out)),
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'تكبير', onPressed: () => controller.setView(controller.zoom * 1.25, controller.pan), icon: const Icon(Icons.zoom_in)),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات',
                    icon: const Icon(Icons.more_vert),
                    color: AppColors.panel2,
                    onSelected: (v) {
                      switch (v) {
                        case 'bg':
                          popup.value = 'bg';
                          break;
                        case 'layers':
                          popup.value = 'layers';
                          break;
                        case 'grid':
                          controller.update(() => controller.showGrid = !controller.showGrid);
                          break;
                        case 'snap':
                          controller.update(() => controller.snap = !controller.snap);
                          break;
                        case 'reset':
                          controller.resetView();
                          break;
                        case 'export':
                          showExportSheet(ctx, canvas.state.doc, images);
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'layers', child: Text('الطبقات')),
                      PopupMenuItem(value: 'bg', child: Text('الخلفية والمقاس')),
                      PopupMenuItem(value: 'grid', child: Text('إظهار/إخفاء الشبكة')),
                      PopupMenuItem(value: 'snap', child: Text('تفعيل/إيقاف المحاذاة')),
                      PopupMenuItem(value: 'reset', child: Text('إعادة ضبط العرض')),
                      PopupMenuItem(value: 'export', child: Text('تصدير')),
                    ],
                  ),
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'إضافة', onPressed: () => popup.value = 'add', icon: const Icon(Icons.add_circle, color: AppColors.accent)),
                  BlocBuilder<CanvasBloc, CanvasState>(
                    builder: (context, st) => Row(children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'تراجع',
                        onPressed: st.canUndo ? () => canvas.add(const UndoRequested()) : null,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'إعادة',
                        onPressed: st.canRedo ? () => canvas.add(const RedoRequested()) : null,
                        icon: const Icon(Icons.redo),
                      ),
                    ]),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'تصدير',
                    onPressed: () => showExportSheet(ctx, canvas.state.doc, images),
                    icon: const Icon(Icons.ios_share),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        const Positioned.fill(child: CustomPaint(painter: DotsPainter())),
                        Positioned.fill(
                          child: CanvasView(
                            images: images,
                            controller: controller,
                            onEditText: () => _editSelectedText(ctx),
                          ),
                        ),
                        // النافذة المنبثقة فوق اللوحة: فتحها لا يغيّر حجم التصميم فلا يتحرك أو يقفز
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: EditorBottom(
                            controller: controller,
                            images: images,
                            popup: popup,
                            popupOnly: true,
                            onEditNewText: () => Future.delayed(const Duration(milliseconds: 120), () => _editSelectedText(ctx)),
                            onEditText: () => _editSelectedText(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: EditorBottom(
                      controller: controller,
                      images: images,
                      popup: popup,
                      onEditNewText: () => Future.delayed(const Duration(milliseconds: 120), () => _editSelectedText(ctx)),
                      onEditText: () => _editSelectedText(ctx),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
