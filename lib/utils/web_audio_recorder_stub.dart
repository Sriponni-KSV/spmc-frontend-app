bool isAudioRecorderAvailable() => false;

void startAudioRecording(void Function(bool success) callback) {
  callback(false);
}

void stopAudioRecording(void Function(String base64) callback) {
  callback("");
}
