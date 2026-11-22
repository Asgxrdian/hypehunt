/// Minimal authenticated-user identity for the app layer. Pure Dart.
class AppUser {
  const AppUser({required this.id, required this.email});
  final String id;
  final String email;
}
