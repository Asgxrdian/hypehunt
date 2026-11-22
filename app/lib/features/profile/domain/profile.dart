/// The user's public-ish identity row (`profiles` table). Pure Dart.
class Profile {
  const Profile({required this.id, required this.email, this.username});
  final String id;
  final String email;
  final String? username;

  Profile copyWith({String? username}) =>
      Profile(id: id, email: email, username: username ?? this.username);
}
