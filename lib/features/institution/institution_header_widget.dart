// lib/features/institution/institution_header_widget.dart
// Reusable branded header: logo + "School Name powered by Academia"
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/institution_provider.dart';
import '../../models/institution.dart';

class InstitutionHeader extends StatelessWidget {
  final bool compact;
  const InstitutionHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final inst = context.watch<InstitutionProvider>().effectiveInstitution;
    if (compact) return _CompactHeader(inst: inst);
    return _FullHeader(inst: inst);
  }
}

class _CompactHeader extends StatelessWidget {
  final Institution inst;
  const _CompactHeader({required this.inst});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Logo(inst: inst, size: 32),
      const SizedBox(width: 8),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inst.schoolName,
            style: _f(inst, 13, FontWeight.w700, inst.primary),
            overflow: TextOverflow.ellipsis),
          Text('powered by Academia',
            style: _f(inst, 9, FontWeight.w400, const Color(0xFF94A3B8))),
        ]),
      ),
    ]);
  }
}

class _FullHeader extends StatelessWidget {
  final Institution inst;
  const _FullHeader({required this.inst});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [inst.primary, inst.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        _Logo(inst: inst, size: 48),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inst.schoolName,
            style: _f(inst, 18, FontWeight.w800, Colors.white),
            overflow: TextOverflow.ellipsis),
          if (inst.tagline != null)
            Text(inst.tagline!, style: _f(inst, 12, FontWeight.w400, Colors.white70), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('powered by Academia', style: _f(inst, 10, FontWeight.w400, Colors.white54)),
        ])),
      ]),
    );
  }
}

class _Logo extends StatelessWidget {
  final Institution inst;
  final double size;
  const _Logo({required this.inst, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.25)),
      child: inst.logoUrl != null
        ? ClipRRect(borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.network(inst.logoUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback()))
        : _fallback(),
    );
  }

  Widget _fallback() => Center(
    child: Text(inst.schoolName.isNotEmpty ? inst.schoolName[0].toUpperCase() : 'A',
      style: GoogleFonts.sora(fontSize: size * 0.45, fontWeight: FontWeight.w800, color: inst.primary)));
}

TextStyle _f(Institution inst, double size, FontWeight w, Color c) {
  try { return GoogleFonts.getFont(inst.fontFamily, fontSize: size, fontWeight: w, color: c); }
  catch (_) { return GoogleFonts.inter(fontSize: size, fontWeight: w, color: c); }
}
