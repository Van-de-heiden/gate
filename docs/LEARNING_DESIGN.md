# Gate: one question worth following

Design decision, 10 September 2026. This is a research-informed product design, not a clinical claim or a validated personalised learning intervention. The goal is useful understanding that leaves the app with the learner, not longer sessions or more earned consumption.

## Evidence reviewed before implementation

The [US Institute of Education Sciences practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1) supports retrieval quizzes and deep explanatory questions, as well as spacing, combining explanatory graphics with verbal descriptions, connecting concrete and abstract representations, and alternating worked examples with problem solving. Its evidence ratings differ: for example, the guide rates retrieval and explanatory questioning more strongly than pre-questions. It does not establish one universal lesson layout, a perfect repetition interval, or the effectiveness of Gate.

[Gruber, Gelman and Ranganath (2014)](https://pubmed.ncbi.nlm.nih.gov/25284006/) found better memory in a laboratory trivia task during high-curiosity states, including a delayed test. That supports exploring meaningful unanswered questions as openings. It does **not** prove that these particular stories will engage this user, that every cliffhanger improves learning, or that a mobile learning gate reduces screen time.

Our implementation choices below are inferences from those findings combined with the user's explicit preference for one topic at a time. We do not infer a diagnosis, a fixed “visual learner” type or a scientifically optimal individual method from that preference.

## Translate principles into a usable round

| Need | Gate implementation | Boundary |
|---|---|---|
| A reason to care | A concrete unresolved case: a profitable order but an empty account, a seemingly reliable alarm with many false positives | Relevance is authored; no endless cliffhanger or engagement feed |
| Coherent first understanding | Select a concrete topic before selecting chapters and questions | “Philosophy” alone is not a topic; two philosophy cases must not mix |
| Participation while learning | Predictions, decisions, self-explanation reveals, calculations and dialogue | Inline mistakes carry no unlock penalty; the final exam is separate |
| Inspect a relationship | Exact native bars, comparisons and process diagrams next to the explanation | AI scene illustrations supply context, never exact data or historical proof |
| Recall, not only recognition | Seven authored formats, including bounded text recall and numerical input | Free prose is not graded by keyword guessing; personal notes are ungraded |
| Useful feedback | Explain the model and the wrong assumption; prioritise actual errors in a retry | Retry material stays in the same case; no surprise unrelated chapters |
| Return later | Topic-bound due rounds and the existing spaced-repetition heuristic | 1/3/7/14/30 days is a practical rule, not a universal optimum |
| Use outside the app | A bounded decision, observation or transfer question | No claim that a passed quiz alone changes real-world behaviour |

Coherence within a case does not mean rejecting all interleaving. Worked examples and decisions alternate within a case; different topics vary between rounds. The new selection rule addresses abrupt subject changes, not a blanket scientific argument against mixed practice.

## Authoring choices

Twelve new cases contain four chapters each. Their staging differs deliberately: the print workshop follows an object and its consequences; the Socratic case revises a definition through dialogue; the cash case changes payment timing in one business; the alarm case changes a denominator; the habit case changes one recurring moment. A chapter's cards can begin with a scene, a question, a calculation or a decision. There is no required “theory, everyday example, vocabulary” prose template for these cases.

The images are local, enlargeable and captioned as synthetic illustrative scenes. Historically specific scenes are not purported photographs. Exact visualisations use values and labels from the authored data; generated imagery never supplies an answer that depends on counting depicted objects. Original covers remain as broad shelf identities.

Medical and financial content stays at the level of general concepts with explicit model assumptions. The sources are further reading, not endorsements. The if-then case links the original Gollwitzer–Sheeran implementation-intentions review as further reading; its publisher full text was not accessible during this revision, so no numerical effect-size claim is made from it. Clinical topics link NIH material; business and quantitative cases link the relevant OpenStax explanations; historical and philosophical cases distinguish primary texts/objects from our fictional scenarios.

## Scope and persistence

- The entire earlier 96-chapter library remains; new totals are 144 chapters, 744 exam questions, 48 ungraded probes and 24 additional scene images.
- Short rounds begin with less of one case; longer rounds deepen it. When the last chapters remain, a longer round retains earlier context instead of jumping elsewhere.
- Duration estimates use word count and task allowances. They are not a clock-based proof of learning and do not force pointless waiting.
- Notes, answers, stable option permutations, reader and quiz positions, and reveal states persist locally.
- An already saved legacy mixed-topic round is labelled and preserved until finished. New sessions are topic-bound. No progress file is deleted or reset.
- The daily free consumption budget remains 30 minutes. This learning redesign does not change monitor permissions, report privacy, shield limitations or the independent target-grant architecture.
- Remove synthetic narration as requested; retain native accessibility and visible keyboard dismissal.

## How to evaluate honestly

Automated tests establish topic boundaries, question coverage, grading separation, legacy decode and persistence. They cannot establish motivation or learning effectiveness.

On the actual phone, first try the Gutenberg and cash cases without narration. After a pause, explain their central distinction without looking. The next day, try a changed numerical or everyday example. Note where you lost the thread, where an image explained nothing, and where a question was answerable through an obviously silly distractor. That editorial feedback is more useful than claiming a learning-science certification.

The practical success criteria are: the story stays understandable through four chapters; you can explain and apply the central mechanism later; interruptions do not lose work; and Gate supports the user's lower screen-time goal without turning learning into an endless attention feed. A controlled learning or screen-time outcome study has not been run.
