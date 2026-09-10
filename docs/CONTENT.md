# Gate learning library, version 4

16 paths, 144 chapters, 744 explained exam tasks and 48 ungraded inline probes. Version 4 adds 12 concrete cases with four chapters and twenty exam questions each. The complete 96-chapter / 504-question version-3 library is retained unchanged in the runtime catalogue, including all original IDs, prose and optional source photographs. Existing completed chapters and memory records are not reset.

The library covers learning, reasoning, statistics, digital safety, economics, physics, the environment, history, philosophy, business, personal finance, industries, health, self-development, communication and civic institutions. This is a broad introductory curriculum, not a qualification or an independently peer-reviewed textbook. Health/finance/civics chapters teach general concepts; examples are explicitly simplified and do not make individual clinical, investment or legal recommendations.

## Learning design

Foundation chapters retain their existing structure. The new cases use individually authored sequences: a historical trace, a dialogue, a changing business problem, a numerical counterexample or a bounded everyday experiment. The reader presents one stage at a time, sometimes asking for a prediction before revealing an explanation. Every new chapter contains an inline scene or a precise visual, a practical takeaway, an optional note and a further-reading source. The 24 scene illustrations are placed inside stories, not just on covers. Source links are references and further reading; the fictional examples/questions do not reproduce source text. Generated scenes are labelled as illustrations, never historical evidence or exact scientific diagrams. Numerical figures remain native, deterministic views.

Tasks use seven formats: single-choice cases, multiple selection, ordering, matching, bounded recall, fill-in-the-blank and numerical input. Answers have authored explanations. Recall expects a specified term and accepts listed synonyms; this is not an AI essay evaluator. Long reflection notes remain ungraded. Numeric input accepts decimal comma/period and Swiss apostrophe grouping, rejects nonfinite/malformed values, and uses an explicit tolerance.

Each new session selects one concrete `topicID` before building its chapter and question lists. Broad `pathID` values such as philosophy are shelves, not topic boundaries. A 5 / 10 / 15 / 20–30-minute grant starts with up to 1 / 2 / 3 / 4 chapters from that case; progress, due items and extra question load can add context only from the same case. Unrelated due material waits for another session. Retrying a failed round keeps its case and prioritises actual failed questions, including their teaching chapters. Foundation chapters without `topicID` are each treated as a separate topic; they are never used as filler in another story.

Every exam question's chapter is taught before assessment. Voluntary chapter rounds cover that chosen chapter; voluntary due review selects one topic and uses only its due questions when available. Inline probes are stored separately, require a completed attempt before showing feedback, and carry no exam credit or failure penalty. Notes and self-explanation reveals remain ungraded. The narrator has been removed; this does not remove VoiceOver.

Short gate rounds do not mark a chapter complete until all its exam question IDs have been answered correctly across attempts and the current chapter questions in a passing session are correct. An existing mixed-topic saved round can finish once with its original answers; the reader labels this legacy state. New rounds are topic-bound. This exception avoids silently throwing away effort or a passed, not-yet-issued grant.

Repetition intervals remain 1, 3, 7, 14 and 30 days; wrong answers return sooner. This is a product heuristic. A same-day repeat does not count as another long-term strengthening step. Quiz input is saved with stable answer permutations and target-bound sessions. Reader position, quiz position, revealed stages and inline responses survive closing or relaunching. Time estimates use authored word count plus allowances for inline attempts and exam questions, not a fixed duration per chapter; they remain estimates rather than required waiting timers.

## New connected cases

| Topic | Four connected chapters |
|---|---|
| Gutenberg: one reusable text | Mainz workshop → setup versus copy cost → repeated errors → what a surviving page proves |
| Stoic response to rejection | Event versus interpretation → control and influence → responsibility → a second response |
| Socratic definition of success | Example versus definition → counterexample → necessary versus sufficient → justified revision |
| A furniture workshop's cash | Order result → peak shortfall → deposit → growth and financing |
| Compound growth | Second-year interest → net growth costs → asymmetric percentages → purchasing power |
| One chip-production chain | Lithography → aligned layers → yield → bottleneck |
| One evening and the next morning | Sleep opportunity → sleep pressure and rhythm → feeling versus performance → bounded observation |
| The moment at the front door | Specific cue → environment → fallback → honest implementation measure |
| A customer's price objection | Position and interest → packages → alternative and boundary → clear agreement |
| A bicycle repair decision | Sunk cost → forgone alternative → uncertain outcome → continuation criterion |
| A parcel alarm | Detection rate → alarms' denominator → base-rate change → error consequences |
| Remembering one explanation | Closed-book recall → explanatory feedback → later retrieval → transfer with limits |

These are scoped introductory cases, not a claim that the entire fields are covered in depth. They contain roughly 8,000 new instructional words plus separately authored questions and explanations. Finance examples explicitly state simplifications; health chapters do not diagnose the reader. The next editorial expansion should add concrete cases with their own evidence and decisions, not inflate topic labels or duplicate question paraphrases.

## Editing

`Gate/curriculum.json` is the runtime bundle, with no content-generation/network requirement. `scripts/content/` contains authored additions and `scripts/build_curriculum.py` merges them with the original lessons. Run `python3 scripts/build_curriculum.py`, then `python3 scripts/validate.py` and `swift test`. Keep IDs stable when correcting text. If adding/removing question meaning, consider existing memories and saved sessions deliberately.

The original v0.2 IDs are listed in `scripts/content/enrichment.py`. The builder preserves their original questions and attaches `.extra1`/`.extra2` additions. Sources and images have separate provenance in `docs/ASSETS.md`.

The four `story_*.py` content modules define the new cases. `story_authoring.py` supplies only data constructors, not a prose template. `story_visuals.py` contains exact authored diagrams attached to specific stages; `story_images.json` records the scene prompts. The builder is repeatable and does not generate prose or pictures at runtime. Research rationale and evaluation limits are in [LEARNING_DESIGN.md](LEARNING_DESIGN.md).
