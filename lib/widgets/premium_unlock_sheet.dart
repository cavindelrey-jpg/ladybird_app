// lib/widgets/premium_unlock_sheet.dart
// MoMo / Orange Money unlock sheet for the 5,000 FCFA individual premium
// tier. Writes a pending payment record to Firestore; a Cloud Function
// (not part of this client) should listen on `payments/{id}` and, once the
// provider confirms the transaction, flip `users/{userId}.isPremium` to
// true server-side. This sheet does not set isPremium itself.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PremiumUnlockSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onUnlockSuccess;

  const PremiumUnlockSheet({
    super.key,
    required this.userId,
    required this.onUnlockSuccess,
  });

  @override
  State<PremiumUnlockSheet> createState() => _PremiumUnlockSheetState();
}

class _PremiumUnlockSheetState extends State<PremiumUnlockSheet> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedProvider = 'mtn'; // default
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // No cloud_functions dependency here — a pending payment record is
      // written to Firestore, which a backend trigger picks up to launch
      // the actual MoMo/Orange Money USSD prompt and confirm the result.
      final paymentRef = FirebaseFirestore.instance.collection('payments').doc();

      await paymentRef.set({
        'id': paymentRef.id,
        'phoneNumber': _phoneController.text.trim(),
        'provider': _selectedProvider,
        'userId': widget.userId,
        'amount': 5000,
        'currency': 'XAF',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _PendingDialog(provider: _selectedProvider),
      );
      widget.onUnlockSuccess();
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 12, left: 24, right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: C.bdr, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: C.goldp, borderRadius: BorderRadius.circular(Rad.sm)),
                child: const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Unlock Premium',
                      style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: C.txt)),
                  Text('Every past question, every school, every board.',
                      style: GoogleFonts.inter(fontSize: 12, color: C.txt2)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: C.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: C.goldp, borderRadius: BorderRadius.circular(Rad.md)),
              child: Text('5,000 FCFA — one time',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: C.navy)),
            ),
            const SizedBox(height: 20),

            Text('PAYMENT METHOD',
                style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1, color: C.txt2)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _ProviderCard(
                  label: 'MTN MoMo',
                  color: const Color(0xFFFFCC00),
                  isSelected: _selectedProvider == 'mtn',
                  onTap: () => setState(() => _selectedProvider = 'mtn'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProviderCard(
                  label: 'Orange Money',
                  color: const Color(0xFFFF6600),
                  isSelected: _selectedProvider == 'orange',
                  onTap: () => setState(() => _selectedProvider = 'orange'),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(fontSize: 14, color: C.txt),
              decoration: InputDecoration(
                hintText: '6XX XXX XXX',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: C.muted),
                prefixText: '+237 ',
                prefixStyle: GoogleFonts.inter(fontSize: 14, color: C.txt),
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter your phone number';
                if (value.length < 9) return 'Enter a valid Cameroon phone number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Text(_errorMessage!,
                  style: GoogleFonts.inter(color: C.red, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('Pay Now', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Skip for now',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: C.txt2)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PendingDialog extends StatelessWidget {
  final String provider;
  const _PendingDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    final label = provider == 'mtn' ? 'MTN MoMo' : 'Orange Money';
    return AlertDialog(
      backgroundColor: C.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
      title: Row(children: [
        const Icon(Icons.check_circle_outline_rounded, color: C.grn),
        const SizedBox(width: 8),
        Expanded(child: Text('Prompt sent', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700))),
      ]),
      content: Text(
        'Check your phone for the $label PIN prompt to approve the '
        '5,000 FCFA payment. Premium access unlocks automatically once '
        'it\'s confirmed.',
        style: GoogleFonts.inter(fontSize: 13, color: C.txt2, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // dialog
            Navigator.of(context).pop(); // sheet
          },
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: .12) : C.surf3,
          border: Border.all(color: isSelected ? color : C.bdr, width: isSelected ? 1.6 : 1),
          borderRadius: BorderRadius.circular(Rad.md),
        ),
        child: Column(children: [
          CircleAvatar(radius: 10, backgroundColor: color),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: C.txt)),
        ]),
      ),
    );
  }
}
