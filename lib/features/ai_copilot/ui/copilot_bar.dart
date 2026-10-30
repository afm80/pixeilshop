import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../bloc/copilot_bloc.dart';

/// شريط المساعد الذكي: أمر نصي أو صوتي.
class CopilotBar extends StatefulWidget {
  const CopilotBar({super.key});

  @override
  State<CopilotBar> createState() => _CopilotBarState();
}

class _CopilotBarState extends State<CopilotBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    context.read<CopilotBloc>().add(CopilotTextSubmitted(t));
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CopilotBloc, CopilotState>(
      listenWhen: (a, b) => a.partial != b.partial && b.listening,
      listener: (context, s) {
        _ctrl.text = s.partial;
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      },
      builder: (context, s) {
        return Container(
          color: AppColors.panel,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.panel2,
                    hintText: s.listening ? 'أستمع إليك…' : 'اطلب من المساعد: ازل الخلفية، اضف نص…',
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'إرسال',
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded, color: AppColors.accent),
              ),
              IconButton(
                tooltip: 'أمر صوتي',
                onPressed: () => context.read<CopilotBloc>().add(const CopilotVoicePressed()),
                style: IconButton.styleFrom(backgroundColor: s.listening ? AppColors.danger : AppColors.panel2),
                icon: Icon(s.listening ? Icons.stop_rounded : Icons.mic_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}
