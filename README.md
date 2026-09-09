# Gate

**Less distraction. More understanding. Free to use, modify and share.**

Gate is an open-source iPhone app that adds a learning step before additional consumption time.
Code and original lesson content are available under the [MIT licence](LICENSE).
Third-party reference photos are not relicensed under MIT.

## Status: 0.2 product alpha

The first on-device spike worked. This iteration replaces its single-grant architecture and adds a
monochrome product interface. It is **not a finished, independently validated App Store release**.

- A shared daily allowance of **60 minutes** for explicitly selected apps and websites.
- Independent **5 / 10 / 15 active-minute grants**; up to eight at once.
- Separate request, failure and cooldown state per app/domain.
- One activity ID per grant: expiration of A does not close B.
- An always-reachable request panel; a successful quiz closes its sheet.
- A medium/large **text-only launcher widget**, editable in the app.
- Onboarding, local learning history, confirmed usage checkpoints and settings.
- **8 learning paths, 24 chapters, 96 questions** with explanations.
- Original German lesson text, diagrams, optional narration and reflection notes.
- Random path rotation, curriculum progression and due-question priority.
- Repetition starts at 1 / 3 / 7 / 14 / 30 days; errors return earlier.
- Repeating immediately cannot inflate the long-term mastery indicator.
- Interrupted sessions retain their target, question order and answers.

### Learning paths

Learning & memory · Clear thinking · Statistics · Digital safety · Decisions & economics ·
Everyday physics · Earth systems · History & source criticism.

The curriculum is an **introductory, extensible edition**, not eight complete specialist courses.
Content is AI-assisted, authored for Gate, with linked reading references. It has not received
independent subject-matter review. Source organisations do not endorse or validate Gate.
Every tested question is accompanied by its source lesson in the session.

### How the time rule works

The first hour is one pool, **not a separate free hour for every app**.
After that, grants and failures are independent. A 5-minute grant starts with 3 questions;
10 minutes with 5; 15 minutes with 7. More confirmed daily consumption and failed attempts add
questions, capped at 14. Passing requires at least 80%. Every third failed attempt creates a
15-minute cooldown for that target.

A grant expires when its active usage is exhausted **or 30 wall-clock minutes after issue**,
whichever comes first. Its displayed remaining active time is an upper bound based on the latest
iOS callback. It is not a fabricated second-by-second timer.

Daily usage charts show **confirmed minimums for the selected consumption pool**, not total
device Screen Time. Checkpoints continue up to 240 minutes. Beyond that the chart remains a
lower bound; the learning-load progression is already capped. Missing callbacks are not zero usage.

## Build and try

Requires **iOS 17.4+**, a compatible Xcode and an Apple development team with Family Controls.
The notification path does not require a beta SDK.

1. Switch to `codex/technical-spike` and pull.
2. Open `Gate.xcodeproj`; choose the shared **Gate** scheme.
3. Check automatic signing on the app and four extensions, including the new Widget target.
4. App Group on shared-state targets: `group.ch.mauruspichler.gate`.
5. Run on a **physical iPhone** for Screen Time behaviour.
6. Complete onboarding; expand categories and select individual distraction apps/domains.
7. Do **not** select Phone or WhatsApp. Gate cannot inspect opaque tokens to identify these
   apps automatically, and broad category selection is rejected in this mode.
8. Debug settings include a deliberate **2-minute test mode**. The default is still 60 minutes.
9. Add Gate's medium/large widget. Remove home-screen icons manually if desired.

Migration from 0.1 preserves the selected tokens, but stops the two legacy monitors and asks you
to set up monitoring again. Old temporary passes are not imported. No quiz learning history
existed in the spike.

### Widget limits

The widget is a list of explicit, editable links. It routes through Gate before asking iOS to
open the destination. It cannot replace SpringBoard or programmatically remove icons.
Medium shows four enabled entries; large shows up to eight. URL schemes require the relevant
app to be installed, and some apps do not offer a supported opening URL.
Phone calls are unaffected when Phone is excluded from the restriction selection.
A `tel:` link can be configured for a specific contact.

### Safety and privacy limits

The iOS adult-web filter and explicit Apple-media restrictions remain set during free and
earned time, as well as when consumption monitoring is paused.
This is **not an absolute explicit-content guarantee**: Gate cannot inspect every frame,
post or message in third-party apps. Individual Family Controls authorisation can be revoked.
Do not represent self-authorised Screen Time controls as impossible to bypass.

Shared state uses an App Group file, a cross-process lock and atomic writes. Only an armed
monitor can produce an active grant. On storage failures, existing shields are not deliberately
cleared. There is no analytics SDK, backend, account or advertising.

Text, diagrams and quiz content are bundled. Reference photos are **opt-in online loads**
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
Screen Time callbacks, real web blocking, notifications or widget launching on a physical phone.
Use the [device acceptance checklist](docs/DEVICE_TESTS.md) before merging.

## Distribution

Apple's [Family Controls distribution entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
is a separate requirement for distribution. A development provisioning warning does not mean
TestFlight/App Store approval is already granted.

## Contributing

Add chapters to `Gate/curriculum.json`; keep stable lesson/question IDs so historical learning
data survives. Each chapter needs an objective, two explanation cards, a meaningful visual,
a reflection prompt, a takeaway, a source and four fully explained questions. Run validation and
the Swift tests. Do not add remote feeds or unreviewed autogenerated lessons at runtime.
