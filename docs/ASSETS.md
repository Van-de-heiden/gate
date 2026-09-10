# Gate visual assets

The app icon is an original two-part open portal in ivory on charcoal. Editable source: `docs/brand/gate-icon.svg`. Installed 1024×1024 RGB asset: `Gate/Assets.xcassets/AppIcon.appiconset/GateIcon.png`. It follows the existing monochrome product language and has no typography at small icon size.

Eight conceptual editorial photographs were created using the built-in image generation tool, then packaged as 1200×800 JPEG assets for the native app. No remote image request is needed for these motifs. These are illustrative scenes, not photographs of actual historical places, actual individuals or documented events. Existing NASA source photographs remain separately credited and opt-in.

| Asset | Subject prompt |
|---|---|
| `Path-learning` | Open book, index cards, pencil and glass prism on an ivory desk; understanding an idea from several angles. |
| `Path-history` | Quiet sunlit stone archway in a library and a weathered classical sculpted head; history, philosophy and institutions. |
| `Path-business` | Craftsman's workshop, mechanical parts and workbench; useful work and industrial systems. |
| `Path-health` | Oats and berries, walking shoes, linen and a garden window; health and daily habits. |
| `Path-money` | Unbranded coin stacks, brass balance and hourglass; money, time and choices. |
| `Path-science` | Botanical greenhouse, green leaves and a glass flask with water; natural systems and curiosity. |
| `Path-digital` | Closed laptop, physical security key and face-down phone; privacy and intentional technology. |
| `Path-communication` | Two chairs, a small table and two cups in a library corner; listening and dialogue. |

Shared generation prompt: “Use case: photorealistic-natural. Asset type: full-width learning-path photograph for the Gate iPhone app. [Subject.] Style: sophisticated editorial photography, real material detail, tactile and human, warm muted ivory, charcoal and restrained natural colors. Wide landscape composition 3:2, strong single focal point, generous quiet space, softly directional daylight, no text, no lettering, no logos, no frames, no UI, no illustration, no diagram. It should feel like the opening photograph of an excellent thoughtful magazine. This is a conceptual learning-path cover, not a factual documentary record.”

The generated image motifs are supplied with the project for use under its MIT terms to the extent any rights are held. Third-party reference photographs retain their own terms. No external photograph was copied into these generated covers.


## Version 4: inline case scenes

Twenty-four additional scenes were generated on 10 September 2026 with the built-in image-generation tool, inspected individually, then packaged as 1200×800 sRGB JPEGs. The originals were retained during packaging. These illustrations are bundled offline in `Gate/Assets.xcassets/Scene-<id>.imageset/scene.jpg`. Every use has its own scene description and provenance caption in the curriculum. Two specific scenes support each of the twelve new cases; the other stages use exact native diagrams where useful. The existing eight path covers were not replaced.

The complete per-scene requests are recorded in `scripts/content/story_images.json`. Each uses this exact common prefix and suffix:

```text
Use case: illustration-story. Asset type: inline scene image inside an adult learning chapter in Gate, a refined native iPhone app. Primary request:
[scene from story_images.json]
 Style: cinematic editorial photography-inspired illustration with believable materials, natural human proportions, restrained warm color, charcoal shadows and soft directional light. Landscape 3:2. A single intelligible scene with one focal action. These are illustrative reconstructions, not documentary evidence. No text, lettering, numbers, logos, watermarks, frames, collages, UI or infographic. Make the situation engaging and concrete, not a generic course cover.
```

These are not photographs of actual individuals or documented events, and are not substitutes for the cited primary material. Their depicted apparatus is illustrative, not an authoritative reconstruction. Numbers, process labels and answer-relevant counts are rendered natively, outside generated imagery. No referenced third-party image was used as generation input for these 24 scenes.
