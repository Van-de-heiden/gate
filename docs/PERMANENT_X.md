# X permanent protection

Known X/Twitter, t.co, TweetDeck and media hosts are filtered in the independent
`gate.content` ManagedSettings store. The existing automatic adult filter stays
in the default store. Budget resets, test mode, free time and lesson grants do
not clear the permanent store. No arbitrary domain containing “x” is blocked.

Apple provides opaque application tokens: the user must select X once under
More → Permanent block and save. This picker is additive, accepts individual
apps/websites, rejects categories, removes conflicting pending requests/grants,
and prevents new learning grants through `isProtected` / `isSelected`.
Gate cannot inspect the selected token to attest that it actually represents X.

Individual authorization remains revocable. Third-party mirrors/proxies and
future domains cannot be exhaustively blocked. Safari may show Apple's filter
page instead of a Gate shield. This is not an “unbypassable” device policy.

Device regression checks:
- Launch updated Gate with authorization; open x.com, twitter.com, t.co and media
  URLs during free time, after midnight, and during another app's earned grant.
- Select X in permanent protection, save, reopen X from Spotlight and its icon.
- Try to deselect X and save: it must remain protected.
- Promote an app with a live grant into permanent protection: the grant and its
  request disappear, and the shield offers a pause rather than a lesson.
- Confirm normal selected apps can still earn time and WhatsApp remains open.
- Inspect compact Home/More/Balance with Dynamic Type and VoiceOver.

Reference: https://developer.apple.com/videos/play/wwdc2022/110336/
