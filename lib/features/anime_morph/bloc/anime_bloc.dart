import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/tflite_service.dart';
import '../../poster_builder/model/doc.dart';

enum AnimeStatus { idle, working, success, failure }

class StyleRequested {
  const StyleRequested({required this.layerId, required this.path, required this.kind, this.strength = 1.0});
  final String layerId, path;
  final StyleKind kind;
  final double strength;
}

class AnimeState extends Equatable {
  const AnimeState({this.status = AnimeStatus.idle, this.serial = 0, this.layerId, this.result, this.message = ''});
  final AnimeStatus status;
  final int serial;
  final String? layerId;
  final ImageResult? result;
  final String message;

  @override
  List<Object?> get props => [status, serial, layerId, message];
}

/// "حول الصورة إلى أنمي" ← TfliteService.runAnimeModel()
class AnimeBloc extends Bloc<StyleRequested, AnimeState> {
  AnimeBloc(this._tflite) : super(const AnimeState()) {
    on<StyleRequested>((e, emit) async {
      emit(AnimeState(status: AnimeStatus.working, serial: state.serial + 1, layerId: e.layerId));
      try {
        final r = await _tflite.stylize(e.path, e.kind, strength: e.strength);
        emit(AnimeState(
          status: AnimeStatus.success,
          serial: state.serial + 1,
          layerId: e.layerId,
          result: r.image,
          message: r.usedModel
              ? 'تم التحويل بنموذج الذكاء الاصطناعي (${e.kind.label})'
              : 'تم التحويل بفلتر محلي (ضع ملف نموذج .tflite في assets/models لنتيجة أنمي حقيقية)',
        ));
      } catch (err) {
        emit(AnimeState(
          status: AnimeStatus.failure,
          serial: state.serial + 1,
          layerId: e.layerId,
          message: 'تعذّر التحويل: $err',
        ));
      }
    });
  }

  final TfliteService _tflite;

  void runAnimeModel(String layerId, String path, {StyleKind kind = StyleKind.anime, double strength = 1}) =>
      add(StyleRequested(layerId: layerId, path: path, kind: kind, strength: strength));

  @override
  Future<void> close() {
    _tflite.dispose();
    return super.close();
  }
}
