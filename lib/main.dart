// lib/main.dart
// Academia entry point.
// Initialises Firebase, remote config, and analytics before painting a frame.

import "dart:ui";
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/action_error_widget.dart';
import 'services/connectivity_service.dart';
import 'services/dictionary_service.dart';
import 'services/sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/app_router.dart';
import 'services/analytics_service.dart';
import 'services/config_service.dart';
import 'config/branding.dart';

Future<void> main() async {
  // runZonedGuarded catches errors that occur outside Flutter's own build/
  // layout/paint pipeline (async gaps, timers, stream callbacks) — those
  // never reach FlutterError.onError on their own, so without this they'd
  // silently vanish from Crashlytics entirely.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Every font the app uses (Inter, Sora, Lora) ships in
    // assets/google_fonts/. Never download fonts at runtime: on a phone
    // that has never been online the Dictionary -- and every other
    // screen -- must still render in the intended typeface.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Global error boundary — catches widget build errors in release so a
    // crashing subtree shows a visible fallback instead of going blank/black.
    // Set once here rather than in MaterialApp's builder (which reruns on
    // every rebuild of the app).
    ErrorWidget.builder = (details) => _ErrorFallback(details: details);

    // Firebase init — kept for Crashlytics/Analytics only (no Supabase
    // equivalent); Auth/Firestore/Storage now live on Supabase below.
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init failed (expected on web if unconfigured): $e');
    }

    // Supabase init — auth/data/storage. Same shared project as
    // academia-cameroon (see core/supabase_config.dart's header).
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);

    // Route Flutter framework errors (build/layout/paint) to Crashlytics as
    // fatal, instead of just printing to console and moving on.
    FlutterError.onError = (details) {
      // Always leave a one-line trace: the framework's console reporter
      // throttles repeats, which once hid a page-killing error entirely.
      debugPrint('FlutterError: ${details.exceptionAsString().split('\n').first} '
          '(${details.library ?? 'unknown library'})');
      FlutterError.presentError(details);
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {}
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}
      return true;
    };

    // Remote config (non-blocking — uses defaults if Firestore is unavailable)
    await ConfigService.instance.initialize();

    // Branding (which product this build is: Academia platform or a
    // school white-label like Green Hill) — must resolve before runApp
    // so the very first frame already has the right name/colors/logo,
    // not a flash of Academia defaults. Falls back to Academia on any
    // load failure rather than blocking startup (see branding.dart).
    await Branding.load();

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

    ConnectivityService().initialize();
  // Warm the offline dictionary in the background -- never block launch.
  unawaited(DictionaryService().loadDictionary());
  SyncService().startSyncTimer();
  runApp(const AcademiaApp());
  }, (error, stack) {
    // Anything not caught above (async errors, isolate-level) lands here.
    // Guarded like the handlers above: if Firebase.initializeApp() failed
    // (no network on first launch, unsupported platform) Crashlytics
    // itself throws, which would turn every async error into two.
    debugPrint('Uncaught: $error');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  });
}

class AcademiaApp extends StatelessWidget {
  const AcademiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Was scaffolded (state, prefs persistence, toggle()/setMode()) but
        // never actually registered in the widget tree, and MaterialApp
        // below had no darkTheme/themeMode — so toggling it did nothing.
        // Registering it here and wiring it into MaterialApp is the fix.
        ChangeNotifierProvider(create: (_) => ThemeProvider()..restoreFromPrefs()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..restoreFromPrefs()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) => MaterialApp(
          title: Branding.current.appName,
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          theme: AppTheme.light.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: _AcademiaPageTransition(),
              TargetPlatform.iOS: _AcademiaPageTransition(),
            }),
          ),
          darkTheme: AppTheme.dark.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: _AcademiaPageTransition(),
              TargetPlatform.iOS: _AcademiaPageTransition(),
            }),
          ),
          themeMode: themeProvider.mode,
          themeAnimationDuration: Duration.zero,
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
          // Was pinned to a single supported locale, which made following
          // the device's system language structurally impossible — with
          // only one entry in supportedLocales, Flutter's default
          // resolution always resolves to it regardless of what the OS
          // reports. English + French (Cameroon's two official languages)
          // lets Flutter's own built-in widgets (Material/Cupertino date
          // pickers, text-selection toolbar, dialog OK/Cancel, the Quill
          // editor toolbar) actually switch with the system language.
          // App-authored screen text is still hardcoded English throughout
          // — real localization of that copy (arb files + wrapping every
          // string site) is a separate, much larger pass, not attempted
          // here. No locale: override and no localeResolutionCallback
          // override means MaterialApp's default resolution (best match
          // against the device's locale list, falling back to the first
          // supported locale) is what actually does the "follow system
          // language" work.
          supportedLocales: const [Locale('en'), Locale('fr')],
          builder: (ctx, child) {
            AppText.syncWith(ctx); // text colours follow light/dark
            return child ?? const SizedBox.shrink();
          },
        ),
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
    final ac = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: ac.navy,
      body: SafeArea(child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.construction_rounded, size: 64, color: ac.gold),
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

/// What a widget that failed to build is replaced with. Must never throw
/// and must lay out anywhere: it can replace a whole page OR one tile in a
/// list or a dropdown menu entry. It used to be a full Scaffold with an
/// AppBar that also logged to Firebase Analytics during build(); with
/// Firebase unavailable that threw, which produced another error screen,
/// which threw again -- an endless error loop that froze the app.
class _ErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    final ac = Theme.of(context).extension<AppColors>();
    final color = ac?.red ?? Colors.red;
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(builder: (context, c) {
        // When a whole page failed there must be a way out -- the compact
        // notice alone left people stuck on a page with no back button.
        final roomForButton = !c.hasBoundedHeight || c.maxHeight >= 120;
        final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
        return Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.all(8),
          color: ac?.redBg ?? const Color(0xFFFFEBEE),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text('Something went wrong here.',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: color))),
            ]),
            if (roomForButton && canPop)
              TextButton.icon(
                onPressed: () => Navigator.maybeOf(context)?.maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Go back'),
              ),
          ]),
        );
      }),
    );
  }
}
