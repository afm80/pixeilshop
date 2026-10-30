import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/speech_service.dart';
import '../command_parser.dart';

sealed class CopilotEvent {
  const CopilotEvent();
}

class CopilotTextSubmitted extends CopilotEvent {
  const CopilotTextSubmitted(this.text);
  final String text;
}

class CopilotVoicePressed extends CopilotEvent {
  const CopilotVoicePressed();
}

class CopilotVoiceResult extends CopilotEvent {
  const CopilotVoiceResult(this.words, this.isFinal);
  final String words;
  final bool isFinal;
}

class CopilotVoiceEnded extends CopilotEvent {
  const CopilotVoiceEnded();
}

class CopilotState extends Equatable {
  const CopilotState({this.listening = false, this.partial = '', this.command, this.serial = 0, this.error = ''});
  final bool listening;
  final String partial;
  final CopilotCommand? command; // أمر جديد بانتظار التنفيذ
  final int serial;
  final String error;

  @override
  List<Object?> get props => [listening, partial, serial, error];
}

/// يستقبل نصاً أو صوتاً ويحوّله إلى أمر منفَّذ على الـ Blocs الأخرى.
class CopilotBloc extends Bloc<CopilotEvent, CopilotState> {
  CopilotBloc(this._speech) : super(const CopilotState()) {
    on<CopilotTextSubmitted>((e, emit) {
      emit(CopilotState(command: CommandParser.parse(e.text), serial: state.serial + 1));
    });
    on<CopilotVoicePressed>((e, emit) async {
      if (state.listening) {
        await _speech.stop();
        emit(CopilotState(serial: state.serial));
        return;
      }
      final ok = await _speech.init(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && !isClosed) add(const CopilotVoiceEnded());
        },
        onError: (_) {
          if (!isClosed) add(const CopilotVoiceEnded());
        },
      );
      if (!ok) {
        emit(CopilotState(serial: state.serial + 1, error: 'التعرف على الصوت غير متاح (تأكد من إذن الميكروفون)'));
        return;
      }
      emit(CopilotState(listening: true, serial: state.serial));
      await _speech.listen((words, isFinal) {
        if (!isClosed) add(CopilotVoiceResult(words, isFinal));
      });
    });
    on<CopilotVoiceResult>((e, emit) {
      if (e.isFinal && e.words.trim().isNotEmpty) {
        emit(CopilotState(command: CommandParser.parse(e.words), partial: e.words, serial: state.serial + 1));
      } else {
        emit(CopilotState(listening: true, partial: e.words, serial: state.serial));
      }
    });
    on<CopilotVoiceEnded>((e, emit) {
      if (state.listening) emit(CopilotState(partial: state.partial, serial: state.serial));
    });
  }

  final SpeechService _speech;

  @override
  Future<void> close() {
    _speech.stop();
    return super.close();
  }
}
