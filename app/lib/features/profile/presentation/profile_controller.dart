import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_profile_repository.dart';
import '../domain/profile.dart';
import '../domain/user_preferences.dart';

/// Combined view state for the profile surfaces.
class ProfileData {
  const ProfileData({required this.profile, required this.preferences});
  final Profile profile;
  final UserPreferences preferences;

  ProfileData copyWith({Profile? profile, UserPreferences? preferences}) =>
      ProfileData(
        profile: profile ?? this.profile,
        preferences: preferences ?? this.preferences,
      );
}

class ProfileController extends AutoDisposeAsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() async {
    final repo = ref.watch(profileRepositoryProvider);
    final results =
        await Future.wait([repo.getProfile(), repo.getPreferences()]);
    return ProfileData(
      profile: results[0] as Profile,
      preferences: results[1] as UserPreferences,
    );
  }

  /// Saves preferences. Returns true on success; on failure the previous
  /// data is restored so the UI never strands the user on an error screen.
  Future<bool> savePreferences({
    required List<String> favoriteGenres,
    required List<String> favoritePlatforms,
  }) async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    try {
      await ref.read(profileRepositoryProvider).updatePreferences(
            favoriteGenres: favoriteGenres,
            favoritePlatforms: favoritePlatforms,
          );
      state = AsyncData(
        (previous ?? await future).copyWith(
          preferences: UserPreferences(
            favoriteGenres: favoriteGenres,
            favoritePlatforms: favoritePlatforms,
          ),
        ),
      );
      return true;
    } catch (e, st) {
      state = previous != null ? AsyncData(previous) : AsyncError(e, st);
      return false;
    }
  }

  /// Saves the username. Returns an error message, or null on success.
  Future<String?> saveUsername(String? username) async {
    final previous = state.valueOrNull;
    try {
      final cleaned =
          (username?.trim().isEmpty ?? true) ? null : username!.trim();
      await ref.read(profileRepositoryProvider).updateUsername(cleaned);
      if (previous != null) {
        state = AsyncData(
          previous.copyWith(
            profile: Profile(
              id: previous.profile.id,
              email: previous.profile.email,
              username: cleaned,
            ),
          ),
        );
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, ProfileData>(
  ProfileController.new,
);
