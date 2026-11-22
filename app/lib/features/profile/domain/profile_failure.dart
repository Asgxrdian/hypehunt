/// Domain-level profile error with a user-safe message.
class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class UsernameTakenFailure extends ProfileFailure {
  const UsernameTakenFailure() : super('That username is taken');
}
