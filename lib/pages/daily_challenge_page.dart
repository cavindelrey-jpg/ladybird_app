// lib/pages/daily_challenge_page.dart
// Minimal MCQ flow. Real XP only — awarded per correct answer at the
// challenge's own xpPerCorrect rate (10 XP/correct, matching the decided
// MCQ rate), written once via DailyChallengeRepository.submitAttempt so a
// user can't replay the same day's challenge for repeat XP.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/app_user.dart';
import '../models/daily_challenge.dart';
import '../models/xp_transaction.dart';
import '../repositories/daily_challenge_repository.dart';
import '../services/auth_service.dart';
import '../core/result.dart';

class DailyChallengePage extends StatefulWidget {
  final AppUser user;
  final DailyChallenge challenge;
  const DailyChallengePage({super.key, required this.user, required this.challenge});

  @override
  State<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends State<DailyChallengePage> {
  late final List<int?> _answers =
      List<int?>.filled(widget.challenge.questions.length, null);
  int _step = 0;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await DailyChallengeRepository.instance.submitAttempt(
      challenge: widget.challenge,
      userId: widget.user.id,
      selectedAnswers: _answers.map((a) => a ?? -1).toList(),
    );
    if (!mounted) return;
    if (result case Success(:final value)) {
      final awarded = await AuthService.instance.addXp(widget.user.id, value, XpSource.mcq);
      if (!mounted) return;
      final ac = AppColors.of(context);
      Navigator.of(context).pop(true);
      final message = awarded < value
          ? 'Challenge complete — +$awarded XP (daily cap reached)'
          : 'Challenge complete — +$awarded XP!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: ac.grn));
    } else if (result case Failure(:final message)) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.challenge.questions[_step];
    final isLast = _step == widget.challenge.questions.length - 1;
    final ac = AppColors.of(context);

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text(widget.challenge.title, style: GoogleFonts.sora(
            fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Question ${_step + 1} of ${widget.challenge.questions.length}',
              style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
          const SizedBox(height: 12),
          Text(q.prompt, style: GoogleFonts.sora(
              fontSize: 17, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 20),
          ...List.generate(q.options.length, (i) {
            final selected = _answers[_step] == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _answers[_step] = i),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? ac.primaryBg : ac.surf,
                    borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: selected ? ac.primary : ac.bdr),
                  ),
                  child: Row(children: [
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18, color: selected ? ac.primary : ac.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(q.options[i],
                        style: GoogleFonts.inter(fontSize: 13.5, color: ac.txt))),
                  ]),
                ),
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _answers[_step] == null || _submitting
                  ? null
                  : () {
                      if (isLast) {
                        _submit();
                      } else {
                        setState(() => _step++);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.pur, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isLast ? 'Submit' : 'Next',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
