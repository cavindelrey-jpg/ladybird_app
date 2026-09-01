// lib/core/supabase_config.dart
// Project URL + anon/public key for supabase_flutter's client-side
// initialization. Both are meant to be embedded in a compiled client app
// (that's what "anon public" means) — protection comes from RLS policies
// on the tables themselves (see supabase/migrations/), not from hiding
// this key. Never put the service_role key here or anywhere in lib/ — it
// bypasses RLS entirely and belongs only in server-side/migration tooling
// (see migration/.env, gitignored).

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://ccumxxysaaphhgdzlagk.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjdW14eHlzYWFwaGhnZHpsYWdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc4NDI5OTEsImV4cCI6MjEwMzQxODk5MX0.uKYiAsntGYM4nxZCxuLyI8dQsbdq72HqX-Ezkml-6zQ';
}
