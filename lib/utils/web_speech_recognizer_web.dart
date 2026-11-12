// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void _ensureJsSpeechRecognizer() {
  try {
    if (js.context.hasProperty('speechRecognizer') &&
        js.context['speechRecognizer'] != null &&
        js.context['speechRecognizer']['_isV2'] == true) {
      return;
    }
  } catch (_) {}

  try {
    final jsCode = '''
    (function() {
      if (window.speechRecognizer && window.speechRecognizer._isV2) {
        return;
      }

      // Clean up previous instance if reloading
      if (window.speechRecognizer && window.speechRecognizer.recognition) {
        try {
          window.speechRecognizer.recognition.onstart = null;
          window.speechRecognizer.recognition.onresult = null;
          window.speechRecognizer.recognition.onerror = null;
          window.speechRecognizer.recognition.onend = null;
          window.speechRecognizer.recognition.abort();
        } catch(e) {}
      }

      window.speechRecognizer = {
        _isV2: true,
        recognition: null,
        isUserListening: false,
        isReady: true,
        onResultCallback: null,
        onStatusCallback: null,
        onErrorCallback: null,
        accumulatedFinal: '',
        sessionFinal: '',
        targetLang: 'en-IN',
        _restartTimer: null,
        _retryTimer: null,

        isSupported: function() {
          return !!(window.SpeechRecognition || window.webkitSpeechRecognition);
        },

        start: function(onResult, onStatus, onError, lang) {
          const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) {
            if (onError) onError("Web Speech API is not supported in this browser. Please use Google Chrome or Microsoft Edge.");
            return false;
          }

          if (this._restartTimer) {
            clearTimeout(this._restartTimer);
            this._restartTimer = null;
          }
          if (this._retryTimer) {
            clearTimeout(this._retryTimer);
            this._retryTimer = null;
          }

          this.onResultCallback = onResult;
          this.onStatusCallback = onStatus;
          this.onErrorCallback = onError;
          this.isUserListening = true;
          this.accumulatedFinal = '';
          this.sessionFinal = '';
          this.targetLang = (lang && lang.trim()) ? lang.trim() : 'en-IN';

          this._stopCurrentRecognition();
          this._safeStart(0);
          return true;
        },

        _stopCurrentRecognition: function() {
          if (this.recognition) {
            const oldRec = this.recognition;
            this.recognition = null;
            oldRec.onstart = null;
            oldRec.onresult = null;
            oldRec.onerror = null;
            oldRec.onend = null;
            try {
              oldRec.abort();
            } catch(e) {}
          }
        },

        _safeStart: function(attempt) {
          if (!this.isUserListening) return;

          const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) return;

          this._stopCurrentRecognition();

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
              if (!this.isUserListening) return;
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
              if (!this.isUserListening) return;
              const err = event.error;

              if (err === 'no-speech' || err === 'aborted') {
                return;
              }

              this.isUserListening = false;
              this._stopCurrentRecognition();

              if (err === 'not-allowed' || err === 'service-not-allowed') {
                if (this.onErrorCallback) this.onErrorCallback("Microphone permission denied. Please allow microphone access in your browser address bar.");
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              } else if (err === 'audio-capture') {
                if (this.onErrorCallback) this.onErrorCallback("No microphone found or microphone is in use by another application.");
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              } else if (err === 'network') {
                if (this.onErrorCallback) this.onErrorCallback("Network error during speech recognition. Please check your internet connection.");
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              } else {
                console.warn("Speech error:", err);
                if (this.onErrorCallback) this.onErrorCallback("Speech recognition error: " + err);
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              }
            };

            rec.onend = () => {
              if (this.recognition !== rec) return;

              if (this.isUserListening) {
                if (this.sessionFinal) {
                  this.accumulatedFinal = (this.accumulatedFinal ? this.accumulatedFinal + ' ' : '') + this.sessionFinal;
                  this.sessionFinal = '';
                }
                clearTimeout(this._restartTimer);
                this._restartTimer = setTimeout(() => {
                  if (this.isUserListening) {
                    this._safeStart(0);
                  }
                }, 100);
              } else {
                this.recognition = null;
                if (this.onStatusCallback) this.onStatusCallback('notListening');
              }
            };

            rec.start();
          } catch(err) {
            const errStr = (err && err.message) ? err.message : String(err);
            console.warn("Speech start exception (attempt " + attempt + "):", errStr);

            if (attempt < 5 && this.isUserListening && (
              errStr.includes('already started') ||
              errStr.includes('InvalidStateError') ||
              errStr.includes('busy') ||
              errStr.includes('failed')
            )) {
              clearTimeout(this._retryTimer);
              this._retryTimer = setTimeout(() => {
                if (this.isUserListening) {
                  this._safeStart(attempt + 1);
                }
              }, 120 + (attempt * 80));
              return;
            }

            this.isUserListening = false;
            this._stopCurrentRecognition();
            if (this.onErrorCallback) this.onErrorCallback(errStr);
            if (this.onStatusCallback) this.onStatusCallback('notListening');
          }
        },

        stop: function() {
          this.isUserListening = false;
          if (this._restartTimer) {
            clearTimeout(this._restartTimer);
            this._restartTimer = null;
          }
          if (this._retryTimer) {
            clearTimeout(this._retryTimer);
            this._retryTimer = null;
          }
          if (this.sessionFinal) {
            this.accumulatedFinal = (this.accumulatedFinal ? this.accumulatedFinal + ' ' : '') + this.sessionFinal;
            this.sessionFinal = '';
          }
          this._stopCurrentRecognition();
          if (this.onStatusCallback) {
            try { this.onStatusCallback('notListening'); } catch(e) {}
          }
        },

        abort: function() {
          this.isUserListening = false;
          if (this._restartTimer) {
            clearTimeout(this._restartTimer);
            this._restartTimer = null;
          }
          if (this._retryTimer) {
            clearTimeout(this._retryTimer);
            this._retryTimer = null;
          }
          this.accumulatedFinal = '';
          this.sessionFinal = '';
          this._stopCurrentRecognition();
          if (this.onStatusCallback) {
            try { this.onStatusCallback('notListening'); } catch(e) {}
          }
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
