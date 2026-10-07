import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/web_speech_recognizer.dart';

class LiveSpeechService {
  static final LiveSpeechService _instance = LiveSpeechService._internal();
  factory LiveSpeechService() => _instance;
  LiveSpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  Timer? _webSoundSimulationTimer;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (kIsWeb) {
      return isWebSpeechAvailable();
    }
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (val) {
          _isListening = false;
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
      return _isSpeechInitialized;
    } catch (_) {
      _isSpeechInitialized = false;
      return false;
    }
  }

  Future<bool> startListening({
    required void Function(String liveText) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
    void Function(double level)? onSoundLevel,
    String lang = 'en-US',
  }) async {
    if (_isListening) {
      await stopListening();
    }

    if (kIsWeb) {
      _isListening = true;
      onStatus?.call('listening');

      // Start simulated sound waves for UI feedback
      _webSoundSimulationTimer?.cancel();
      _webSoundSimulationTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (!_isListening) {
          timer.cancel();
          return;
        }
        final tick = timer.tick % 6;
        final level = 1.0 + (tick * 1.5);
        onSoundLevel?.call(level);
      });

      final started = startWebSpeechRecognition(
        onResult: (text) {
          onResult(text);
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            _webSoundSimulationTimer?.cancel();
          } else if (status == 'listening') {
            _isListening = true;
          }
          onStatus?.call(status);
        },
        onError: (err) {
          _isListening = false;
          _webSoundSimulationTimer?.cancel();
          onError?.call(err);
        },
        lang: lang,
      );

      if (!started) {
        _isListening = false;
        _webSoundSimulationTimer?.cancel();
        return false;
      }
      return true;
    }

    // Mobile / Native platforms
    final available = await initialize();
    if (!available) {
      onError?.call('Speech recognition is not available on this device.');
      return false;
    }

    _isListening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        onSoundLevelChange: (level) {
          onSoundLevel?.call(level);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: lang,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      return true;
    } catch (e) {
      _isListening = false;
      onError?.call(e.toString());
      return false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    _webSoundSimulationTimer?.cancel();
    _webSoundSimulationTimer = null;

    if (kIsWeb) {
      stopWebSpeechRecognition();
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> abort() async {
    _isListening = false;
    _webSoundSimulationTimer?.cancel();
    _webSoundSimulationTimer = null;

    if (kIsWeb) {
      abortWebSpeechRecognition();
      return;
    }

    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
