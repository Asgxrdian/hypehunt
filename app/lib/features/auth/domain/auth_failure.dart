/// Domain-level auth error with a human-readable, user-safe message.
/// The data layer maps raw SDK exceptions into this; the UI only ever
/// renders [message] — never a raw error code (M1 spec §4).
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
