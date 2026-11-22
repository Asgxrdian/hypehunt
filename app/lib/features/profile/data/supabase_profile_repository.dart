import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_failure.dart';
import '../domain/profile_repository.dart';
import '../domain/user_preferences.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(Supabase.instance.client),
);

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProfileFailure('You need to be signed in for that');
    }
    return user.id;
  }

  @override
  Future<Profile> getProfile() async {
    try {
      final row =
          await _client.from('profiles').select().eq('id', _uid).single();
      return Profile(
        id: row['id'] as String,
        email: _client.auth.currentUser?.email ?? '',
        username: row['username'] as String?,
      );
    } on ProfileFailure {
      rethrow;
    } catch (_) {
      throw const ProfileFailure('Couldn\'t load your profile');
    }
  }

  @override
  Future<UserPreferences> getPreferences() async {
    try {
      final row = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', _uid)
          .single();
      return UserPreferences(
        favoriteGenres: List<String>.from(row['favorite_genres'] as List),
        favoritePlatforms:
            List<String>.from(row['favorite_platforms'] as List),
        advancedTooltips: row['advanced_tooltips'] as bool? ?? false,
      );
    } on ProfileFailure {
      rethrow;
    } catch (_) {
      throw const ProfileFailure('Couldn\'t load your preferences');
    }
  }

  @override
  Future<void> updateUsername(String? username) async {
    try {
      await _client
          .from('profiles')
          .update({'username': username}).eq('id', _uid);
    } on PostgrestException catch (e) {
      // 23505 = unique violation: username already claimed.
      if (e.code == '23505') throw const UsernameTakenFailure();
      throw const ProfileFailure('Couldn\'t save your username');
    } on ProfileFailure {
      rethrow;
    } catch (_) {
      throw const ProfileFailure('Couldn\'t save your username');
    }
  }

  @override
  Future<void> updatePreferences({
    required List<String> favoriteGenres,
    required List<String> favoritePlatforms,
  }) async {
    try {
      await _client.from('user_preferences').update({
        'favorite_genres': favoriteGenres,
        'favorite_platforms': favoritePlatforms,
      }).eq('user_id', _uid);
    } on ProfileFailure {
      rethrow;
    } catch (_) {
      throw const ProfileFailure('Couldn\'t save your preferences');
    }
  }
}
