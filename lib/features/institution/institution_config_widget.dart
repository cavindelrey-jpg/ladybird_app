// lib/features/institution/institution_config_widget.dart
// Wraps child with InstitutionProvider context and rebuilds theme on change.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/institution_provider.dart';
import '../../theme/institution_theme_engine.dart';

class InstitutionConfig extends StatelessWidget {
  final Widget child;
  const InstitutionConfig({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final institution = context.watch<InstitutionProvider>().effectiveInstitution;
    return Theme(
      data: InstitutionThemeEngine.build(institution),
      child: child,
    );
  }
}
