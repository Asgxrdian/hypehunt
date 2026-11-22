import 'package:flutter/material.dart';

import '../../../core/constants/game_taxonomy.dart';

/// Tap-to-toggle chip grid over a taxonomy. Reused by onboarding and by
/// the profile's Edit preferences (M1 spec §5).
class PreferenceChipGrid extends StatelessWidget {
  const PreferenceChipGrid({
    super.key,
    required this.entries,
    required this.selected,
    required this.onToggle,
  });

  final List<TaxonomyEntry> entries;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in entries)
          FilterChip(
            key: ValueKey('chip-${entry.slug}'),
            label: Text(entry.label),
            selected: selected.contains(entry.slug),
            onSelected: (_) => onToggle(entry.slug),
          ),
      ],
    );
  }
}
