import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../poster_builder/model/doc.dart';
import '../background_remover_service.dart';

enum RemoverStatus { idle, working, success, failure }

class RemoveBackgroundRequested {
  const RemoveBackgroundRequested({required this.layerId, required this.path, this.tolerance = 42, this.colorOnly = false});
  final String layerId, path;
  final double tolerance;
  final bool colorOnly;
}

class SubjectSegmentationState extends Equatable {
  const SubjectSegmentationState({
    this.status = RemoverStatus.idle,
    this.serial = 0,
    this.layerId,
    this.result,
    this.method = '',
    this.message = '',
  });
  final RemoverStatus status;
  final int serial; // يتغير مع كل نتيجة ليُطلق المستمعين دائماً
  final String? layerId;
  final ImageResult? result;
  final String method;
  final String message;

  @override
  List<Object?> get props => [status, serial, layerId, method, message];
}

/// "ازل الخلفية" ← SubjectSegmentationBloc.removeBackground()
class SubjectSegmentationBloc extends Bloc<RemoveBackgroundRequested, SubjectSegmentationState> {
  SubjectSegmentationBloc(this._service) : super(const SubjectSegmentationState()) {
    on<RemoveBackgroundRequested>((e, emit) async {
      emit(SubjectSegmentationState(status: RemoverStatus.working, serial: state.serial + 1, layerId: e.layerId));
      try {
        final r = await _service.remove(e.path, tolerance: e.tolerance, colorOnly: e.colorOnly);
        emit(SubjectSegmentationState(
          status: RemoverStatus.success,
          serial: state.serial + 1,
          layerId: e.layerId,
          result: r.image,
          method: r.method,
          message: switch (r.method) {
            'subject' => 'تمت إزالة الخلفية بالذكاء الاصطناعي',
            'selfie' => 'تمت إزالة الخلفية (نموذج الأشخاص)',
            _ => 'تمت إزالة الخلفية بطريقة الألوان — يمكنك تحسينها بالممحاة',
          },
        ));
      } catch (err) {
        emit(SubjectSegmentationState(
          status: RemoverStatus.failure,
          serial: state.serial + 1,
          layerId: e.layerId,
          message: 'تعذّرت إزالة الخلفية: $err',
        ));
      }
    });
  }

  final BackgroundRemoverService _service;

  void removeBackground(String layerId, String path, {double tolerance = 42, bool colorOnly = false}) =>
      add(RemoveBackgroundRequested(layerId: layerId, path: path, tolerance: tolerance, colorOnly: colorOnly));
}
