# A continuous home landscape

The existing tree, hills, clouds, sun and moon now fill Today edge to edge.
Foreground content scrolls over a stationary backdrop; a continuous ground mist
keeps the launcher and other lower controls readable without separate cards.
The compact allowance dial sits directly in the sky. One greeting replaces the
three introductory texts. Measurement detail is available from the info button;
missing authorization/monitoring and exhausted time remain visible.

Morning 05–09, daytime 09–17, evening 17–21, night 21–05 follow the existing
local-calendar policy. These are visual time bands, not astronomical sunrise or
weather claims. The existing minute schedule updates the phase. The former
15-fps landscape timer is removed; only phase changes crossfade, and Reduce Motion
disables that transition. Reduced transparency/increased contrast add a stronger
reading veil. The landscape is decorative and cannot intercept controls.

The daily allowance, timestamp semantics, grants, restrictions and curriculum
are unchanged. The label retains its upper-bound sign. All learning paths,
including the greenhouse-effect chapter, use exactly the existing material.

`scripts/preview_home.py` renders morning/day/evening/night and large-type previews
on the CI iPhone simulator using the shared shipping SwiftUI components. This
isolated preview app does not authorize Screen Time or access Gate's app group.
These images validate appearance; they do not prove native grant/launcher flows.

On-device acceptance:
- Open Today at normal and large text sizes; scroll through every launcher entry.
- Open and close the allowance info sheet; missing monitor permission remains
  visible without opening the sheet. Pause remains reachable in the header.
- Verify a pending request and an active grant are both reachable and operate
  independently, including test-mode recovery.
- Check all four phase previews and reopen across a time-band boundary; the native
  tab bar remains visible and screen content avoids its hit area.
- Check VoiceOver reading order, Reduce Motion, Increase Contrast and Reduce
  Transparency. The same static scene is used in Low Power Mode.

API reference: https://developer.apple.com/documentation/swiftui/timelineview
