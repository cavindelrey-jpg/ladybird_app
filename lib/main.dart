// lib/main.dart
// Academia entry point.
// Initialises Firebase, remote config, and analytics before painting a frame.

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/institution_provider.dart';
import 'screens/app_router.dart';
import 'services/analytics_service.dart';
import 'services/config_service.dart';

Future<void> main() async {
  // runZonedGuarded catches errors that occur outside Flutter's own build/
  // layout/paint pipeline (async gaps, timers, stream callbacks) — those
  // never reach FlutterError.onError on their own, so without this they'd
  // silently vanish from Crashlytics entirely.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Global error boundary — catches widget build errors in release so a
    // crashing subtree shows a visible fallback instead of going blank/black.
    // Set once here rather than in MaterialApp's builder (which reruns on
    // every rebuild of the app).
    ErrorWidget.builder = (details) => _ErrorFallback(details: details);

    // Firebase init
    await Firebase.initializeApp();

    // Route Flutter framework errors (build/layout/paint) to Crashlytics as
    // fatal, instead of just printing to console and moving on.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Remote config (non-blocking — uses defaults if Firestore is unavailable)
    await ConfigService.instance.initialize();

    // Status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // Lock to portrait on phones; allow landscape on tablets
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(const AcademiaApp());
  }, (error, stack) {
    // Anything not caught above (async errors, isolate-level) lands here.
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class AcademiaApp extends StatelessWidget {
  const AcademiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InstitutionProvider()..restoreFromPrefs(),
      child: MaterialApp(
        title: 'Academia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: _AcademiaPageTransition(),
            TargetPlatform.iOS: _AcademiaPageTransition(),
          }),
        ),
        home: const _MaintenanceGate(),
        // Missing entirely before this fix — flutter_quill's toolbar
        // buttons (used in both the Article and Course composers) call
        // FlutterQuillLocalizations.of(context) internally, and throw an
        // UnimplementedError the instant they try to build without this
        // delegate registered. That's what made "Write a Post" and
        // "Create Course" appear to do nothing: the push happened, but
        // the composer's toolbar threw on its very first frame, in a
        // tight repeating loop, so the screen never finished rendering.
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        builder: (ctx, child) => child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Shows a maintenance screen if ConfigService.isMaintenanceMode is true.
class _MaintenanceGate extends StatelessWidget {
  const _MaintenanceGate();

  @override
  Widget build(BuildContext context) {
    if (ConfigService.instance.isMaintenanceMode) {
      return _MaintenanceScreen(
          message: ConfigService.instance.maintenanceMessage);
    }
    return const AppRouter();
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final String message;
  const _MaintenanceScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.navy,
      body: SafeArea(child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction_rounded, size: 64, color: C.gold),
            const SizedBox(height: 20),
            const Text('Under Maintenance',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
                textAlign: TextAlign.center),
          ]),
        ),
      )),
    );
  }
}

/// A single, consistent motion for every screen transition in the app —
/// a subtle fade combined with a short upward slide, eased out rather than
/// linear. Replaces the stock OS default (which differs per platform and
/// doesn't carry any of the app's own character) with one deliberate,
/// branded feel used everywhere.
class _AcademiaPageTransition extends PageTransitionsBuilder {
  const _AcademiaPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.instance.track(AcademiaEvent.pageViewed,
        params: {'error': details.exception.toString()});
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 72, height: 72,
            decoration: BoxDecoration(color: C.redb,
                borderRadius: BorderRadius.circular(Rad.xl)),
            child: const Icon(Icons.error_outline_rounded, size: 36, color: C.red)),
          const SizedBox(height: 16),
          const Text('An unexpected error occurred',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(details.exception.toString(),
              style: const TextStyle(fontSize: 12, color: C.txt2),
              textAlign: TextAlign.center, maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ]),
      )),
    );
  }
}
