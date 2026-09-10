bool isWebSpeechAvailable() => false;

bool startWebSpeechRecognition({
  required void Function(String liveText) onResult,
  void Function(String status)? onStatus,
  void Function(String error)? onError,
  String lang = 'en-US',
}) => false;

void stopWebSpeechRecognition() {}

void abortWebSpeechRecognition() {}
