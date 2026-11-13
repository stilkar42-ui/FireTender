# Phase 1.8 — understanding the apprentice

The Ask Speaker field now uses a small trained neural intent classifier. Replies still come from authored knowledge and current simulation readings. The question popup stays below the elder's original seat. Long replies widen the speech bubble instead of moving him or covering the controls above.

In Phase 2, Red Hollow names the shelter and Stone Mountain’s kin names the people. The chapter adds authored answers about the elder’s return, the Torch Bearer, weather, the shelter and ash. These read the same chapter state as the workbench. The metrics below describe the earlier dialogue wording. The live tests now expect the kinship replies in place of the original population phrasing.

## Phase 1.8.1 conversation repair

The Phase 1.8 build reproduced both reported failures. The diagnostic values below come from the Godot model. Its acceptance cutoffs are 0.55 confidence, 0.22 margin over the runner-up, and 0.48 known-feature coverage.

| Question | Neural prediction | Confidence | Margin | Coverage | Original reply route |
| --- | --- | ---: | ---: | ---: | --- |
| What happened to your legs? | Injury, then apprenticeship | 0.547 | 0.306 | 87.1% | Uncertain because injury fell just short of the confidence cutoff. The reply asked for clarification. |
| How do I keep the fire alive? | Banking, then growth | 0.512 | 0.099 | 100% | Uncertain on both confidence and margin. The classifier confused tending with banking even though it knew the features. |
| Coal | Carrying, then coals | 0.705 | 0.532 | 100% | Accepted and recommended carrying the ember. The recognizable subject hid a mismatch in the requested action. |

The same model files and thresholds now feed `sim/speaker_understanding.gd`. It identifies subject words, question forms and references to the previous turn, then uses the neural prediction alongside those cues. Injury is a subject. Asking how it happened, why the elder cannot walk, and whether it will mend lead to different authored answers. He acknowledges the unrevealed cause and describes the established injury. Brief practical questions can lead to a live diagnosis when the model cannot pick a narrow topic. Cues such as banking itself, ash cover or overnight keeping help distinguish banking from general tending. Single-word coal questions describe the coal bed.

The conversation stores the reason for a practical recommendation with the recent turn. “Why?” explains that recommendation, “Show me” gives a concrete instruction based on the hearth, and “What happens if I don't?” describes a possible consequence. A new named subject can take over the conversation. An assessment compares the present flame, coals and arrangement with the previous reading and checks relevant player actions. A first assessment can establish that comparison point. Questions about duration read the coals and ash and give qualitative advice. Questions about extinction explain what to do with surviving coals or a cold bed. Familiar subjects with unanswered facts receive a specific limit. An unresolvable reference asks for clarification.

The existing neural benchmark still measures the classifier by itself. The conversation evaluation was authored separately before implementing the routing changes. It has 32 standalone questions and 15 turns across three conversations. After normalization, none of the questions appear verbatim in the model's training or development data. It checks the requested subject and purpose separately from required content in the answer. The content checks ask for both a relevant observation and a useful next action where appropriate, or a specific limit for unanswered facts. The same fixtures ran through the Phase 1.8 exported build for comparison.

| Measure | Phase 1.8 | Phase 1.8.1 |
| --- | ---: | ---: |
| Standalone replies meeting relevance checks | 9 / 32 | 32 / 32 |
| Replies within conversations meeting relevance checks | 2 / 15 | 15 / 15 |
| Expected reply topic | 21 / 47 | 47 / 47 |
| Expected request type | — | 47 / 47 |

This is a targeted, authored evaluation with response criteria expressed as expected content. Novel metaphors, questions with several topics, and references across several turns can still be misunderstood. The system generally follows the latest substantive topic. It has limited spelling tolerance for distinctive subject words and gives qualitative coal endurance estimates. The model, authored knowledge, live reads and tests all run locally inside Godot.

Reproduce the conversation comparison using the fixture, the older pack and the current project.

```powershell
godot --headless --path . --script tests/conversation_checks.gd -- --report outputs/phase181-conversation.json
godot --headless --path . --main-pack outputs/Firetender-phase18.pck --script (Resolve-Path tests/conversation_checks.gd).Path -- --baseline --report outputs/phase181-baseline.json
```

The reports include each question, actual reply, expected content and neural scores. The `--offline` test option runs the gameplay regressions without loading the separate evaluation fixture.

The sections below document the Phase 1.8 model and training baseline.

## Architecture

The network averages learned sparse features into **24 tanh hidden units**, followed by a **27-class softmax**. Features are words (weight three), adjacent word bigrams, and character 3–5-grams within word boundaries. Character features let related spellings share evidence. Bigram features retain some local word order. Both embedding and output matrices are learned with supervised cross-entropy and SGD; this replaces the previous phrase-scoring classifier. There are no pretrained language models, reply generation, Python processes, servers, paid APIs, GPU requirements, or online requests in the game.

This is a small embedding classifier inspired by [fastText's efficient classification architecture](https://aclanthology.org/E17-2068/), with a tanh hidden layer and explicit character features. It was chosen because its entire inference path is straightforward GDScript and its weights are small enough to ship. It is a domain classifier, with limited generalization outside the authored corpus.

`sim/speaker_neural.gd` normalizes at most 120 characters, extracts features, loads/checks the model once, and returns:

- `intent`: accepted topic, or an empty string when rejected.
- `raw` and `secondary`: first and second neural choices for development inspection.
- `confidence`, `margin`, and known-feature `coverage`.
- `reason`: accepted, uncertain, unfamiliar, unsupported, or model unavailable.

Confidence is a softmax score, **not a guarantee of correctness**. A development-set rejection policy requires score ≥0.55, margin ≥0.22, and feature coverage ≥0.48; the explicit unknown class is always rejected. Uncertainty prompts a clarification, unfamiliar/unsupported questions receive an honest limit. Missing or damaged weight files fail closed, leaving authored suggestions and the rest of gameplay usable. A SHA-256 checksum and dimensional check protect against mismatched model files.

Topics cover growth, weak flame, coals, excessive load, air, crowding, smoke, wet fuel, starting from an ember, felt heat, construction, fuel choice, banking, revival, placement, feeding underneath, ember carrying, next steps, improvement, recall, identity, experience, injury, apprenticeship, inherited fire, combustion, and unsupported questions. Growth and weak-flame questions share physical diagnosis code, while remaining distinct intent labels for the existing interface/tests.

## Training and evaluation

Developer tools require only Python's standard library. The shipped game requires none of it.

```powershell
py -3 tools/speaker/train.py
py -3 tools/speaker/train.py --evaluate
godot --headless --path . --script tests/neural_checks.gd
```

`tools/speaker/corpus.py` contains **624 training** and **87 development** utterances. They include informal fragments, metaphor, negation, typos, personal questions, and unsupported requests that also contain fire vocabulary. Examples are authored independently rather than produced by combining one keyword with many identical templates. Seed 1808 fixes initialization and sample order. Training runs 180 epochs and chooses the checkpoint solely by development top-1 accuracy; the selected checkpoint is epoch 30, at 93.1% development accuracy. Rejection thresholds are selected on that same development split using costs of 4 for wrong accepted intents, 5 for unsupported acceptance, and 1 for abstention. Development figures are selection figures, not independent performance estimates.

`tools/speaker/evaluation.json` is the separately authored evaluation set. It is never used by training or threshold selection. Its 116 questions include the brief's required examples and legacy anchors: **106 are absent verbatim from both training and development**, and 10 overlapping anchors are explicitly excluded from unseen metrics. Different wording remains domain related; this is a small authored prototype benchmark, not an independent human playtest.

The frozen model's results:

| Measurement | Result |
| --- | --- |
| Unseen top-1 intent accuracy before rejection | 94 / 106 = **88.7%** |
| Correct accepted answers to unseen in-scope questions | 74 / 94 = **78.7%** |
| In-scope abstentions | 16 / 94 |
| Wrong accepted in-scope intents | 4 / 94 |
| Precision among accepted in-scope intents | 74 / 78 = **94.9%** |
| Outside-knowledge rejection | 12 / 12 |
| Python / Godot inference parity | All 116 predictions, within 0.0001 confidence |

All nine required example questions reach the intended topic, including the short follow-up and the question about inserting a stick underneath. These overlap with some training anchors and are not represented as nine independent unseen successes. The report lists every prediction, score, and overlap flag in `tools/speaker/results.json`; Godot comparison, grounding checks and CPU measurements are in `outputs/speaker-evaluation.json`.

Known limitations are visible in that report. The model can mistake “carry all those logs” for ember carrying, excessive wind for excessive fuel, a cloud for a fuel load, or a collapsing cabin for general combustion. Some misspellings and indirect wording correctly cause abstention. No thresholds or training examples were changed in response to these evaluation mistakes. Future iterations should add independently written training examples and reserve a new evaluation set before making fresh generalization claims. Even with all outside questions rejected here, twelve examples do not establish universal out-of-domain detection.

## Grounding and conversational memory

`sim/speaker_advice.gd` keeps the existing fire readings authoritative: live flame, viable red charcoal, cooling, ash cover, moisture/vapor, smoke, crowding, tinder density, cold load, spatial warmth, structural weakness, insertion openings and distant nests. Neural labels never become numerical fire facts. A struggling-fire answer can combine a primary observation and action with an additional grounded problem, such as damp fuel or restricted breath. Practical language stays separate from internal units.

`sim/speaker_conversation.gd` keeps six recent substantive turns, sixteen meaningful tending actions, and twenty-four distinct retained teachings. Follow-ups compare fresh readings with the previous check and inspect actions since that turn. They can recognize a removed overload, opened space, brighter fire, deterioration, or no clear change. A relevant action alone does not prove improvement or causation. Asking twice without changing anything does not earn praise twice. Time can change the readings without a player action, and the Speaker does not attribute that to the apprentice. Repeating a question uses stored authored advice. Next-step questions use the current apprenticeship task when training is active.

`Mentor.enter` clears the temporary hearth context on experiment changes/retries. Retained teachings remain available. Asking still does not advance combustion, mark a tending action, progress a lesson, or discard queued reactive observations. Existing dialogue history retains its 32-entry bound. No simulation code or fixed-step timing was changed.

## Character knowledge and later story

`sim/speaker_knowledge.json` stores authored replies, established facts, and explicit gaps in knowledge. It records his experience, injured leg, teaching role and relation to the apprentice. Age, the full genealogy, his named teacher, the cause of the injury, and future recovery remain open story details. The `unknown` entries document those authoring boundaries.

The living Speaker's consultation and reactive speech can later be disabled with `conversation.living_available`. No death, spiritual character, or new story event has been implemented. `remembered_teaching(topic)` returns only previously retained words; it performs no neural inference or new diagnosis. `export_memory()` / `import_memory()` provide a bounded, versioned teaching-memory payload for a future story/save owner. They do not yet create a cross-session save system. Local conversation context is deliberately not restored across different hearths. This lets a later event recall something actually heard without making the remembered elder answer new questions.

## Adding content

1. Add varied independent training questions to the appropriate intent row in `corpus.py`. Include nearby confusable topics and unsupported uses of similar language. Do not move evaluation mistakes into training while continuing to call that evaluation unseen.
2. Add development questions separately. Retrain and inspect selection/rejection results. The standard-library trainer writes `sim/speaker_model/model.json` and `weights.bin` together. Commit/distribute both; the metadata contains vocabulary, ordering, dimensions, thresholds and the weight checksum.
3. For a new topic, add its examples, then add an authored grounded response in the conversation/advice layer. Update the 27-label regression assertion if intentionally changing the taxonomy. A predicted label with no knowledge or fire-answer mapping cannot create facts.
4. For character subjects, edit the knowledge JSON and keep explicit unknown facts accurate. Every new biography fact should be an intentional story decision. For physical answers, add cue-based checks to `speaker_advice.gd`, never learned numerical claims.
5. Add fresh held-out questions and contextual response tests. Run the neural, advice, apprenticeship and rendered scene suites, then the full regression list in the README. Inspect misses, rejection, response relevance, and UI fit in addition to accuracy.

## Deployment and cost

The model files total **931,573 bytes** (802,284 bytes of float32 weights and 129,289 bytes of metadata). Final source headless measurements on this machine were about 15 ms cold load, 0.42 ms median inference, roughly 1.1 ms p95, and 2.08 MB additional static allocation on first load. These are local CPU measurements on short questions, not hardware-independent promises. Inference occurs on question submission, never every combustion step or render frame.

`export_presets.cfg` explicitly includes the raw JSON and binary model files and the knowledge JSON; developer tools, datasets, tests and outputs are excluded. An exported PCK was exercised with the engine and an external smoke-test script using `--offline`, which skips Python/evaluation-data access while testing model loading, grounded replies, follow-ups, character facts, retained teachings and determinism. All runtime resources came from the PCK. No HTTP/network client or subprocess exists in the Speaker implementation; system networking was not altered. This validates the packaged runtime path, not a standalone executable installer.

Export a Windows build using Godot's normal export templates, or a data pack without templates:

```powershell
godot --headless --editor --path . --export-pack "Windows Desktop" outputs/Firetender-phase18.pck
```

The existing `PLAY.cmd` starts the updated project. **G** still asks, **H** still opens history, Enter submits typed questions, and Escape dismisses the question popup. Suggested questions bypass inference with their explicit authored topic, so that convenient path remains reliable even if a model file is unavailable.

## Regression validation

All eleven suites passed **479 standard checks**, plus fourteen screenshot-capture checks. Totals: 46 combustion, 34 apprenticeship, 24 construction, 23 tinder, 31 thermal, 30 grain, 54 existing heat/advice, 19 keeping, 24 neural, 70 scene, and 124 workbench. The full combustion suite includes the deterministic two-hour comparison; the workbench suite loads all 37 experiments and compares accelerated/headless physical states. Rendered scene checks passed at 1152×738, 1280×820, and 1600×900, including typed injury, experience, struggling-fire and follow-up replies fitting the stationary elder's layout. The separately packaged runtime smoke check is additional to those totals.
