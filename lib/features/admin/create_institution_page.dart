// lib/features/admin/create_institution_page.dart
// Register a new school — Super Admin only. This was the actual gap that
// made testing a new school require a manual Firestore document add:
// InstitutionRepository.create() has existed the whole time, nothing in
// the app ever called it. This is that missing call site.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/institution.dart';
import '../../repositories/institution_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

const _kPresetPalettes = [
  ('Navy & Gold',   '#0A1F44', '#152D5E', '#C9A227'),
  ('Purple',        '#7C3AED', '#A78BFA', '#F59E0B'),
  ('Forest Green',  '#065F46', '#059669', '#F59E0B'),
  ('Crimson',       '#991B1B', '#DC2626', '#F59E0B'),
  ('Ocean Blue',    '#1E3A8A', '#3B82F6', '#F59E0B'),
];

class CreateInstitutionPage extends StatefulWidget {
  const CreateInstitutionPage({super.key});

  @override
  State<CreateInstitutionPage> createState() => _CreateInstitutionPageState();
}

class _CreateInstitutionPageState extends State<CreateInstitutionPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Cameroon');
  final _emailCtrl = TextEditingController();

  int _paletteIndex = 0;
  final Set<InstitutionFeature> _features = {
    InstitutionFeature.library,
    InstitutionFeature.clubs,
    InstitutionFeature.announcements,
  };

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _countryCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _saving = true; _error = null; });

    final code = _codeCtrl.text.trim().toUpperCase();
    final codeError = InstitutionRepository.validateCode(code);
    if (codeError != null) {
      setState(() { _error = codeError; _saving = false; });
      return;
    }

    final taken = await InstitutionRepository.instance.codeExists(code);
    if (taken) {
      setState(() { _error = 'That school code is already taken — try another.'; _saving = false; });
      return;
    }

    final (_, primary, secondary, accent) = _kPresetPalettes[_paletteIndex];
    final institution = Institution(
      institutionId: '', // Firestore assigns the real ID on create
      schoolCode: code,
      schoolName: _nameCtrl.text.trim(),
      primaryColor: primary, secondaryColor: secondary, accentColor: accent,
      fontFamily: 'Inter',
      enabledFeatures: _features.toList(),
      tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
      contactEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
    );

    final result = await InstitutionRepository.instance.create(institution);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result is Success<String>) {
      showToast(context, '✅ ${institution.schoolName} created — code: $code');
      Navigator.of(context).pop();
    } else {
      setState(() => _error = (result as Failure).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Register a School', style: AppText.title),
      ),
      body: AppBackground(child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('School Code', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: AppText.body.copyWith(fontSize: 15, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: 'e.g. AUGUSTA2026',
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
              validator: (v) => InstitutionRepository.validateCode(v ?? ''),
            ),
            const SizedBox(height: 6),
            Text('4–12 letters/numbers. This is what students type on the "Enter your school code" screen.',
                style: AppText.caption),
            const SizedBox(height: 20),
            Text('School Name *', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              style: AppText.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Augusta Institute',
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _taglineCtrl,
              style: AppText.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Tagline (optional)',
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _countryCtrl,
                  style: AppText.body.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Country',
                    filled: true, fillColor: C.surf3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _emailCtrl,
                  style: AppText.body.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Contact email (optional)',
                    filled: true, fillColor: C.surf3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Text('Brand Colors', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: List.generate(_kPresetPalettes.length, (i) {
                final (label, primary, secondary, accent) = _kPresetPalettes[i];
                final active = i == _paletteIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.md),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _paletteIndex = i);
                    },
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: C.surf, borderRadius: BorderRadius.circular(Rad.md),
                        border: Border.all(color: active ? C.gold : C.bdr, width: active ? 2 : 1),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _swatch(primary), const SizedBox(width: 4),
                          _swatch(secondary), const SizedBox(width: 4),
                          _swatch(accent),
                        ]),
                        const SizedBox(height: 6),
                        Text(label, style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Text('Enabled Features', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: InstitutionFeature.values.map((f) {
                final active = _features.contains(f);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => active ? _features.remove(f) : _features.add(f));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? C.primary : C.surf2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? C.primary : C.bdr),
                      ),
                      child: Text(f.key, style: AppText.caption.copyWith(
                          fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: active ? Colors.white : C.txt2)),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Text(_error!, style: AppText.bodySm.copyWith(color: C.red)),
              ),
            ],
            const SizedBox(height: 28),
            PrimaryBtn(label: 'Create School', loading: _saving, onTap: _submit),
          ],
        ),
      )),
    );
  }

  Widget _swatch(String hex) {
    final c = hex.replaceAll('#', '').padLeft(6, '0');
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(color: Color(int.parse('FF$c', radix: 16)), shape: BoxShape.circle),
    );
  }
}
