---
name: disability-testing
description: Evaluate products through the lived experience of specific disability types — low vision, blindness, color blindness, motor impairments, Deaf/HoH, dyslexia, ADHD, anxiety, autism, cognitive disabilities, and epilepsy/vestibular. Produces per-disability findings with simulation techniques, AT behavior notes, and specific fixes. Trigger on phrases like disability testing, simulate blindness, low vision audit, dyslexia testing, ADHD design review, anxiety-friendly design, autism accessibility, motor impairment testing, deaf UX, color blind test, vestibular testing, epilepsy safe design, how does this work for someone with X, or any request to evaluate a product through the lens of a specific disability. Always use this skill for disability-specific UX evaluation.
---

# Disability-Specific UX Testing

Evaluate products through the lived experience of specific disability types. WCAG criteria define the floor — this skill goes further, into how real people with real disabilities actually experience design decisions. Compliance and usability are not the same thing.

---

## How to Use This Skill

**Single disability mode:** "Run a low vision audit on this design"
**Multi-disability mode:** "Run all disability profiles on this prototype"
**Simulation guide mode:** "How do I test this with Trembling Trevor in Funkify?"
**Full disability sweep:** No profile specified — run all applicable profiles

For each disability profile, the skill produces:
- How this user experiences the product
- Specific friction points and failure modes
- Simulation technique (tool, method, or persona)
- Design fixes with WCAG criterion reference where applicable
- Real AT behavior notes where relevant

---

## Disability Profiles

---

### Profile 1: Low Vision

**Who this is:**
Users who have partial sight that cannot be fully corrected with glasses or contacts. Includes macular degeneration (central vision loss), glaucoma (peripheral vision loss), cataracts (diffuse blur), and diabetic retinopathy. Not the same as blindness — these users see, but imperfectly.

**How they experience digital products:**
- Rely on browser zoom (200–400%) and OS-level text scaling
- May use screen magnification software (ZoomText, macOS Zoom, Windows Magnifier)
- Need high contrast — low contrast text disappears or blurs together
- Lose context when zoomed in — can't see the full page at once
- Struggle with light-weight typefaces (100, 200, 300 weight)
- Lose track of cursor/focus position during magnification

**What breaks first:**
- Text under 16px — especially placeholders, labels, helper text
- Low contrast text (#999 on white, gray-on-gray)
- Layouts that break or truncate content at 200–400% zoom
- Horizontal scrolling required at high zoom
- Focus indicators too small to locate when magnified
- Content that relies on spatial relationships invisible in a magnified view

**Simulation techniques:**
- **Funkify (Chrome extension):** Visual persona blurs and warps content — simulates presbyopia and low vision
- **Browser zoom:** Test 200%, 300%, 400% — does content reflow? Is anything cut off?
- **Windows High Contrast Mode / macOS Increase Contrast:** Reveals color-dependent UI failures
- **Squint test:** Squint at the screen — if you lose hierarchy, contrast has failed
- **Colour Contrast Analyser (desktop app):** Test every text/background combination

**Design fixes:**
- Minimum 16px body text, 18–20px preferred — use relative units (rem/em)
- Font weight minimum 400 for body — never thin weights for readable content
- Target 4.5:1 contrast minimum; aim for 7:1 for critical content
- Use Atkinson Hyperlegible or Hyperlegible Sans for legibility-critical contexts
- Ensure reflow at 320px / 400% zoom (WCAG 1.4.10)
- Never rely on spatial position alone for instructions ("click the box on the right")
- Make focus indicators large enough to locate when magnified — minimum 3px solid outline

**WCAG criteria:** 1.4.3, 1.4.4, 1.4.6, 1.4.10, 1.4.11, 1.4.12, 2.4.11

---

### Profile 2: Blindness / Screen Reader Users

**Who this is:**
Users who are legally blind or fully blind and rely on screen readers (NVDA, JAWS, VoiceOver, TalkBack) to access digital content. They experience the product as a linear audio stream — the DOM order is their reality.

**How they experience digital products:**
- Navigate by headings, landmarks, links, and form controls — not visually
- Hear the entire accessible name of every element as it receives focus
- Skip navigation uses header structure (H1, H2, H3) to scan for content
- Experience button labels, link text, and ARIA names as the interface itself
- Cannot infer context from visual layout, color, or proximity
- Encounter content in DOM order — visual position is irrelevant

**What breaks first:**
- Icon buttons with no accessible name (an unlabeled share icon is just silence)
- Images with missing, wrong, or over-descriptive alt text
- Complex tables with no header associations
- Modals that don't manage focus — screen reader stays on the page behind
- Dynamic content updates that aren't announced (form errors, cart additions, live updates)
- Positive tabindex values that create a chaotic focus order
- Placeholder text as the only label — it disappears on input and isn't always read
- Click events on non-interactive elements (div/span instead of button)
- "Click here" and "Read more" links — indistinguishable in the links list

**Simulation techniques:**
- **NVDA + Chrome (Windows):** Most important combination — most common real-world AT
- **VoiceOver + Safari (macOS/iOS):** Critical for Apple ecosystem products
- **TalkBack + Chrome (Android):** Mobile screen reader testing
- **Screen reader only mode:** Close eyes, navigate with keyboard only — do not look at screen
- **Headings map (WAVE or axe):** Reveals what the heading structure actually is
- **Links list:** In NVDA press Insert+F7 — see all link text in isolation. Is each one meaningful?

**Testing protocols:**
1. Navigate the page using only headings (H key in NVDA/VoiceOver)
2. Navigate using landmarks (D key in NVDA)
3. Complete the primary task using Tab only — no mouse
4. Submit a form and hear the error messages
5. Trigger a modal/dialog — does focus move in and trap correctly?
6. Hear every image alt text — is it meaningful in context?

**Design fixes:**
- All interactive elements are native HTML (`<button>`, `<a>`, `<input>`) or have correct ARIA roles
- Every icon button has `aria-label` describing the action
- All images have meaningful `alt` — decorative images have `alt=""`
- Focus moves to modal on open; returns to trigger on close
- All dynamic updates use `aria-live` or `role="alert"` appropriately
- Links describe destination or action — never "click here"
- DOM order matches visual reading order

**WCAG criteria:** 1.1.1, 1.3.1, 1.3.2, 2.1.1, 2.4.1, 2.4.3, 2.4.4, 4.1.2, 4.1.3

---

### Profile 3: Color Blindness

**Who this is:**
Users with color vision deficiency — most commonly deuteranopia (red-green, most common in men at ~8%), protanopia (red-green), tritanopia (blue-yellow, rare). Color blindness doesn't mean seeing in grayscale — it means certain color distinctions are invisible.

**How they experience digital products:**
- Red and green look similar or identical
- Status indicators using only red (error) and green (success) are indistinguishable
- Charts using only color to differentiate data series are unreadable
- Links that differ from body text only by color may be undetectable

**Simulation techniques:**
- **Funkify (Chrome extension):** Color blindness simulators for all types
- **Chrome DevTools → Rendering → Emulate vision deficiencies:** Built into Chrome — no extension needed. Covers deuteranopia, protanopia, tritanopia, achromatopsia
- **Colour Blindness Simulator (Coblis):** Upload screenshots for simulation
- **Grayscale test:** Convert to grayscale — can you still tell what everything means?

**Design fixes:**
- Never use color as the only differentiator — always pair with icon, pattern, or text label
- Form errors: red border + error icon + error text (not just red border)
- Charts: labels directly on data, patterns in fills, or textures — not color only
- Links: underline or border-bottom in addition to color
- Status badges: include text ("Error," "Success," "Warning") not just color

**WCAG criteria:** 1.4.1

---

### Profile 4: Motor Impairments / Limited Dexterity

**Who this is:**
Users with conditions affecting motor control — arthritis, Parkinson's disease, cerebral palsy, spinal cord injuries, repetitive strain injury (RSI), limb difference, and tremors. May use keyboards, switch access, head pointers, eye tracking, or mouth sticks instead of a mouse.

**How they experience digital products:**
- Precise mouse clicks are difficult or impossible
- Drag interactions are frequently inaccessible
- Small touch targets require multiple attempts
- Fast-moving UI, carousels, and timeouts cause task failure
- Keyboard-only use must be complete — no mouse-required interactions

**Simulation techniques:**
- **Funkify "Trembling Trevor" persona:** Simulates tremor — makes mouse pointer harder to control. Reveals which touch targets are too small or too close
- **Keyboard-only testing:** Unplug mouse — can you complete every task?
- **One hand testing:** Use keyboard with one hand — reveals keyboard shortcut burdens
- **Switch access simulation:** Tab-only navigation (no mouse, no arrow keys beyond standard)
- **Sticky keys + slow motion:** OS accessibility → Slow Keys slows keyboard repeat

**Design fixes:**
- Touch targets minimum 44×44px; prefer 56×72px for primary actions
- Minimum 8px spacing between adjacent targets
- All interactions achievable via keyboard without mouse
- No drag-only interactions — provide button alternatives (up/down arrows for sort)
- No timed interactions without extension options
- Hover-to-reveal content has keyboard equivalent (focus-to-reveal)
- Double-click and long-press actions have alternatives
- Form auto-save and resume — don't lose progress on timeout

**WCAG criteria:** 2.1.1, 2.1.2, 2.5.1, 2.5.2, 2.5.4, 2.5.7, 2.5.8

---

### Profile 5: Deaf / Hard of Hearing

**Who this is:**
Users who are Deaf (capital D — culturally Deaf, often prefer sign language), hard of hearing, or deafened. For many Deaf users, English is a second language — signed language is primary. This has implications for reading level and content comprehension beyond just captioning.

**How they experience digital products:**
- Cannot access audio content without captions or transcripts
- Audio alerts (notification sounds, error beeps) are inaudible
- For some Deaf users, complex written English is less accessible than plain language (sign language has different grammar)
- Video content without captions is entirely inaccessible

**Simulation techniques:**
- **Mute device completely:** Navigate the product — does anything break? Are there audio-only cues?
- **Video without captions:** Watch your own product's video without looking at the visuals — is there important information only communicated by audio?
- **Plain language check:** Would someone for whom English is a second language understand this copy?

**Design fixes:**
- Captions on all video — accurate, synchronized, with speaker identification
- Transcript for all audio content
- Never use audio-only alerts — always pair with visual feedback
- Plain language throughout — target Grade 8 reading level (WCAG AAA 3.1.5)
- Sign language interpretation for critical public-facing video content (WCAG AAA 1.2.6)

**WCAG criteria:** 1.2.1, 1.2.2, 1.2.4, 1.2.6

---

### Profile 6: Dyslexia

**Who this is:**
Users with dyslexia experience difficulties with reading fluency, decoding, and spelling. Letters may appear to shift, reverse, or blur together. Dense text, justified alignment, and decorative fonts increase difficulty significantly.

**How they experience digital products:**
- Long unbroken paragraphs are very hard to parse
- Fully justified text creates "rivers" of white space that make tracking difficult
- Decorative, condensed, or italic fonts increase letter confusion
- Similar-looking letters (b/d, p/q, il1) cause reading errors
- High word density and low whitespace increase cognitive load
- Reading progress is lost when tracking from line end to next line start

**Simulation techniques:**
- **Funkify Dyslexia Simulator:** Scrambles and "dances" text on screen — shows the frustration of text instability
- **Remove all CSS:** Does the content structure still support reading without visual design?
- **Text to speech:** Use OS read-aloud or browser extension — does the content make sense when read linearly?

**Design fixes:**
- Use Atkinson Hyperlegible, Hyperlegible Sans, or OpenDyslexic for body text where legibility is critical
- Never use italic for body content — reserve for occasional emphasis only
- Left-align all body text — never full justify
- Line length 50–75 characters maximum
- Line height minimum 1.5× font size
- Generous paragraph spacing
- Short paragraphs — 3–5 sentences maximum
- Avoid ALL CAPS except for very short labels
- Break content into sections with clear headings
- Use bullet lists for sequential or enumerated content

**WCAG criteria:** 1.4.8 (AAA), 3.1.3 (AAA), 3.1.5 (AAA) — note: WCAG does not specifically address dyslexia at AA. Best practice exceeds WCAG here.

---

### Profile 7: ADHD

**Who this is:**
Users with Attention Deficit Hyperactivity Disorder experience difficulty sustaining attention, filtering distractions, managing impulsivity, and organizing multi-step tasks. ADHD presents differently in different people — hyperactive, inattentive, or combined types.

**How they experience digital products:**
- Animated banners, auto-playing videos, and moving elements compete with the primary task
- Long forms feel overwhelming and lead to abandonment mid-flow
- Multiple CTAs on a single screen create decision paralysis
- Notifications and badges pull attention away from current task
- Progress loss from session timeouts is catastrophic
- Error messages that don't explain what to do next cause abandonment

**Simulation techniques:**
- **Funkify Cognition Simulator:** Slows and fragments interactions — simulates cognitive load and attention difficulties
- **Distraction audit:** Count every moving, blinking, or animated element visible simultaneously
- **Task completion timing:** How many steps to complete the core task? Anything over 7 is a risk
- **No scaffolding test:** Try to complete a multi-step task without reading any instructions

**Design fixes:**
- One primary action per screen — eliminate competing CTAs
- Progress indicators on all multi-step flows
- Auto-save or session data preservation — never lose progress on timeout
- Pause/stop controls on all moving content
- Respect `prefers-reduced-motion` — ADHD users often benefit from reduced motion
- Short, chunked content with clear headings
- Prominent undo/back options at every step
- Error messages that specifically tell users what to do next
- Minimize notifications — make them opt-in, not opt-out

**WCAG criteria:** 2.2.1, 2.2.2, 3.3.1, 3.3.3 — best practice significantly exceeds WCAG here.

---

### Profile 8: Anxiety

**Who this is:**
Users with anxiety disorders — generalized anxiety, social anxiety, OCD, health anxiety, PTSD. Anxiety in UX context is often triggered by: fear of making irreversible mistakes, uncertainty about what an action will do, pressure from time limits, intrusive notifications, and dark patterns.

**How they experience digital products:**
- Irreversible actions without confirmation cause significant distress
- Vague error messages create catastrophizing loops
- Time limits and countdown timers create pressure responses
- Dark patterns (fake urgency, confirmshaming) trigger anxiety
- Unexpected state changes (sudden page redirects, popup modals) are startling
- Privacy-invasive products create persistent background stress

**Simulation techniques:**
- **Slow, deliberate read-through:** Read every label, error message, and CTA aloud — does anything feel threatening or ambiguous?
- **Error path walkthrough:** Deliberately trigger every error state — are the messages reassuring or alarming?
- **Consequence audit:** For every action, ask: what happens if the user does this by mistake? Is it recoverable?

**Design fixes:**
- Confirmation dialogs before all destructive or irreversible actions — framed calmly
- Reassuring, specific error messages — no red all-caps, no exclamation points in errors
- Undo available for as many actions as technically feasible
- No countdown timers unless genuinely time-limited — and then with extension option
- No auto-playing audio or sudden sounds
- No fake urgency or artificial scarcity
- Privacy practices explained in plain, calm language at the point of data collection
- Progress saved automatically — never lost without warning
- Support contact visibly available — knowing help exists reduces anxiety

**WCAG criteria:** 2.2.1, 2.2.6, 3.3.1, 3.3.3, 3.3.4 — anxiety is significantly undertreated in WCAG. This is a practice area beyond compliance.

---

### Profile 9: Autism Spectrum

**Who this is:**
Autistic users have diverse support needs and strengths. Common UX friction points relate to: sensory sensitivity (to motion, sound, visual complexity), literal interpretation of language, difficulty with ambiguous or inconsistent UI, and overwhelm from dense information.

**How they experience digital products:**
- Auto-playing audio or video can be overwhelming and disorienting
- Sensory-heavy UI (high contrast animations, strobing effects, busy backgrounds) causes distress
- Idiomatic or figurative language is taken literally ("Your cart is hungry!")
- Inconsistent navigation or surprise interactions break mental models
- Ambiguous or vague copy ("Continue" — continue to what?) creates uncertainty
- Social pressure mechanics ("3 people are looking at this right now") are read literally and create distress

**Simulation techniques:**
- **Literal language audit:** Read every UI string as if it were literal fact — does anything break?
- **Sensory intensity check:** Count simultaneous audio, motion, and visual stimulus — flag anything above 1–2 concurrent stimuli
- **Consistency walkthrough:** Navigate to the same destination via 3 different paths — is the result identical?
- **Predictability test:** Use the product for 5 minutes, then predict what will happen when you click each element — are your predictions correct?

**Design fixes:**
- All metaphors and idioms replaced with literal, specific language
- Opt-in for all audio and motion — nothing forces sensory input
- Navigation and component behavior 100% consistent across the product
- Confirmation for every action with uncertain outcome — "This will delete your account permanently. This cannot be undone."
- No dark patterns, no social pressure mechanics, no fake urgency
- Quiet mode option — reduces visual complexity, disables non-essential animations
- Predictable patterns — users should be able to build an accurate mental model quickly

**WCAG criteria:** 1.4.2, 2.2.2, 3.2.1, 3.2.2, 3.2.3, 3.2.4 — autism-specific needs extend significantly beyond WCAG.

---

### Profile 10: Cognitive Disabilities

**Who this is:**
Users with intellectual disabilities, traumatic brain injury, dementia, stroke effects, or other conditions affecting memory, reasoning, and language processing. Often the most underserved group in accessibility work.

**How they experience digital products:**
- Multi-step processes without external memory aids (progress indicators, summaries) cause task failure
- Abstract icons without labels are confusing
- Long paragraphs are inaccessible
- Error recovery requires more guidance than "invalid input"
- Complex navigation structures create disorientation
- Timed sessions lose work without warning

**Simulation techniques:**
- **Strip to essentials:** Remove all secondary content — is the primary task still completable?
- **Memory load test:** Cover the screen after reading instructions — can you complete the next step from memory?
- **Icon test:** Cover all text labels — can you determine what every icon does?

**Design fixes:**
- Persistent contextual cues — breadcrumbs, step indicators, page titles
- Labels on all icons — never icon-only navigation
- Short sentences, plain language, bullet lists
- Error messages that provide the correction, not just the problem
- Auto-save with explicit confirmation that work is saved
- Help available inline at every decision point
- Simple, flat navigation — maximum 2 levels deep for primary tasks

**WCAG criteria:** COGA (Cognitive Accessibility Guidance) significantly extends WCAG here. See W3C COGA supplemental guidance.

---

### Profile 11: Epilepsy / Vestibular Disorders

**Who this is:**
Users with photosensitive epilepsy (seizures triggered by flickering light above 3Hz), or vestibular disorders (inner ear conditions causing motion sickness and disorientation from visual motion — parallax, scroll-triggered animations, zooming effects).

**How they experience digital products:**
- Rapidly flashing elements can trigger seizures — this is a physical safety issue
- Parallax scroll effects, page transition animations, and zoom effects trigger vestibular symptoms
- Auto-playing video with rapid cuts or strobe effects is dangerous
- Many vestibular users have enabled `prefers-reduced-motion` and expect it to be respected

**Simulation techniques:**
- **PEAT (Photosensitive Epilepsy Analysis Tool):** Tests video content against flash threshold
- **prefers-reduced-motion override:** Set `prefers-reduced-motion: reduce` in browser DevTools — does all motion stop?
- **Scroll test with eyes half-closed:** Does scrolling cause disorientation? (Rough vestibular check)
- **Animation audit:** List every animation, transition, and auto-playing element on the page

**Design fixes:**
- No content flashing faster than 3 times per second (WCAG 2.3.1 — this is an A criterion)
- `prefers-reduced-motion` respected for all non-essential animations
- Parallax, scroll-triggered animations, and page transitions disabled under reduced motion
- Play/pause control for all auto-playing video
- No animations in the peripheral visual field (sidebars, banners) while users try to read

**WCAG criteria:** 2.3.1 (A), 2.3.2 (AAA), 2.3.3 (AAA WCAG 2.1)

---

## Output Format

```
# Disability-Specific UX Testing Report

**Product / Feature:** [name]
**Profiles Tested:** [list of disability profiles run]
**Audit Date:** [date]

---

## [Profile Name]

### How This User Would Experience This Product

[2–3 sentences describing the real user experience — not just a list of failures]

### Friction Points Found

**[CRITICAL / MAJOR / MINOR]** [Specific issue]
> Where: [location in product]
> Why it matters: [impact on this user]
> Fix: [specific, implementable change]
> WCAG: [criterion if applicable]

### Simulation Guidance

[Specific technique, tool, or persona to use for this disability profile on this product]

### What's Working Well

[1–2 specific things that already serve this user well]

---

[Repeat per profile]

---

## Cross-Profile Priority Fixes

[Issues that appeared across multiple profiles — fix these first as they have the highest reach]

1.
2.
3.

---

## Testing Toolkit Summary

| Tool | What it tests | How to access |
|------|--------------|---------------|
| Funkify | Low vision, motor, dyslexia, cognition, color | Chrome extension |
| Chrome DevTools → Rendering | Color blindness, reduced motion, forced colors | Built into Chrome |
| NVDA + Chrome | Blindness / screen reader | Free download (nvaccess.org) |
| VoiceOver | Blindness / screen reader | Built into macOS/iOS |
| Colour Contrast Analyser | Contrast, color blindness | Free desktop app (TPGi) |
| PEAT | Photosensitive epilepsy | Free download (trace.umd.edu) |
| Text Spacing Bookmarklet | Low vision, dyslexia | One-click bookmarklet (w3.org) |
```

---

## Reference Framework

Grounded in Matthew Stephens' accessibility practice and his work on Loud + Clear (Parkinson's fitness app), which holds that:

- Compliance and usability are not the same thing — WCAG is the floor, not the ceiling
- Simulation is a start, not a substitute — test with real disabled users
- Disability-specific knowledge produces better design decisions than checklist-following alone
- The Funkify Chrome extension provides accessible, low-barrier simulation for design and dev teams
- Designing for specific disability needs almost always improves the experience for everyone
