// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void _ensureJsSpeechRecognizer() {
  try {
    if (js.context['speechRecognizer'] != null) return;

    final jsCode = '''
    (function() {
      if (window.speechRecognizer) return;
      window.speechRecognizer = {
        recognition: null,
        isUserListening: false,
        onResultCallback: null,
        onStatusCallback: null,
        onErrorCallback: null,
        accumulatedFinal: '',
        targetLang: 'en-US',

        isSupported: function() {
          return !!(window.SpeechRecognition || window.webkitSpeechRecognition);
        },

        start: function(onResult, onStatus, onError, lang) {
          const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) {
            if (onError) onError("Web Speech API is not supported in this browser. Please use Google Chrome or Microsoft Edge.");
            return false;
          }

          this.onResultCallback = onResult;
          this.onStatusCallback = onStatus;
          this.onErrorCallback = onError;
          this.isUserListening = true;
          this.accumulatedFinal = '';
          this.targetLang = lang || 'en-US';

          // Ensure microphone permission is granted first
          if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices.getUserMedia({ audio: true })
              .then((stream) => {
                // Stop the temporary stream tracks now that permission is confirmed
                stream.getTracks().forEach(track => track.stop());
                this._createAndStartRecognition();
              })
              .catch((err) => {
                console.warn("Microphone permission error:", err);
                if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
                  if (this.onErrorCallback) this.onErrorCallback("Microphone permission denied. Please allow microphone access in your browser address bar.");
                } else {
                  this._createAndStartRecognition();
                }
              });
          } else {
            this._createAndStartRecognition();
          }

          return true;
        },

        _createAndStartRecognition: function() {
          if (!this.isUserListening) return;

          const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (this.recognition) {
            try {
              this.recognition.onend = null;
              this.recognition.onerror = null;
              this.recognition.onresult = null;
              this.recognition.abort();
            } catch(e) {}
            this.recognition = null;
          }

          try {
            const rec = new SpeechRecognition();
            this.recognition = rec;
            rec.continuous = true;
            rec.interimResults = true;
            rec.maxAlternatives = 1;
            rec.lang = (this.targetLang && this.targetLang !== 'en-US') ? this.targetLang : (navigator.language || 'en-IN');

            rec.onstart = () => {
              if (this.onStatusCallback) this.onStatusCallback('listening');
            };

            rec.onresult = (event) => {
              let sessionText = '';
              for (let i = 0; i < event.results.length; ++i) {
                sessionText += event.results[i][0].transcript;
              }
              this._lastSessionText = sessionText;
              const full = (this.accumulatedFinal + (sessionText.length > 0 ? (' ' + sessionText) : '')).trim();
              if (this.onResultCallback && full.length > 0) {
                this.onResultCallback(full);
              }
            };

            rec.onerror = (event) => {
              console.warn("Web Speech API recognition error:", event.error);
              if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
                if (this.onErrorCallback) this.onErrorCallback("Microphone permission denied or blocked.");
              } else if (event.error !== 'no-speech' && event.error !== 'audio-capture') {
                if (this.onErrorCallback) this.onErrorCallback(event.error);
              }
            };

            rec.onend = () => {
              if (this.isUserListening) {
                if (this._lastSessionText && this._lastSessionText.trim().length > 0) {
                  this.accumulatedFinal = (this.accumulatedFinal + ' ' + this._lastSessionText).trim();
                  this._lastSessionText = '';
                }
                setTimeout(() => {
                  if (this.isUserListening) {
                    this._createAndStartRecognition();
                  }
                }, 150);
              } else {
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              }
            };

            rec.start();
          } catch(err) {
            console.error("Failed to initialize Web Speech API:", err);
            if (this.onErrorCallback) this.onErrorCallback(err.toString());
          }
        },

        stop: function() {
          this.isUserListening = false;
          if (this.recognition) {
            try {
              this.recognition.stop();
            } catch(e) {}
          }
          if (this.onStatusCallback) this.onStatusCallback('notListening');
        },

        abort: function() {
          this.isUserListening = false;
          if (this.recognition) {
            try {
              this.recognition.abort();
            } catch(e) {}
          }
          if (this.onStatusCallback) this.onStatusCallback('notListening');
        }
      };
    })();
    ''';
    js.context.callMethod('eval', [jsCode]);
  } catch (_) {}
}

bool isWebSpeechAvailable() {
  _ensureJsSpeechRecognizer();
  try {
    final recognizer = js.context['speechRecognizer'];
    if (recognizer != null) {
      return recognizer.callMethod('isSupported') == true;
    }
    return js.context['SpeechRecognition'] != null || js.context['webkitSpeechRecognition'] != null;
  } catch (_) {
    return false;
  }
}

bool startWebSpeechRecognition({
  required void Function(String liveText) onResult,
  void Function(String status)? onStatus,
  void Function(String error)? onError,
  String lang = 'en-US',
}) {
  _ensureJsSpeechRecognizer();
  try {
    final recognizer = js.context['speechRecognizer'];
    if (recognizer == null) {
      onError?.call("Speech recognition service could not be initialized.");
      return false;
    }

    final onResultJs = js.JsFunction.withThis((_, dynamic text) {
      onResult(text?.toString() ?? '');
    });

    final onStatusJs = js.JsFunction.withThis((_, dynamic status) {
      onStatus?.call(status?.toString() ?? '');
    });

    final onErrorJs = js.JsFunction.withThis((_, dynamic err) {
      onError?.call(err?.toString() ?? '');
    });

    final result = recognizer.callMethod('start', [onResultJs, onStatusJs, onErrorJs, lang]);
    return result == true;
  } catch (e) {
    onError?.call(e.toString());
    return false;
  }
}

void stopWebSpeechRecognition() {
  try {
    final recognizer = js.context['speechRecognizer'];
    if (recognizer != null) {
      recognizer.callMethod('stop');
    }
  } catch (_) {}
}

void abortWebSpeechRecognition() {
  try {
    final recognizer = js.context['speechRecognizer'];
    if (recognizer != null) {
      recognizer.callMethod('abort');
    }
  } catch (_) {}
}
