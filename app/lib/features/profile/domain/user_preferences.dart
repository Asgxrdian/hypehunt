/// The user's taste data (`user_preferences` table). Pure Dart.
class UserPreferences {
  const UserPreferences({
    required this.favoriteGenres,
    required this.favoritePlatforms,
    this.advancedTooltips = false,
  });

  const UserPreferences.empty()
      : favoriteGenres = const [],
        favoritePlatforms = const [],
        advancedTooltips = false;

  final List<String> favoriteGenres;
  final List<String> favoritePlatforms;
  final bool advancedTooltips;

  bool get isEmpty => favoriteGenres.isEmpty && favoritePlatforms.isEmpty;

  UserPreferences copyWith({
    List<String>? favoriteGenres,
    List<String>? favoritePlatforms,
    bool? advancedTooltips,
  }) =>
      UserPreferences(
        favoriteGenres: favoriteGenres ?? this.favoriteGenres,
        favoritePlatforms: favoritePlatforms ?? this.favoritePlatforms,
        advancedTooltips: advancedTooltips ?? this.advancedTooltips,
      );
}
