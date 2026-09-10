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
- On Gate's website shield, tap **Pause in Gate anfordern**; notification opens the pause page on iOS 26. If notifications are disabled, open Gate manually: the pending pause is persisted.
- Try while a different learning session was suspended. Its progress must remain.
- Automatic adult filtering may render Apple's own block page first. It cannot be redirected by this Screen Time implementation. **Heute → Pause** and **gate · Pause** in the widget are the direct manual routes.
- Closing/finishing the optional 60-second pause does not unlock the domain. No trigger answers are retained.
- Individual authorization can still be revoked in iOS and the app can be uninstalled. The additive lock is an in-app commitment, not device supervision.

### Curriculum and images
- Search a term, filter by category, open a specific chapter, finish it, and reopen it. Explicit chapter practice must not jump to a different chapter.
- Try all seven formats, including wrong/missing numeric values, unmatched pairs, multiple selections and reordered steps.
- Suspend/reopen each input format. Answers and permutation persist. A short partial round must not prematurely mark a new chapter complete.
- Open **Wissen auffrischen** when due questions exist: only due questions appear in this voluntary review mode.
- Disable networking. All eight image motifs and all chapters remain usable; the older external NASA source photo still loads only on explicit request.

## Everyday allowance and native interface regression checks

- Upgrade with an old persisted two-minute test: opening Gate restores the 60-minute allowance, preserving confirmed usage and learning history. No re-selection is required.
- Under Mehr, expand Entwickleroptionen and explicitly confirm a test. At 1 confirmed minute the test has an upper bound of 1 minute left; at 2 it blocks. The Today screen and Settings both expose Auf Alltag wechseln.
- Leave the Apple picker draft empty or different from the saved selection, then use the dedicated everyday-mode button. It must use the saved monitoring selection and leave the draft uncommitted.
- Switch from a used-up two-minute test to everyday mode: 2 confirmed minutes remain 2 and the free-time upper bound becomes 58. A later two-minute callback must not re-block everyday mode; the 60-minute callback must. At 70 confirmed minutes, mode switching must not grant another free hour.
- Leave the test enabled overnight. The first next-day app/monitor update returns to 60 minutes and resets only daily usage, not selection or learning progress. A same-day restart retains an explicitly confirmed new test.
- Compare Gate's confirmed checkpoint and timestamp with iOS Screen Time. Gate is not a live total-device counter; if the discrepancy persists in everyday mode, capture both values and the Gate timestamp rather than resetting usage.
- Check Today, Learning and Settings in light/dark appearance, larger text and Reduce Motion. Check contrast, scroll access, tab selection and disabled-button visibility. Physical-device visual QA remains required.

## Gate-branded shields

- On a consumption shield, check the ivory portal icon, Gate name, message and both buttons in light/dark device appearance and with larger text. The primary action still requests a lesson; the secondary action closes the shielded activity.
- On a permanently selected website that reaches Gate's shield, check the supportive message and “Pause in Gate anfordern”. Tap the Gate notification to reach the existing pause page; with notifications disabled, opening Gate manually should still present the pending pause. Completing the pause must never grant website access.
- Messages are chosen in 30-minute time buckets when iOS requests a configuration. iOS may cache the screen, so a new message on every visit is not promised. No attempt counter or browsing history is added.
- The automatic adult filter remains unchanged and can still display Apple's system page instead. Do not disable it to obtain a branded screenshot.

## Fuel gauge and native Liquid Glass navigation

- Build with Xcode 26+ and run on iOS 26+: the bottom bar must be the native floating system bar. Check system selection gestures, scrolling content under the bar, keyboard presentation, light/dark appearance, Reduce Transparency and Reduce Motion. Earlier supported iOS versions should show their native tab bar instead.
- Open a learning path, switch to Today and back: the path and scroll position should remain. Open Mehr → Textliste, switch tabs and return: unsaved new entries must remain; Back and Sichern must be reachable.
- Type into library search, select another native tab, then return: the keyboard dismisses and the search text remains.
- With 0 / 30 / 60 confirmed consumption minutes in everyday mode, the needle must show full / half / empty with upper bounds of 60 / 30 / 0 free minutes. Consumption above 60 must never send the needle below empty.
- At 1 minute in the deliberate 2-minute test, the gauge shows half and at most 1 minute free. Switch to everyday mode: the same usage gives at most 59 minutes and a nearly full dial; usage must not reset.
- Check a small iPhone and the largest Dynamic Type sizes. The numeric value and explanatory text must remain readable. VoiceOver reads one free-time value, rather than the decorative ticks. Reduce Motion suppresses needle/value animation.
- From Apple's filter page, close the browser tab and tap **gate · Pause** in the medium and large widget. Gate opens its pause even with notifications disabled. Repeat while Gate has a suspended lesson; its answers must survive. Closing the pause must not unlock any website.
