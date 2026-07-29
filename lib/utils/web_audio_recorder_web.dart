// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

bool isAudioRecorderAvailable() {
  try {
    return js.context['audioRecorder'] != null;
  } catch (_) {
    return false;
  }
}

void startAudioRecording(void Function(bool success) callback) {
  try {
    final recorder = js.context['audioRecorder'];
    if (recorder == null) {
      callback(false);
      return;
    }
    final jsCallback = js.JsFunction.withThis((_, dynamic successVal) {
      callback(successVal == true);
    });
    js.context['audioRecorder'].callMethod('startRecording', [jsCallback]);
  } catch (_) {
    callback(false);
  }
}

void stopAudioRecording(void Function(String base64) callback) {
  try {
    final recorder = js.context['audioRecorder'];
    if (recorder == null) {
      callback("");
      return;
    }
    final jsCallback = js.JsFunction.withThis((_, dynamic base64Val) {
      callback(base64Val?.toString() ?? "");
    });
    js.context['audioRecorder'].callMethod('stopRecording', [jsCallback]);
  } catch (_) {
    callback("");
  }
}
