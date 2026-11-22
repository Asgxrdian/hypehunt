import 'package:flutter_test/flutter_test.dart';
import 'package:hyperhunt/core/theme/app_theme.dart';

void main() {
  test('theme builds with constitutional tokens', () {
    final theme = buildHyperTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, HyperColors.lime);
    expect(theme.colorScheme.secondary, HyperColors.cyan);
  });
}
