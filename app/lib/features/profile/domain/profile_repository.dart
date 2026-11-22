import 'profile.dart';
import 'user_preferences.dart';

/// Contract for profile + preference persistence. RLS on the server is
/// the real enforcement; this layer just moves the user's own rows.
abstract interface class ProfileRepository {
  Future<Profile> getProfile();

  Future<UserPreferences> getPreferences();

  Future<void> updateUsername(String? username);

  Future<void> updatePreferences({
    required List<String> favoriteGenres,
    required List<String> favoritePlatforms,
  });
}
