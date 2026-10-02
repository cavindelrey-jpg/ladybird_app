// lib/core/supabase_config.dart
// Project URL + anon/public key for supabase_flutter's client-side
// initialization. Both are meant to be embedded in a compiled client app
// (that's what "anon public" means) — protection comes from RLS policies
// on the tables themselves (see supabase/migrations/), not from hiding
// this key. Never put the service_role key here or anywhere in lib/ — it
// bypasses RLS entirely and belongs only in server-side/migration tooling
// (see migration/.env, gitignored).
//
// Both can be overridden at build time to point a QA build at a local
// stack (`supabase start`) without touching production:
//   flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
//               --dart-define=SUPABASE_ANON_KEY=<local anon key>
// A normal build (no defines) uses the production project below.

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ccumxxysaaphhgdzlagk.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjdW14eHlzYWFwaGhnZHpsYWdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc4NDI5OTEsImV4cCI6MjEwMzQxODk5MX0.uKYiAsntGYM4nxZCxuLyI8dQsbdq72HqX-Ezkml-6zQ',
  );
}
