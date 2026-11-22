import 'package:hyperhunt/features/auth/domain/app_user.dart';
import 'package:hyperhunt/features/auth/domain/auth_failure.dart';
import 'package:hyperhunt/features/auth/domain/auth_repository.dart';
import 'package:hyperhunt/features/profile/domain/profile.dart';
import 'package:hyperhunt/features/profile/domain/profile_repository.dart';
import 'package:hyperhunt/features/profile/domain/user_preferences.dart';

/// Hand-rolled fakes (no mocking package — Bible §3: fewer dependencies).
class FakeAuthRepository implements AuthRepository {
  AppUser? user;
  bool failNext = false;
  String failMessage = 'Email or password is incorrect';
  final calls = <String>[];

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw AuthFailure(failMessage);
    }
  }

  @override
  AppUser? get currentUser => user;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(user);

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    _maybeFail();
    user = AppUser(id: 'user-a', email: email);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    calls.add('signUp:$email');
    _maybeFail();
    user = AppUser(id: 'user-a', email: email);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _maybeFail();
    user = null;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    calls.add('requestReset:$email');
    _maybeFail();
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    calls.add('confirmReset:$email:$code');
    _maybeFail();
  }
}

class FakeProfileRepository implements ProfileRepository {
  Profile profile =
      const Profile(id: 'user-a', email: 'a@test.dev', username: null);
  UserPreferences preferences = const UserPreferences.empty();
  final calls = <String>[];
  bool failNext = false;

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw Exception('boom');
    }
  }

  @override
  Future<Profile> getProfile() async {
    _maybeFail();
    return profile;
  }

  @override
  Future<UserPreferences> getPreferences() async {
    _maybeFail();
    return preferences;
  }

  @override
  Future<void> updateUsername(String? username) async {
    calls.add('updateUsername:$username');
    _maybeFail();
    profile = profile.copyWith(username: username);
  }

  @override
  Future<void> updatePreferences({
    required List<String> favoriteGenres,
    required List<String> favoritePlatforms,
  }) async {
    calls.add(
        'updatePreferences:${favoriteGenres.join(",")}|${favoritePlatforms.join(",")}');
    _maybeFail();
    preferences = UserPreferences(
      favoriteGenres: favoriteGenres,
      favoritePlatforms: favoritePlatforms,
    );
  }
}
