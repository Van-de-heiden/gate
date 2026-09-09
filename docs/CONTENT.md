# Gate learning library, version 3

16 paths, 96 chapters, 504 explained tasks. All 24 original chapter IDs, their four original questions each, prose and source photographs remain. Each original chapter receives a practical paragraph, a small real-world mission and two additional tasks. Eight new paths and three additional chapters per original path are authored in German, including Swiss numeric examples.

The library covers learning, reasoning, statistics, digital safety, economics, physics, the environment, history, philosophy, business, personal finance, industries, health, self-development, communication and civic institutions. This is a broad introductory curriculum, not a qualification or an independently peer-reviewed textbook. Health/finance/civics chapters teach general concepts; examples are explicitly simplified and do not make individual clinical, investment or legal recommendations.

## Learning design

Each chapter includes a learning objective, explanation, worked everyday case, a limitation, vocabulary, a visual, an optional reflection, a practical mission, a takeaway and a further-reading source. Source links are references and further reading; the authored examples/questions do not reproduce source text. Conceptual generated images are labelled as illustrations, never historical evidence or exact scientific diagrams. Numerical figures remain native, deterministic views.

Tasks use seven formats: single-choice cases, multiple selection, ordering, matching, bounded recall, fill-in-the-blank and numerical input. Answers have authored explanations. Recall expects a specified term and accepts listed synonyms; this is not an AI essay evaluator. Long reflection notes remain ungraded. Numeric input accepts decimal comma/period and Swiss apostrophe grouping, rejects nonfinite/malformed values, and uses an explicit tolerance.

Gate sessions vary by path, mix due retrieval, prioritise gaps and diversify formats. Each question's chapter is taught before assessment. Voluntary chapter rounds cover that chosen chapter; voluntary review uses due questions only when available. Short gate rounds do not mark a new chapter complete until all its question IDs have been answered correctly across attempts and the current chapter questions in a passing session are correct. Older completed IDs are retained.

Repetition intervals remain 1, 3, 7, 14 and 30 days; wrong answers return sooner. This is a product heuristic. A same-day repeat does not count as another long-term strengthening step. Quiz input is saved with stable answer permutations and target-bound sessions.

## Editing

`Gate/curriculum.json` is the runtime bundle, with no content-generation/network requirement. `scripts/content/` contains authored additions and `scripts/build_curriculum.py` merges them with the original lessons. Run `python3 scripts/build_curriculum.py`, then `python3 scripts/validate.py` and `swift test`. Keep IDs stable when correcting text. If adding/removing question meaning, consider existing memories and saved sessions deliberately.

The original v0.2 IDs are listed in `scripts/content/enrichment.py`. The builder preserves their original questions and attaches `.extra1`/`.extra2` additions. Sources and images have separate provenance in `docs/ASSETS.md`.
