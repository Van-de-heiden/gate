# Gate

**Less distraction. More understanding. Free to use, modify and share.**

Gate is an open-source iPhone app that adds a learning step before additional consumption time.
Code and original lesson content are available under the [MIT licence](LICENSE).
Third-party reference photos are not relicensed under MIT.

## Status: 0.3 learning-library alpha

The first on-device spike worked. Gate now has independent app grants, a monochrome interface,
a substantially expanded curriculum and permanent in-app selections. It is **not a finished, independently validated App Store release**.

- A shared daily allowance of **60 minutes** for explicitly selected apps and websites.
- Independent **5 / 10 / 15 active-minute grants**; up to eight at once.
- Separate request, failure and cooldown state per app/domain.
- One activity ID per grant: expiration of A does not close B.
- An always-reachable request panel; a successful quiz closes its sheet.
- A medium/large **text-only launcher widget**, extendable and reorderable in the app.
- Onboarding, local learning history, confirmed usage checkpoints and settings.
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

The widget is a list of explicit links. Saved destinations can be reordered and new ones added;
they cannot be deleted, disabled or replaced from within Gate. It routes through Gate before asking iOS to
open the destination. It cannot replace SpringBoard or programmatically remove icons.
Medium shows four enabled entries; large shows up to eight. URL schemes require the relevant
app to be installed, and some apps do not offer a supported opening URL.
Phone calls are unaffected when Phone is excluded from the restriction selection.
A `tel:` link can be configured for a specific contact.

### Safety and privacy limits

The iOS adult-web filter and explicit Apple-media restrictions remain set during free and
earned time. After activation, the saved consumption selection can only be extended; the in-app
pause control is unavailable.
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
Screen Time callbacks, real web blocking, notifications or widget launching on a physical phone.
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
- Saved consumption selections are additive: deselection is retained at the persistence boundary, including v0.2 migration and onboarding re-entry. Saved launcher destinations can be reordered and extended, not deleted/disabled/replaced. The in-app pause is unavailable after activation.
- A separate permanent website selection cannot be unlocked through learning or the free allowance. Its Gate shield leads via a notification/manual app opening to a helpful pause page, without recording personal trigger answers.

### Platform boundary for website protection

The built-in automatic adult filter stays active. Apple can show its own block page before a Gate shield. `WebContentSettings` does not provide arbitrary browser redirects; this version does not claim a custom page for every automatically detected adult URL. Gate's custom shield applies to expressly selected permanent website tokens. The pause page is also always available from Today. Family Controls individual authorization remains revocable and Gate itself remains uninstallable; in-app commitment is not MDM/device supervision. See [Apple's Screen Time explanation](https://developer.apple.com/videos/play/wwdc2022/110336/).

Upgrade on the existing branch, build all five targets, and run the [0.3 physical-device checks](docs/DEVICE_TESTS.md). In particular check keyboard dismissal and permanent shielding on the actual iOS version. See [content design](docs/CONTENT.md) and [asset provenance](docs/ASSETS.md).
