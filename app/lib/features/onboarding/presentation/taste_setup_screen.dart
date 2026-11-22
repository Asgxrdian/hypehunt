import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/game_taxonomy.dart';
import '../../profile/presentation/profile_controller.dart';
import 'preference_chip_grid.dart';

/// Two-step taste picker. Serves both post-signup onboarding
/// (isEditing: false — skippable, lands on /home) and the profile's
/// Edit preferences (isEditing: true — pops back on save).
class TasteSetupScreen extends ConsumerStatefulWidget {
  const TasteSetupScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  ConsumerState<TasteSetupScreen> createState() => _TasteSetupScreenState();
}

class _TasteSetupScreenState extends ConsumerState<TasteSetupScreen> {
  final Set<String> _genres = {};
  final Set<String> _platforms = {};
  int _step = 0;
  bool _prefilled = false;
  bool _saving = false;

  void _prefillFrom(List<String> genres, List<String> platforms) {
    if (_prefilled) return;
    _genres.addAll(genres);
    _platforms.addAll(platforms);
    _prefilled = true;
  }

  void _leave() {
    if (widget.isEditing) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final ok = await ref.read(profileControllerProvider.notifier)
        .savePreferences(
          favoriteGenres: _genres.toList(),
          favoritePlatforms: _platforms.toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _leave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t save right now — you can retry from '
              'your profile any time.'),
        ),
      );
      if (!widget.isEditing) _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileControllerProvider);

    // Pre-fill from existing preferences once loaded (empty for a
    // fresh account, populated when editing).
    profile.whenData(
      (data) => _prefillFrom(
        data.preferences.favoriteGenres,
        data.preferences.favoritePlatforms,
      ),
    );

    final isGenreStep = _step == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit preferences' : 'Step ${_step + 1} of 2'),
        leading: isGenreStep
            ? (widget.isEditing
                ? BackButton(onPressed: _leave)
                : null)
            : BackButton(onPressed: () => setState(() => _step = 0)),
        automaticallyImplyLeading: false,
        actions: [
          if (!widget.isEditing)
            TextButton(
              key: const ValueKey('skip-button'),
              onPressed: _saving ? null : _leave,
              child: const Text('Skip for now'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Text(
                isGenreStep ? 'What do you like to play?' : 'Where do you play?',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                isGenreStep
                    ? 'Pick as many as you want — 3 to 5 works great.'
                    : 'We\'ll emphasize games for your platforms.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              PreferenceChipGrid(
                entries: isGenreStep ? kGenres : kPlatforms,
                selected: isGenreStep ? _genres : _platforms,
                onToggle: (slug) => setState(() {
                  final target = isGenreStep ? _genres : _platforms;
                  target.contains(slug)
                      ? target.remove(slug)
                      : target.add(slug);
                }),
              ),
              const SizedBox(height: 32),
              FilledButton(
                key: const ValueKey('primary-button'),
                onPressed: _saving
                    ? null
                    : isGenreStep
                        ? () => setState(() => _step = 1)
                        : _finish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isGenreStep
                        ? 'Continue'
                        : widget.isEditing
                            ? 'Save'
                            : 'Finish'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
