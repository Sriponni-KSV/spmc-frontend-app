/// Thrown when an HTTP request fails due to a network issue
/// (no internet, backend unreachable, DNS failure, etc.)
class NetworkException implements Exception {
  final String message;

  const NetworkException([
    this.message =
        'Something went wrong. Please check your internet connection.',
  ]);

  @override
  String toString() => message;
}
