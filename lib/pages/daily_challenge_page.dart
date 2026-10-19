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
import '../widgets/application_shell.dart';
import '../widgets/app_background.dart';

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

    return ApplicationShell(
      user: widget.user,
      currentTitle: widget.challenge.title,
      subtitle: 'Question ${_step + 1} of ${widget.challenge.questions.length}',
      currentDestination: AppNavDestination.none,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      contextualPanel: _buildChallengeContextualPanel(context, ac),
      child: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Question ${_step + 1} of ${widget.challenge.questions.length}',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
            const SizedBox(height: 12),
            Text(q.prompt, style: GoogleFonts.sora(
                fontSize: 17, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: List.generate(q.options.length, (i) {
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
              ),
            ),
            const SizedBox(height: 16),
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
                    : Text(isLast ? 'Submit Challenge' : 'Next Question',
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildChallengeContextualPanel(BuildContext context, AppColors ac) {
    final answeredCount = _answers.where((a) => a != null).length;
    final total = widget.challenge.questions.length;
    final progress = total > 0 ? (answeredCount / total) : 0.0;
    final totalXpPossible = total * widget.challenge.xpPerCorrect;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, color: ac.gold, size: 22),
            const SizedBox(width: 8),
            Text('Daily Challenge', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: ac.txt)),
          ],
        ),
        const SizedBox(height: 14),

        // Progress Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.txt2)),
                  Text('$answeredCount / $total answered',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: ac.bdr,
                  valueColor: AlwaysStoppedAnimation<Color>(ac.primary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.stars_rounded, size: 16, color: ac.gold),
                  const SizedBox(width: 6),
                  Text('Earn up to $totalXpPossible XP',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: ac.txt)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Question Navigator
        Text('Questions', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: ac.txt)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(total, (i) {
            final isCurrent = i == _step;
            final isAnswered = _answers[i] != null;
            return InkWell(
              onTap: () => setState(() => _step = i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? ac.primary
                      : (isAnswered ? ac.grnBg : ac.surf),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent
                        ? ac.primary
                        : (isAnswered ? ac.grn : ac.bdr),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isCurrent ? Colors.white : (isAnswered ? ac.grn : ac.txt),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Rules
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rules & Rewards', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: ac.txt)),
              const SizedBox(height: 8),
              Text(
                '• 10 XP awarded per correct answer.\n• Each day\'s challenge can be completed once for XP.\n• Maintaining consecutive daily completions builds your streak multiplier!',
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
