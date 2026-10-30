import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// غلاف بسيط حول speech_to_text (التعرف على الصوت العربي/الإنجليزي).
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  String? _localeId;

  bool get isListening => _stt.isListening;

  Future<bool> init({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onStatus: (s) => onStatus?.call(s),
        onError: (e) => onError?.call(e.errorMsg),
      );
      if (_ready) {
        final locales = await _stt.locales();
        String? pick;
        for (final pref in ['ar_IQ', 'ar_SA', 'ar_EG', 'ar']) {
          for (final l in locales) {
            if (l.localeId.replaceAll('-', '_').toLowerCase() == pref.toLowerCase()) {
              pick = l.localeId;
              break;
            }
          }
          if (pick != null) break;
        }
        pick ??= locales.where((l) => l.localeId.toLowerCase().startsWith('ar')).map((l) => l.localeId).firstOrNull;
        _localeId = pick;
      }
    } catch (e) {
      debugPrint('speech init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  Future<void> listen(void Function(String words, bool isFinal) onResult) async {
    if (!_ready) return;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      localeId: _localeId,
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
