import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../bloc/canvas_bloc.dart';
import '../model/layer.dart';

class LayersListPanel extends StatelessWidget {
  const LayersListPanel({super.key});

  static IconData _icon(Layer l) => switch (l.type) {
        LayerType.text => Icons.title,
        LayerType.image => Icons.image_outlined,
        LayerType.shape => Icons.category_outlined,
      };

  static String _label(Layer l) {
    switch (l.type) {
      case LayerType.text:
        final t = l.text.trim().replaceAll('\n', ' ');
        return t.isEmpty ? 'نص' : (t.length > 22 ? '${t.substring(0, 22)}…' : t);
      case LayerType.image:
        return 'صورة';
      case LayerType.shape:
        return 'شكل';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, st) {
        final layers = st.doc.layers;
        if (layers.isEmpty) {
          return const Center(child: Text('لا توجد طبقات بعد', style: TextStyle(color: AppColors.muted)));
        }
        final bloc = context.read<CanvasBloc>();
        // القائمة تعرض الأعلى أولاً؛ نحول الفهارس إلى فهارس فعلية
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(8),
          buildDefaultDragHandles: true,
          itemCount: layers.length,
          onReorder: (oldI, newI) {
            if (newI > oldI) newI -= 1;
            final n = layers.length;
            bloc.add(LayerReordered(n - 1 - oldI, n - 1 - newI));
          },
          itemBuilder: (context, i) {
            final l = layers[layers.length - 1 - i];
            final sel = l.id == st.selectedId;
            return Container(
              key: ValueKey(l.id),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: sel ? AppColors.accent.withValues(alpha: 0.22) : AppColors.panel2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                dense: true,
                onTap: () => bloc.add(LayerSelected(l.id)),
                leading: Icon(_icon(l), size: 20),
                title: Text(_label(l), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(l.hidden ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => bloc.add(LayerMutated((x) => x.hidden = !x.hidden, id: l.id, commit: true)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(l.locked ? Icons.lock : Icons.lock_open, size: 18),
                      onPressed: () => bloc.add(LayerMutated((x) => x.locked = !x.locked, id: l.id, commit: true)),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
