// lib/features/school/fees_page.dart
// School fees, installment status, and receipts.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';

class FeesPage extends StatelessWidget {
  final AppUser user;
  const FeesPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: user,
      currentDestination: AppNavDestination.fees,
      currentTitle: 'Fees',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _statusBanner(context, ac),
          const SizedBox(height: 24),
          _installmentsCard(context, ac),
          const SizedBox(height: 24),
          _paymentMethodsCard(context, ac),
        ],
      ),
    );
  }

  Widget _statusBanner(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0B1F4D), const Color(0xFF1B3A6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Rad.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Up to date',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4ADE80))),
                ),
                const SizedBox(height: 12),
                Text('Academic Year 2025/2026',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 4),
                Text('Total Paid: 250,000 XAF',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('Outstanding Balance: 50,000 XAF (Due: 31st Oct 2025)',
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFFF4B400),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.account_balance_wallet_rounded,
              size: 56, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _installmentsCard(BuildContext context, AppColors ac) {
    final installments = [
      ('1st Installment (Registration)', '150,000 XAF', 'Paid • 05 Sep 2025', true),
      ('2nd Installment (Term 1)', '100,000 XAF', 'Paid • 10 Oct 2025', true),
      ('3rd Installment (Term 2)', '50,000 XAF', 'Pending • Due 31 Oct 2025', false),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Installment Breakdown',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 16),
          for (final (title, amount, status, isPaid) in installments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPaid ? ac.grn.withOpacity(0.12) : ac.org.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPaid ? Icons.check_rounded : Icons.pending_rounded,
                      color: isPaid ? ac.grn : ac.org,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ac.txt)),
                        Text(status,
                            style: GoogleFonts.inter(
                                fontSize: 11.5, color: ac.txt2)),
                      ],
                    ),
                  ),
                  Text(amount,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ac.txt)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentMethodsCard(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('School Payment Methods',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 12),
          Text(
            'Payments can be made via MTN Mobile Money, Orange Money, or directly at the school bursary office. Upload your proof of payment or transaction ID for automated verification.',
            style: GoogleFonts.inter(fontSize: 13, color: ac.txt2, height: 1.5),
          ),
        ],
      ),
    );
  }
}
