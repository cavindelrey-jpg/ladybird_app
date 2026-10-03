// lib/core/realtime_tolerant.dart
// supabase_flutter's .stream() does a PostgREST fetch AND opens a
// realtime channel. When the channel fails or times out (backgrounded
// app, weak mobile signal, realtime unavailable) it emits a
// RealtimeSubscribeException into the stream -- and Flutter's
// AsyncSnapshot drops the data it was showing when an error arrives, so
// a perfectly good list blanked out into an error / "nothing here yet"
// state. Found in the 2026-10-02 QA run with realtime unreachable: the
// notifications list loaded, then vanished a second later.
//
// The PostgREST fetch is what decides "data vs real error" (its failures
// still come through); the channel rejoins on its own and supabase
// re-fetches on resubscribe, so a dropped live connection only means
// "no live updates for a moment" -- never "your data is gone".

import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeSubscribeException;

extension RealtimeTolerantStream<T> on Stream<T> {
  Stream<T> realtimeTolerant() => handleError((_) {}, test: (e) => e is RealtimeSubscribeException);
}
