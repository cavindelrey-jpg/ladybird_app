# Presentation Go/No-Go Checklist

This one's for you, not Claude Code — run it yourself the night before and again the morning of.

## Build
- [ ] Academia release build installs cleanly on the actual demo device
- [ ] Green Hill release build installs cleanly on the actual demo device
- [ ] Both apps can run side by side (two devices, or two profiles) if you want to show them together

## The demo path only (per `03_DAY3`)
- [ ] Every screen on the path loads with no visible error
- [ ] Every button on the path does something real
- [ ] No placeholder/lorem-ipsum text visible anywhere on the path
- [ ] Green Hill clearly shows different branding from Academia within the first screen

## Safety net
- [ ] Screen recording of a clean full run-through exists and is easy to pull up
- [ ] Demo device is fully charged, do-not-disturb is on, wifi confirmed working at the venue if possible
- [ ] You know which 2–3 screens you will skip if you're running short on time

## Narrative
- [ ] You can state in one sentence what Academia is (the platform) and one sentence what Green Hill is (the first client app built on it)
- [ ] You have an answer ready for "what's not built yet" — better to name it proactively (messaging, quiz auto-gen, full admin tools) as *roadmap* than have it look like an oversight

## Worth a quick check: what did autopilot decide without you?
- [ ] Skim `docs/AUTOPILOT_LOG.md` across all three days — this is the list of every default Claude Code picked instead of stopping to ask you. Nothing in there should surprise you on stage.
- [ ] Skim `docs/DEFERRED_ISSUES.md` if it exists — anything logged there is a known gap; decide if it needs a one-line mention in your "what's not built yet" answer above.

## If something breaks live
1. Don't debug on stage. Acknowledge it lightly, switch to the recorded run-through.
2. Keep talking about the product, not the bug.
