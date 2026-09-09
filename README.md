# Gate

Gate is a free and open-source iPhone app for turning impulsive screen time into deliberate use.

The principle is simple: selected distraction apps and websites share a daily free allowance. After that allowance is spent, Gate shields them. A short learning lesson and a test earn a limited period of access; a failed test grants nothing and makes the next attempt slightly more demanding.

> The phone should remain a tool, not become the room in which the day disappears.

## Current technical spike

This repository currently proves the essential Screen Time loop:

- self-authorization through Apple's Family Controls framework;
- private selection of individual apps and websites;
- one combined daily usage threshold;
- automatic shielding through a Device Activity Monitor extension;
- a custom, text-first shield;
- a lesson and knowledge check before access is granted;
- a five-minute active-use grant, followed by automatic re-shielding;
- an always-on adult website filter and Apple's explicit-media restriction;
- an iOS 26 notification fallback and direct app opening on iOS 27 or newer.

Debug builds use a **2-minute** free allowance so the loop can be tested without ageing visibly. Release builds use **60 minutes**.

## Intended product rules

- Phone, WhatsApp and productive tools remain outside the selected distraction pool.
- YouTube in the app and on the web should both be selected if both routes are distracting.
- Only the requested app, website, or category is temporarily released.
- Unused grant time expires after 30 minutes and cannot be banked.
- Failed tests grant no access. Attempts become approximately 20% more extensive; after three consecutive failures, Gate applies a 15-minute cooldown.
- Later versions will scale lesson length with the requested access duration and the day's cumulative consumption.

## Important limitations

Gate uses Apple's privacy-preserving Screen Time APIs. It cannot inspect every image, video, message or frame displayed inside third-party apps. The adult-content controls therefore provide strong system-level web and media restrictions, but no ordinary iOS app can truthfully promise absolute content inspection while apps such as WhatsApp or YouTube remain usable.

Individual Family Controls authorization can also be revoked by the device owner. A supervised device is required for substantially stronger anti-bypass control.

## Development setup

Requirements:

- Xcode 27 project format;
- iPhone running iOS 16 or later;
- a paid Apple Developer Program team for Family Controls development signing.

The prototype uses these identifiers:

- App: `ch.mauruspichler.gate`
- App Group: `group.ch.mauruspichler.gate`
- Extensions: `ch.mauruspichler.gate.monitor`, `ch.mauruspichler.gate.shieldconfiguration`, and `ch.mauruspichler.gate.shieldaction`

Forks should replace the bundle IDs and App Group consistently in the Xcode project, all entitlement files, and the Swift constants.

On the first physical-device run:

1. Approve the Family Controls request.
2. Approve notifications; iOS 26 uses one to lead back to Gate from a shield.
3. Select individual distraction apps and websites. Do not select Phone or WhatsApp.
4. Start the daily gate.
5. In Debug, use a selected app for two active minutes and verify that the shield appears.
6. Press the shield's primary button, open Gate through the notification, pass the lesson, and verify the five-minute grant.

Family Controls distribution requires Apple's separate approval for the app and its extensions. Local development on a registered device is the first milestone.

## Privacy

The spike has no account, analytics, advertising, server, or network backend. Selection tokens and gate state stay in the shared App Group container on the device.

## License

Gate is released under the [MIT License](LICENSE). You may use, modify, distribute, and build upon the code, including commercially, provided the copyright and license notice remain included.
