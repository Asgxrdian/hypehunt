/// Canonical genre and platform vocabularies (Bible §5, M1 spec §4).
///
/// `slug` is what we STORE (RAWG's stable identifiers, joinable against
/// `games.genres` in feed queries). `label` is what we SHOW. Never store
/// labels; never show slugs.
class TaxonomyEntry {
  const TaxonomyEntry(this.slug, this.label);
  final String slug;
  final String label;
}

const kGenres = <TaxonomyEntry>[
  TaxonomyEntry('action', 'Action'),
  TaxonomyEntry('adventure', 'Adventure'),
  TaxonomyEntry('role-playing-games-rpg', 'RPG'),
  TaxonomyEntry('shooter', 'Shooter'),
  TaxonomyEntry('strategy', 'Strategy'),
  TaxonomyEntry('indie', 'Indie'),
  TaxonomyEntry('simulation', 'Simulation'),
  TaxonomyEntry('puzzle', 'Puzzle'),
  TaxonomyEntry('platformer', 'Platformer'),
  TaxonomyEntry('racing', 'Racing'),
  TaxonomyEntry('sports', 'Sports'),
  TaxonomyEntry('fighting', 'Fighting'),
  TaxonomyEntry('massively-multiplayer', 'MMO'),
  TaxonomyEntry('casual', 'Casual'),
  TaxonomyEntry('arcade', 'Arcade'),
  TaxonomyEntry('family', 'Family'),
  TaxonomyEntry('board-games', 'Board Games'),
  TaxonomyEntry('card', 'Card'),
  TaxonomyEntry('educational', 'Educational'),
];

const kPlatforms = <TaxonomyEntry>[
  TaxonomyEntry('pc', 'PC'),
  TaxonomyEntry('playstation', 'PlayStation'),
  TaxonomyEntry('xbox', 'Xbox'),
  TaxonomyEntry('nintendo-switch', 'Nintendo Switch'),
  TaxonomyEntry('mobile', 'Mobile'),
];
