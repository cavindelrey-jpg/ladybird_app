# Academia — Course Content Generation Rules

Derived from the manually-built "Theory of Relativity" reference course. Any AI/agent generating course content must follow these rules exactly. This is not a style preference — courses that violate these rules are considered broken output and must be regenerated.

---

## 1. Math & Equations — LaTeX only, never caret notation

**Rule:** All mathematical expressions must be rendered through a proper math renderer (KaTeX or MathJax) using LaTeX syntax. Plain text approximations like `E = mc^2`, `f(x)`, `sqrt(1 - v^2/c^2)` are forbidden anywhere in course body content.

- Inline math: `$E = mc^2$` → renders as a real superscript, not a caret.
- Display math (equations that deserve their own line, like derivations or named formulas): use block LaTeX, e.g.
  ```
  $$\Delta t = \dfrac{\Delta t_0}{\sqrt{1 - \dfrac{v^2}{c^2}}}$$
  ```
- Superscripts/subscripts (Δt₀, x², v²/c²) must use LaTeX `^{}` and `_{}` — never Unicode superscript characters typed manually, never `^2` left as raw text in body copy.
- Square roots, fractions, and Greek letters (Δ, θ, π …) must be real LaTeX commands (`\sqrt{}`, `\dfrac{}{}`, `\Delta`, `\theta`), not spelled out or approximated with `/` and `^`.
- If a formula is *also* shown inside a downloaded diagram/infographic (see Rule 3), the surrounding body text must **still** restate it in proper LaTeX — the image is a visual aid, not a substitute for machine-readable math.

**Why:** the reference course's biggest formula (`E = mc²`) only looks right because it's a static image. Every other course won't have a bespoke image for every equation — the renderer must handle it natively.

---

## 2. Lists — use the live list component, never manual numbering

**Rule:** Ordered lists must be generated using the app's actual ordered-list/list widget (auto-incrementing), not by typing `1.`, `2.`, `3.` as literal characters inside a paragraph or bullet string.

- Bad: a string field containing `"1. Measurements of time dilation..."`.
- Good: a `List` block with `type: ordered` and items `["Measurements of time dilation...", "Observation of the bending of starlight...", ...]`, numbered by the renderer.
- Same applies to bullet lists (•) — use `type: unordered`, not a manually prefixed bullet character.
- Numbering must survive edits: if an item is inserted or deleted, the renderer re-numbers automatically. This is impossible with hardcoded number strings and is the actual reason this rule exists.
- Nested lists (e.g. sub-points under "Applications") must use nested list blocks, not indentation via spaces/tabs in plain text.

---

## 3. Images — every course must be visually illustrated, sourced automatically

**Rule:** Every major section (Introduction, and each H2-level topic that describes a visual, spatial, or physical phenomenon) gets at least one relevant image, auto-fetched from open-source/stock sources (the pipeline already supports this — it must actually be invoked per section, not left for the Upload tab).

- **Hero image**: one strong image directly under the title/breadcrumb block, representative of the whole topic (e.g. the gravitational-lensing diagram used at the top of the Relativity course).
- **Section images**: each concept that benefits from a visual (time dilation, spacetime curvature, black holes, gravitational waves, a historical figure) gets its own image placed immediately after the paragraph that introduces it — not batched at the end, not left as a single image for the whole course.
- **Diagram preference over generic stock**: prefer labeled diagrams/infographics (axes, arrows, annotations) over decorative photography when explaining a mechanism (e.g. the annotated `E = mc²` infographic, the twin-clock time-dilation diagram). Portraits/photos are acceptable for people, places, or historical context (e.g. the Einstein portrait).
- **No copyrighted or watermarked material** — only openly licensed/stock sources, consistent with existing sourcing rules.
- **No placeholder or fabricated images** — if no suitable image is found for a section, skip the image rather than inserting a generic filler graphic. (Consistent with Academia's "no fake data" principle — this extends to "no fake/irrelevant images.")
- Each image should sit full-width within the content column, not floated or cropped awkwardly, matching the reference course's layout.
- **Minimum of 3 images per lesson, deliberately placed**: one shortly after the opening/introduction, at least one inside the body next to the specific concept it illustrates, and one before the closing/conclusion. Use more than 3 whenever the lesson genuinely covers that many distinct visual concepts (several objects, steps, places, or diagrams), especially in content-dense sections like key-facts lists. One image for an entire lesson is not acceptable output.
- **Relevance over convenience**: an image must depict the actual thing its surrounding paragraph is about. The search query behind it must be specific and drawn from that paragraph's real content (e.g. "Nok terracotta figure Nigeria archaeology", not just the lesson's title reused for every image in it). A lesson-title-only query, repeated for every image slot in that lesson, is not specific enough on its own and must not be the only sourcing strategy. If the best available match is still a poor fit, skip the image rather than keep one that doesn't match — reusing the existing "no fake/irrelevant images" standard above.

---

## 4. Section structure — consistent scaffolding

Every generated course should follow this skeleton, matching the reference:

1. **Hero image**
2. **Breadcrumb** (Subject > Discipline > Level > Topic)
3. **Tag chips** (subject, difficulty, estimated read time, curriculum tag e.g. "GCE A-Level")
4. **Title**
5. **One-paragraph summary** (2–4 sentences, same text that appears under the title and is reused as the Introduction's opening)
6. **Author card** (name, avatar, learner count, star rating)
7. **INTRODUCTION** (bold all-caps section header) — context + why the topic matters
8. **HISTORICAL BACKGROUND** (if applicable) — origin, key people, prior state of knowledge
9. **Core concept sections**, one H2 per major sub-topic, each with its own image where relevant (e.g. SPECIAL RELATIVITY, GENERAL RELATIVITY, SPACETIME, EFFECTS OF GENERAL RELATIVITY)
10. **EXPERIMENTAL EVIDENCE / KEY FACTS TO REMEMBER** — dense, scannable facts as bolded label + value pairs (`**Scientist**: Albert Einstein`), not paragraphs
11. **IMPORTANCE / APPLICATIONS** — bulleted list (live list component) of real-world uses
12. **CONCLUSION** — 2 short paragraphs synthesizing the topic
13. **Engagement bar** (like, save, share) + **Comments** section

Section headers are bold, ALL CAPS, no numbering prefix (e.g. `INTRODUCTION`, not `1. Introduction`).

**Subheadings inside a lesson are mandatory, not optional.** A single H2 lesson must be broken into named H3 subheadings for its distinct parts (definitions, causes, examples, a named process) rather than left as one continuous run of paragraphs under just the lesson title. A lesson with no internal subheadings, regardless of length, is incomplete output.

---

## 5. Tone and density

- Prose paragraphs: 3–5 sentences, plain declarative language appropriate for GCE/BAC-level students — no unexplained jargon.
- "Key Facts" sections use `**Bold label**: value` pairs, not full sentences.
- Keep each section self-contained enough to be read out of order — students will jump around, not read linearly.
- **Real length, not a single paragraph.** A lesson should be substantive enough to actually teach its sub-topic: several distinct paragraphs across multiple subheadings, each idea given its own paragraph rather than crammed together. Separate every paragraph with a blank line in the source so it renders as its own visually distinct block, not a wall of text.
- **No em dashes.** Never use `—` anywhere in generated content. Use a period, comma, colon, or parentheses instead.
- **Definitions stay tight.** When a term is introduced and defined, the core definition itself (not the surrounding sentence) must land in 5-7 words. Extra context, examples, or nuance belong in a following sentence, not folded into the definition itself.

---

## 6. Thumbnails — mandatory, separate from in-body images

**Rule:** Every lesson must have a thumbnail image, in addition to whatever hero/section images appear inside the lesson body. The thumbnail is what represents the lesson in lists, grids, and cards (Library, search results, "Continue Learning," etc.) — it is not optional and it is not the same field as the hero image, even if the same picture is reused for both.

- Thumbnail is auto-fetched from the same open-source/stock pipeline as body images (Rule 3) — no manual upload requirement, no placeholder/default icon standing in for it.
- If generation runs and no suitable image is found, the lesson is not considered complete — flag it for a retry rather than shipping with a blank or generic placeholder thumbnail.

---

## 7. Heavy-math subjects — pulled out of this pipeline for now

**Rule:** This note-generation pipeline is systematically **excluded** from subjects that are primarily problem-solving rather than explanatory prose. For now, do not run auto-generation on:

- Mathematics
- Further Mathematics
- Additional Mathematics
- Physics
- Computer Science / Coding

**Why:** these subjects live and die on worked examples, step-by-step derivations, and solved problems — a fundamentally different note-making methodology from the prose-plus-diagram format this pipeline produces (as seen in the Relativity example, which is itself borderline — it's explanatory Physics, not problem-solving Physics). Trying to force worked-example content through this pipeline is what produces broken math rendering and other failures.

A separate methodology and separate route will be built specifically for these subjects later, built around solved problems, stepwise working, and heavier LaTeX use than prose subjects need. Until that route exists, this pipeline should either skip these subjects entirely or explicitly reject/flag any generation request tagged with one of them.

---

## 8. Curriculum-driven generation — systematic coverage from the GCE syllabus folder

**Rule:** A folder containing the full GCE curriculum (by subject, topic, and subtopic) will be provided. Generation is not ad hoc or prompted topic-by-topic by a human — the system must:

1. Ingest the curriculum folder and build a structured list of every subject → topic → subtopic.
2. Walk that list systematically, generating one course/lesson per subtopic, in curriculum order.
3. Skip any subject currently excluded under Rule 7, but still record it in the coverage list as "pending — heavy-math route" rather than silently omitting it.
4. Track completion state (generated / pending / needs-review) per subtopic so re-runs don't duplicate work already done, and gaps in coverage are visible at a glance.
5. Apply every rule above (1–6) to each generated subtopic — no exceptions for length or subject just because generation is automated/bulk rather than one-off.
6. **The syllabus is a scaffold, not a script.** It decides which topics exist, how they're grouped, and what order they're taught in — nothing more. Generated notes must read as if no exam syllabus exists at all: never name "GCE" (or any exam board) in body prose, never write "this is examinable under...", "as required by the syllabus...", "per the curriculum...", or similar framing. A student reading a lesson should experience it as a topic worth understanding on its own terms, not as syllabus content being delivered at them. The app's own structured taxonomy fields (`level`, `examBoard`, per Rule 4's breadcrumb) may still carry "GCE Advanced Level" etc., since that's navigation metadata the student browses by, not narrative text they read.

---

## Summary of the failure modes to fix

| Symptom in broken output | Rule that fixes it |
|---|---|
| Math shown as `E=mc^2`, `sqrt(1-v^2/c^2)` | Rule 1 — real LaTeX via KaTeX/MathJax, inline and block |
| Numbered lists typed as `"1. ..."` text strings | Rule 2 — live ordered-list component, auto-numbered |
| Missing or generic images per section | Rule 3 — auto-fetch a relevant open-source image per major section, diagrams preferred for mechanisms |
| Lessons with no thumbnail / generic placeholder in lists | Rule 6 — mandatory auto-fetched thumbnail per lesson, separate field from body images |
| Broken/garbled output on Maths, Further Maths, Add Maths, Physics, CS | Rule 7 — excluded from this pipeline until a dedicated worked-example route exists |
| Ad hoc, incomplete, or duplicated topic coverage | Rule 8 — systematic walk through the GCE curriculum folder with tracked completion state |
| Em dashes, run-on multi-clause "definitions" | Rule 5 — no em dashes; every definition's core statement stays 5-7 words |
| Notes that read like exam-syllabus copy ("examinable under GCE...") | Rule 8.6 — syllabus is an invisible scaffold, never named in body prose |
| One lesson, one generic image, unrelated to the actual text | Rule 3 — minimum 3 images per lesson, placed deliberately, queried from the actual surrounding content |
| A lesson with no internal structure, one flat wall of text | Rule 4 — mandatory H3 subheadings inside every lesson; Rule 5 — real multi-paragraph length |
