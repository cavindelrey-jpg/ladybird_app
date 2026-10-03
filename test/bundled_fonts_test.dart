import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app (Dictionary included) must render offline on a device that has
/// never been online: every font style it uses has to come from
/// assets/google_fonts/, never from the network. With runtime fetching
/// disabled, google_fonts raises an error for any style that isn't
/// bundled -- these tests collect those errors.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<Object>> loadErrors(void Function() requestFonts) {
    GoogleFonts.config.allowRuntimeFetching = false;
    final errors = <Object>[];
    final done = Completer<List<Object>>();
    runZonedGuarded(() async {
      requestFonts();
      await GoogleFonts.pendingFonts();
      // Let any trailing async failures surface before reporting.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      done.complete(errors);
    }, (e, _) {
      errors.add(e);
      if (!done.isCompleted) {
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (!done.isCompleted) done.complete(errors);
        });
      }
    });
    return done.future.timeout(const Duration(seconds: 30));
  }

  test('every font style used by the app is bundled', () async {
    final errors = await loadErrors(() {
      const weights = [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900];
      for (final w in weights) {
        GoogleFonts.inter(fontWeight: w);
        GoogleFonts.sora(fontWeight: w);
        GoogleFonts.lora(fontWeight: w);
      }
      GoogleFonts.inter(fontStyle: FontStyle.italic);
      GoogleFonts.lora(fontStyle: FontStyle.italic);
      GoogleFonts.lora(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold);
    });
    expect(errors, isEmpty);
  });

  test('the check really detects a font that is not bundled', () async {
    final errors = await loadErrors(() => GoogleFonts.roboto());
    expect(errors.join(), contains('Roboto'));
  });
}
