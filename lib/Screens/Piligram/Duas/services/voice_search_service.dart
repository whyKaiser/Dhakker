import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSearchService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    required Function(String status) onStatus,
    required Function(String error) onError,
  }) async {
    return await _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
    );
  }

  Future<void> startListening({
    required String localeId,
    required Function(String words, bool isFinal) onResult,
    required Function(double level) onSoundLevelChange,
  }) async {
    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.search,
      partialResults: true,
      onSoundLevelChange: onSoundLevelChange,
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
  }
}