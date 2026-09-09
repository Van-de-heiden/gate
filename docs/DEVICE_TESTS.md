# Physical-device acceptance: Gate 0.2

The primary regression test is **A remains usable while B is requested and learned**.

## Prerequisites

- Automatic signing succeeds for Gate plus Monitor, Shield Configuration, Shield Action and Widget.
- Shared App Group is provisioned; authorisation and notifications are allowed.
- After updating from 0.1, re-arm from onboarding/settings.
- Select two **individual** distraction apps and one website. Exclude Phone and WhatsApp.
- Start the deliberate 2-minute debug test; later repeat with the normal 60-minute allowance.

## Independent grants

1. Reach the free threshold and confirm A and B are both shielded.
2. Request A; open the Gate notification, or open Gate directly.
3. Read the chapter(s), answer the quiz and grant five minutes.
4. The lesson sheet must close. A's grant is a small card on Today.
5. While A is still granted, open B and request a lesson.
6. B's request must be visible; A's card must not hide it.
7. Pass B. Both grants must be present with **different activity IDs**.
8. Consume A's five active minutes. Only A re-shields; B remains available.
9. Consume B's allowance. Only B re-shields.
10. Repeat with a website in Safari, app links, Spotlight and App Library.
11. End one grant manually; the other is unchanged.
12. Wait past a grant's 30-minute wall-clock expiry. It must re-shield even if unused.

## Failure, interruption and timing

- Fail A three times: no grant, gradually larger retry, 15-minute cooldown **only for A**.
- B can still request and complete a lesson.
- Dismiss a lesson, use a different app, then resume: original target and answer order persist.
- Request B while A's lesson is paused: the result from A must never unlock B.
- Force-quit/relaunch during a lesson: resume the stored attempt.
- If monitor setup fails after passing, no new exception; preserve the passed result for retry.
- Backgrounding the app stops narration and the learning-active-time counter.
- A previously delivered stale grant callback must not clear a newer grant.
- Restart device, unlock once, then test grants and monitoring again.
- Test 23:55–00:05: prior-day grants expire, free daily pool resets once.
- Reapplying settings/resuming on the same day must not create a second free hour.

## Content and product

- Try all eight paths; answer order changes between sessions.
- After time advances naturally, due questions appear in mixed sessions.
- Correct and wrong answers show explanations, not just scores.
- Every tested question has its lesson available before the quiz.
- Optional photos load only after consent; offline text/diagrams/quiz still work.
- Medium widget shows four entries, large up to eight; changes follow explicit save.
- Widget links never create a consumption exemption.
- Call and receive a call; use WhatsApp before and after the free limit.
- Check large accessibility text, VoiceOver, Reduce Motion, light/dark appearances.
- Chart values are labelled confirmed usage minimums, not exact total Screen Time.

## Release gates not satisfied by a source-code build

Long-duration real-device reliability, browser coverage, accessibility visual review, independent
curriculum review, complete content filtering and App Store entitlement approval are not implied
by green unit tests. Record failures with iOS/Xcode versions and exact reproduction steps.

## 0.3 acceptance checks

### Keyboard regression
- Open a chapter, type a reflection note, tap **Eingabe fertig**. Keyboard closes, note stays.
- Reopen it, type and tap **Zur Prüfung**. Keyboard closes and the first task is visible.
- Solve a numeric and a recall task. Test decimal comma and period. **Fertig**, return, interactive scrolling, next/back and closing the sheet must dismiss the keyboard without losing input.
- Repeat in library search and the new launcher-item editor, including on a small screen and large Dynamic Type.

### Additive selections
- Upgrade with an existing v0.2 selection, usage, notes and learning results. IDs/progress and today's usage stay.
- Save A + B; reopen picker, deselect A and add C; save. A, B and C must stay protected. Repeat with an empty proposed selection and after a day rollover/relaunch.
- Onboarding opened again must not shrink the selection. There is no in-app pause or deletion action after activation.
- Reorder launcher entries and add a link. Previously saved entries/destinations cannot be deleted, disabled or replaced.
- Phone/WhatsApp remain outside the consumption selection as configured. Gate cannot resolve opaque tokens into an automatic exception for a mistakenly selected communication app.

### Permanent websites / helpful interruption
- In **Mehr → Dauerhaft geschützte Websites**, select a benign test domain, never Phone or apps, and save it.
- Test during the free hour, with a consumption grant, at midnight and after restart. It must remain shielded. A learning result must not grant it access.
- On Gate's website shield, tap **Abstand gewinnen**; notification opens the pause page on iOS 26. If notifications are disabled, open Gate manually: the pending pause is persisted.
- Try while a different learning session was suspended. Its progress must remain.
- Automatic adult filtering may render Apple's own block page first. It cannot be redirected by this Screen Time implementation. **Heute → Einen Impuls unterbrechen** remains the manual route.
- Closing/finishing the optional 60-second pause does not unlock the domain. No trigger answers are retained.
- Individual authorization can still be revoked in iOS and the app can be uninstalled. The additive lock is an in-app commitment, not device supervision.

### Curriculum and images
- Search a term, filter by category, open a specific chapter, finish it, and reopen it. Explicit chapter practice must not jump to a different chapter.
- Try all seven formats, including wrong/missing numeric values, unmatched pairs, multiple selections and reordered steps.
- Suspend/reopen each input format. Answers and permutation persist. A short partial round must not prematurely mark a new chapter complete.
- Open **Wissen auffrischen** when due questions exist: only due questions appear in this voluntary review mode.
- Disable networking. All eight image motifs and all chapters remain usable; the older external NASA source photo still loads only on explicit request.
