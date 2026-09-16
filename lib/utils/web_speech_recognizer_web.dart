// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void _ensureJsSpeechRecognizer() {
  try {
    final jsCode = '''
    (function() {
      // Clean up previous instance if reloading
      if (window.speechRecognizer && window.speechRecognizer.recognition) {
        try { window.speechRecognizer.recognition.abort(); } catch(e) {}
      }

      window.speechRecognizer = {
        recognition: null,
        isUserListening: false,
        isReady: true,
        onResultCallback: null,
        onStatusCallback: null,
        onErrorCallback: null,
        accumulatedFinal: '',
        sessionFinal: '',
        targetLang: 'en-IN',

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
          this.sessionFinal = '';
          this.targetLang = lang || 'en-IN';

          this._createAndStartRecognition();
          return true;
        },

        _createAndStartRecognition: function() {
          if (!this.isUserListening) return;

          const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (this.recognition) {
            try {
              this.recognition.onstart = null;
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
            rec.lang = this.targetLang || 'en-IN';

            rec.onstart = () => {
              if (this.isUserListening && this.onStatusCallback) {
                this.onStatusCallback('listening');
              }
            };

            rec.onresult = (event) => {
              let finalChunk = '';
              let interimChunk = '';

              for (let i = 0; i < event.results.length; ++i) {
                const item = event.results[i];
                if (item && item[0] && item[0].transcript) {
                  const text = item[0].transcript.trim();
                  if (item.isFinal) {
                    finalChunk += (finalChunk ? ' ' : '') + text;
                  } else {
                    interimChunk += (interimChunk ? ' ' : '') + text;
                  }
                }
              }

              this.sessionFinal = finalChunk;
              const livePart = interimChunk || finalChunk;
              let full = this.accumulatedFinal;
              if (livePart) {
                full = (full ? full + ' ' : '') + livePart;
              }

              if (this.onResultCallback && full.trim().length > 0) {
                this.onResultCallback(full.trim());
              }
            };

            rec.onerror = (event) => {
              if (event.error === 'no-speech' || event.error === 'aborted') {
                return;
              }
              if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
                this.isUserListening = false;
                if (this.onErrorCallback) this.onErrorCallback("Microphone permission denied. Please allow microphone access in your browser address bar.");
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              } else if (event.error === 'audio-capture') {
                this.isUserListening = false;
                if (this.onErrorCallback) this.onErrorCallback("No microphone found or microphone is in use by another application.");
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              } else if (event.error === 'network') {
                this.isUserListening = false;
                if (this.onErrorCallback) this.onErrorCallback("Network error during speech recognition. Please check your internet connection.");
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              } else {
                if (this.onErrorCallback) this.onErrorCallback("Speech error: " + event.error);
              }
            };

            rec.onend = () => {
              if (this.isUserListening) {
                if (this.sessionFinal) {
                  this.accumulatedFinal = (this.accumulatedFinal ? this.accumulatedFinal + ' ' : '') + this.sessionFinal;
                  this.sessionFinal = '';
                }
                setTimeout(() => {
                  if (this.isUserListening) {
                    this._createAndStartRecognition();
                  }
                }, 100);
              } else {
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              }
            };

            rec.start();
          } catch(err) {
            if (this.onErrorCallback) this.onErrorCallback(err.toString());
          }
        },

        stop: function() {
          this.isUserListening = false;
          if (this.sessionFinal) {
            this.accumulatedFinal = (this.accumulatedFinal ? this.accumulatedFinal + ' ' : '') + this.sessionFinal;
            this.sessionFinal = '';
          }
          if (this.recognition) {
            try {
              this.recognition.stop();
            } catch(e) {}
          }
          if (this.onStatusCallback) this.onStatusCallback('notListening');
        },

        abort: function() {
          this.isUserListening = false;
          this.accumulatedFinal = '';
          this.sessionFinal = '';
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
