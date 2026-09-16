import re

with open('lib/features/dashboard/universal_home_page.dart', 'r') as f:
    content = f.read()

pattern = re.compile(r'Widget _heroAndStats\(BuildContext context\) \{.*?\n  \}', re.DOTALL)

new_method = """Widget _heroAndStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          width: double.infinity,
          height: 190,
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [ac.primary, ac.navy],
            ),
            borderRadius: BorderRadius.circular(Rad.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
              right: -16, top: 4,
              child: Icon(Icons.auto_stories_rounded, size: 120, color: Colors.white.withValues(alpha: .15)),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$_timeGreeting, '),
                      TextSpan(text: _isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name.split(' ').first)),
                      const TextSpan(text: ' \\u{1F44B}'),
                    ]),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(Branding.current.tagline,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: .9), height: 1.3)),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: ac.primary),
                  const SizedBox(width: 6),
                  Text(_dateLabel, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt, height: 1.3)),
                ]),
              ),
            ]),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: _statCard(),
        ),
      ]),
    );
  }"""

content = pattern.sub(new_method.replace('\\', '\\\\'), content)
with open('lib/features/dashboard/universal_home_page.dart', 'w') as f:
    f.write(content)
