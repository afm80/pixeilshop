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
import '../../ai_copilot/ui/copilot_bar.dart';
import '../../anime_morph/bloc/anime_bloc.dart';
import '../../background_remover/background_remover_service.dart';
import '../../background_remover/bloc/subject_segmentation_bloc.dart';
import '../bloc/canvas_bloc.dart';
import '../model/doc.dart';
import '../model/layer.dart';
import 'canvas_view.dart';
import 'editor_panel.dart';
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
          controller.openOnly('color');
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
                  BlocBuilder<CanvasBloc, CanvasState>(
                    builder: (context, st) => Row(children: [
                      IconButton(
                        tooltip: 'تراجع',
                        onPressed: st.canUndo ? () => canvas.add(const UndoRequested()) : null,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        tooltip: 'إعادة',
                        onPressed: st.canRedo ? () => canvas.add(const RedoRequested()) : null,
                        icon: const Icon(Icons.redo),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilledButton.icon(
                      onPressed: () => showExportSheet(ctx, canvas.state.doc, images),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('تصدير'),
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: CanvasView(
                      images: images,
                      controller: controller,
                      onEditText: () => _editSelectedText(ctx),
                    ),
                  ),
                  const CopilotBar(),
                  SizedBox(
                    height: 300,
                    child: ColoredBox(
                      color: AppColors.panel,
                      child: SafeArea(
                        top: false,
                        child: EditorPanel(
                          controller: controller,
                          images: images,
                          onEditNewText: () => Future.delayed(const Duration(milliseconds: 120), () => _editSelectedText(ctx)),
                        ),
                      ),
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
