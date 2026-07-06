/// Base class for all network-related errors.
abstract class NetworkException implements Exception {
  String get message;
  @override
  String toString() => message;
}

/// Device has no internet connection (Wi-Fi off, mobile data off, etc.)
class NoInternetException extends NetworkException {
  @override
  final String message =
      'No internet connection. Please check your Wi-Fi or mobile data.';
}

/// Internet is up but the backend server is unreachable or not running.
class ServerUnavailableException extends NetworkException {
  @override
  final String message =
      'Server is currently unavailable. Please try again later.';
}

/// The request was sent but the server took too long to respond.
class RequestTimeoutException extends NetworkException {
  @override
  final String message =
      'Request timed out. Please check your connection and try again.';
}

/// The server responded with a 5xx internal error (our backend bug / crash).
class ServerErrorException extends NetworkException {
  final int statusCode;
  ServerErrorException(this.statusCode);

  @override
  String get message =>
      'Something went wrong on our end (error $statusCode). Please try again.';
}
