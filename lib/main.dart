// lib/main.dart
// Academia entry point.
// Initialises Firebase, remote config, and analytics before painting a frame.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/institution_provider.dart';
import 'screens/app_router.dart';
import 'services/analytics_service.dart';
import 'services/config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp();

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
        theme: AppTheme.light,
        home: const _MaintenanceGate(),
        builder: (ctx, child) {
          // Global error boundary — catches widget build errors in release.
          ErrorWidget.builder = (details) => _ErrorFallback(details: details);
          return child ?? const SizedBox.shrink();
        },
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
            Text('Under Maintenance',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
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
