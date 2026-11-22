// M1 exit test (Bible §9, M1 spec §7): proves two users cannot read or
// write each other's rows, and CAN access their own.
//
// Run from app/ with two pre-created test accounts:
//
//   dart run integration/rls_isolation_check.dart
//
// Reads config from environment variables (never hardcode — Bible §1):
//   SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY,
//   TEST_A_EMAIL, TEST_A_PASSWORD, TEST_B_EMAIL, TEST_B_PASSWORD
//
// Exit code 0 = all checks passed. Paste the output into the M1 PR.
import 'dart:io';

import 'package:supabase/supabase.dart';

int _failures = 0;

void check(String label, bool passed) {
  stdout.writeln('${passed ? "PASS" : "FAIL"}  $label');
  if (!passed) _failures++;
}

String _env(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    stderr.writeln('Missing environment variable: $key');
    exit(2);
  }
  return value;
}

Future<void> main() async {
  final url = _env('SUPABASE_URL');
  final key = _env('SUPABASE_PUBLISHABLE_KEY');

  final a = SupabaseClient(url, key);
  final b = SupabaseClient(url, key);

  final authA = await a.auth.signInWithPassword(
    email: _env('TEST_A_EMAIL'),
    password: _env('TEST_A_PASSWORD'),
  );
  final authB = await b.auth.signInWithPassword(
    email: _env('TEST_B_EMAIL'),
    password: _env('TEST_B_PASSWORD'),
  );
  final idA = authA.user!.id;
  final idB = authB.user!.id;
  stdout.writeln('Signed in A=$idA  B=$idB\n');

  // --- A writes distinctive preferences ---
  await a.from('user_preferences').update({
    'favorite_genres': ['action', 'indie'],
    'favorite_platforms': ['pc'],
  }).eq('user_id', idA);

  // --- Own-access checks (both directions of "the app still works") ---
  final aOwn =
      await a.from('user_preferences').select().eq('user_id', idA);
  check('A can read A\'s preferences', aOwn.length == 1);
  check(
    'A\'s write landed',
    (aOwn.first['favorite_genres'] as List).contains('action'),
  );
  final bOwn =
      await b.from('user_preferences').select().eq('user_id', idB);
  check('B can read B\'s preferences', bOwn.length == 1);

  // --- Cross-access reads must return ZERO rows ---
  final bReadsA =
      await b.from('user_preferences').select().eq('user_id', idA);
  check('B reading A\'s preferences returns zero rows', bReadsA.isEmpty);
  final aReadsB =
      await a.from('user_preferences').select().eq('user_id', idB);
  check('A reading B\'s preferences returns zero rows', aReadsB.isEmpty);

  // --- Cross-access writes must affect ZERO rows ---
  final bWritesA = await b
      .from('user_preferences')
      .update({'favorite_genres': ['hacked']})
      .eq('user_id', idA)
      .select();
  check('B updating A\'s preferences affects zero rows', bWritesA.isEmpty);

  final aAfter = await a
      .from('user_preferences')
      .select('favorite_genres')
      .eq('user_id', idA)
      .single();
  check(
    'A\'s data unchanged after B\'s attack',
    !(aAfter['favorite_genres'] as List).contains('hacked'),
  );

  // --- Profiles: readable by authenticated (by design), writable only by owner ---
  final bWritesAProfile = await b
      .from('profiles')
      .update({'username': 'stolen'})
      .eq('id', idA)
      .select();
  check('B updating A\'s profile affects zero rows', bWritesAProfile.isEmpty);

  await a.auth.signOut();
  await b.auth.signOut();

  stdout.writeln(
      '\n${_failures == 0 ? "ALL CHECKS PASSED" : "$_failures CHECK(S) FAILED"}');
  exit(_failures == 0 ? 0 : 1);
}
