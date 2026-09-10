# Gate

**Less distraction. More understanding. Free to use, modify and share.**

Gate is an open-source iPhone app that adds a learning step before additional consumption time.
Code and original lesson content are available under the [MIT licence](LICENSE).
Third-party reference photos are not relicensed under MIT.

## Status: 0.3 learning-library alpha

The first on-device spike worked. Gate now has independent app grants, a monochrome interface,
a substantially expanded curriculum and permanent in-app selections. It is **not a finished, independently validated App Store release**.

- A shared daily allowance of **30 minutes** for explicitly selected apps and websites.
- Independent **5 / 10 / 15 active-minute grants**; up to eight at once.
- Separate request, failure and cooldown state per app/domain.
- One activity ID per grant: expiration of A does not close B.
- An always-reachable request panel; a successful quiz closes its sheet.
- A medium/large **text-only launcher widget**, extendable and reorderable in the app.
- Onboarding, local learning history, confirmed usage checkpoints and settings.
- An iOS usage report with separate consumption-selection and all-app views, daily app/site breakdowns and an explicit device selection when several iPhones report data.
- A fuel-style free-time gauge and the native system tab bar, with independent navigation per tab.
- **16 learning paths, 96 chapters, 504 questions in seven formats** with explanations.
- Original German lesson text, diagrams, optional narration and reflection notes.
- Random path rotation, curriculum progression and due-question priority.
- Repetition starts at 1 / 3 / 7 / 14 / 30 days; errors return earlier.
- Repeating immediately cannot inflate the long-term mastery indicator.
- Interrupted sessions retain their target, question order and answers.

### Learning paths

Learning & memory · Clear thinking · Statistics · Digital safety · Decisions & economics ·
Everyday physics · Earth systems · History & source criticism · Philosophy · Business ·
Personal money · Industries · Health · Self-development · Communication · Society & institutions.

The curriculum is an **introductory, extensible edition**, not sixteen complete specialist courses.
Content is AI-assisted, authored for Gate, with linked reading references. It has not received
independent subject-matter review. Source organisations do not endorse or validate Gate.
Every tested question is accompanied by its source lesson in the session.

### How the time rule works

The first 30 minutes form one shared pool for the selected apps and websites.
After that, grants and failures are independent. A 5-minute grant starts with 3 questions;
10 minutes with 5; 15 minutes with 7. More confirmed daily consumption and failed attempts add
questions, capped at 14. Passing requires at least 80%. Every third failed attempt creates a
15-minute cooldown for that target.

Existing saved 60-minute everyday budgets migrate to 30 on the next app or monitor update.
Confirmed usage is retained: 28 consumed minutes leave 2; 30 or more leave none. Existing
earned grants remain independent. The 2-minute debug test still requires explicit activation,
and both leaving the test and the next-day reset return to 30. Additional question load is
measured from the new 30-minute allowance. This is the free consumption budget, not a hard
cap on total device Screen Time; short learning-earned grants remain available.

A grant expires when its active usage is exhausted **or 30 wall-clock minutes after issue**,
whichever comes first. Its displayed remaining active time is an upper bound based on the latest
iOS callback. It is not a fabricated second-by-second timer.

The **Freigabezähler** history shows **confirmed minimums for the selected consumption pool**, not total
device Screen Time. The monitor requests a checkpoint at every active minute up to 24 hours.
iOS delivers these callbacks; delivery can be delayed. Missing callbacks are not zero usage,
and elapsed wall-clock time never increases the consumption counter.

### Monitoring and recovery

Gate inspects its saved daily schedule, selected apps/domains and all minute events on opening
and about once a minute while the app is in the foreground. Missing or older five-minute
configurations are reinstalled automatically. Screen Time registration runs off the main actor.
Healthy monitors are not restarted simply because no new consumption has arrived: an idle
phone or an unselected app legitimately produces no new consumption event.

**Mehr → Nutzungsmessung → Messung neu verbinden** explicitly re-registers a monitor whose
configuration exists but whose callbacks appear stuck. It keeps confirmed usage, learning
progress and independent grants. Past activity within the current day is requested from iOS;
Gate never assumes a new total or resets the budget to obtain a fresh start.

The interface distinguishes **Monitor geprüft** (configuration inspection) from **Neue Nutzung
zuletzt bestätigt** (a higher iOS threshold). Duplicate/out-of-order callbacks cannot refresh the
latter timestamp. An optional local diagnostic contains registration counts, timestamps and
selection counts, but no app names, opaque tokens or browsing history.

The foreground refresh reads shared state without rewriting unchanged shields. The monitor
also applies policy only when the restriction inputs change, under the same process lock, so
minute callbacks do not keep resetting identical Managed Settings. These APIs do not provide a
background poll for total Screen Time on a wall-clock schedule. See Apple's
[monitoring API](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter)
and [past-activity behavior](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity).

### Comparable iOS usage reports

**Bilanz → Bildschirmzeit** uses Apple's `DeviceActivityReport` extension, not the monitor's
threshold log, as the primary statistics display. Choose **Konsum-Auswahl** for the saved app/domain
tokens or **Alle Apps** for all reported activity, including productive apps. Empty consumption
selections never fall back to an all-app report. Reporting is filtered to iPhone models; if multiple
devices report data, choose the matching device inside the report. Their totals are never silently added.

Tap a day for hours, minutes, date and the app/website breakdown. The report displays iOS's
`lastUpdatedDate`, not a locally invented refresh time. Segment totals come from iOS; adding app
and website breakdowns again could double-count overlapping activity. Displayed minutes are rounded
down. Missing report data is distinct from a reported zero, and reloading does not guarantee fresh data.

The original checkpoint chart and monitor diagnostics remain under **Freigabezähler**. Learning
results remain under **Lernbilanz**. Only the selected-pool monitor controls allowance and shielding;
viewing all-app usage never adds productive activity to the allowance or changes a grant.

Private usage data and app/site names remain in the report extension's memory and UI. The target
has no App Group entitlement or shared-store code and does not export, log or network those values.
See Apple's [report isolation](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport)
and [filter semantics](https://developer.apple.com/documentation/deviceactivity/deviceactivityfilter/init(segment:users:devices:applications:categories:webdomains:)).
The newer iOS 26.4 [direct usage export API](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitydata(filteredby:using:))
requires separate data-access authorization and entitlement and is restricted to EU customer installations.
It is not the foundation for this Swiss app; ordinary reports retain iOS 17.4 compatibility.

## Build and try

Requires **iOS 17.4+**, a compatible Xcode and an Apple development team with Family Controls.
The notification path does not require a beta SDK.
For the native **Liquid Glass tab bar**, build with **Xcode 26 or newer** and run on **iOS 26 or newer**.
Older supported iOS versions use their standard system tab bar. Gate does not draw a replacement
background or selection overlay; system appearance and accessibility settings apply.
See [Apple's adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

1. Switch to `codex/technical-spike` and pull.
2. Open `Gate.xcodeproj`; choose the shared **Gate** scheme.
3. Check automatic signing on the app and five extensions, including **GateReportExtension** with Family Controls enabled.
4. App Group on shared-state targets: `group.ch.mauruspichler.gate`. The isolated report target deliberately has no App Group.
5. Run on a **physical iPhone** for Screen Time behaviour.
6. Complete onboarding; expand categories and select individual distraction apps/domains.
7. Do **not** select Phone or WhatsApp. Gate cannot inspect opaque tokens to identify these
   apps automatically, and broad category selection is rejected in this mode.
8. Debug settings include a deliberate **2-minute test mode**. The everyday budget is 30 minutes.
9. Add Gate's medium/large widget. Remove home-screen icons manually if desired.

Migration from 0.1 preserves the selected tokens, but stops the two legacy monitors and asks you
to set up monitoring again. Old temporary passes are not imported. No quiz learning history
existed in the spike.

### Widget limits

The widget is a list of explicit links. Saved destinations can be reordered and new ones added;
they cannot be deleted, disabled or replaced from within Gate. It routes through Gate before asking iOS to
open the destination. It cannot replace SpringBoard or programmatically remove icons.
Medium shows four enabled entries; large shows up to eight. URL schemes require the relevant
app to be installed, and some apps do not offer a supported opening URL.
Phone calls are unaffected when Phone is excluded from the restriction selection.
A `tel:` link can be configured for a specific contact.
The widget's **gate · Pause** link opens the supportive Gate pause directly. It does not unlock websites.

### Safety and privacy limits

The iOS adult-web filter and explicit Apple-media restrictions remain set during free and
earned time. After activation, the saved consumption selection can only be extended; there is no
in-app action to pause protection. The supportive **Gate-Pause** is always available and keeps protection active.
This is **not an absolute explicit-content guarantee**: Gate cannot inspect every frame,
post or message in third-party apps. Individual Family Controls authorisation can be revoked.
Do not represent self-authorised Screen Time controls as impossible to bypass.

Shared state uses an App Group file, a cross-process lock and atomic writes. Only an armed
monitor can produce an active grant. On storage failures, existing shields are not deliberately
cleared. There is no analytics SDK, backend, account or advertising.

Text, diagrams, eight conceptual image motifs and quiz content are bundled. The original NASA
reference photos remain **opt-in online loads**
from their stated source; the host receives normal network information such as IP address.
Offline fallback never prevents a quiz. See [content & photo credits](docs/CONTENT.md).

## Verification

```sh
python3 scripts/validate.py
swift test
xcodebuild -project Gate.xcodeproj -scheme Gate -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The CI workflow runs these checks on macOS. A successful unsigned build cannot verify signing,
Screen Time callbacks, actual usage reports, real web blocking, notifications or widget launching on a physical phone.
Use the [device acceptance checklist](docs/DEVICE_TESTS.md) before merging.

## Distribution

Apple's [Family Controls distribution entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
is a separate requirement for distribution. A development provisioning warning does not mean
TestFlight/App Store approval is already granted.

## Contributing

Use the authored modules in `scripts/content/` and rebuild with `scripts/build_curriculum.py`.
Keep stable lesson/question IDs so historical learning data survives. Each chapter needs a
learning objective, explanations, a worked case, a transfer task, a source and explained questions
in several formats. See [content design](docs/CONTENT.md); run validation and the Swift tests.
Do not add remote feeds or unreviewed autogenerated lessons at runtime.

## 0.3: a larger learning library and deliberate commitments

- **16 paths / 96 chapters / 504 explained tasks** with seven native input formats and a task-at-a-time quiz. Existing learning history, notes, original IDs and the independent app-grant architecture remain.
- Search, topic filters and direct chapter practice. Due-only voluntary reviews, format variation and fuller chapter coverage before completion.
- Eight bundled editorial image motifs and a simple original portal app icon. Content/images work offline; the previous NASA source image remains separately credited.
- Visible keyboard dismissal on notes, quiz answers, search and launcher editing. Next/back/close dismiss the keyboard while keeping input.
- Saved consumption selections are additive: deselection is retained at the persistence boundary, including v0.2 migration and onboarding re-entry. Saved launcher destinations can be reordered and extended, not deleted/disabled/replaced. Protection cannot be paused from within the app after activation.
- A separate permanent website selection cannot be unlocked through learning or the free allowance. Its Gate shield leads via a notification/manual app opening to a helpful pause page, without recording personal trigger answers.

### Platform boundary for website protection

The built-in automatic adult filter stays active. Apple can show its own block page before a Gate shield. `WebContentSettings` does not provide arbitrary browser redirects or a callback to Gate when that system page appears; this version does not replace it. Gate's custom shield applies to expressly selected permanent website tokens when iOS invokes the shield extension. From Apple's page, close the browser tab and open **gate · Pause** in the widget or **Pause** at the top of Today. This manual route is independent of the filter and of notification permission. Family Controls individual authorization remains revocable and Gate itself remains uninstallable; in-app commitment is not MDM/device supervision. See [Apple's Screen Time explanation](https://developer.apple.com/videos/play/wwdc2022/110336/) and [web-filter API](https://developer.apple.com/documentation/managedsettings/webcontentsettings).

Upgrade on the existing branch, build all six targets, and run the [0.3 physical-device checks](docs/DEVICE_TESTS.md). In particular check keyboard dismissal and permanent shielding on the actual iOS version. See [content design](docs/CONTENT.md) and [asset provenance](docs/ASSETS.md).
