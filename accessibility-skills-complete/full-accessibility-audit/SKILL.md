---
name: full-accessibility-audit
description: "Perform a complete, multi-dimensional accessibility audit by orchestrating all specialist accessibility skills into a single unified report. Use this skill whenever the user asks for a full audit, complete accessibility review, end-to-end assessment, or wants to audit an entire product, page, or component suite from every angle. Trigger on phrases like 'full accessibility audit', 'complete audit', 'audit everything', 'comprehensive accessibility review', 'full a11y audit', 'audit this product', 'audit this page', or any audit request that does not specify a single narrow dimension. Covers design, code, contrast, copy, keyboard, motion, forms, tables, alt text, cognitive, mobile/touch, PDF/document, video/media, annotations, full WCAG 2.1/2.2 compliance, disability-specific profiles, and older audience considerations. Produces a prioritized remediation roadmap and test plan. Do not use narrow single-dimension skills when the user wants the full picture — use this."
---

# Full Accessibility Audit

You are the audit director. Your job is to run a complete accessibility assessment by systematically applying every relevant audit dimension to the input provided, then synthesizing findings into a single prioritized report with a clear path to remediation.

This skill orchestrates all specialist skills: accessibility-audit, accessibility-code, accessibility-copy, contrast-checker, keyboard-focus-auditor, motion-auditor, accessible-forms, accessible-tables, alt-text-generator, wcag-checklist, a11y-test-plan, screen-reader-scripting, cognitive-accessibility, mobile-touch-auditor, pdf-document-accessibility, video-media-accessibility, accessibility-annotations, wcag-compliance-auditor, disability-testing, and older-audiences-auditor.

---

## Step 1: Triage the Input

Before running any audit, classify what you've been given. This determines which modules run and in what order.

### Input Types

| Input | Modules to Run |
|-------|---------------|
| Screenshot / Figma / design file | Design audit, contrast, copy, alt text, motion, cognitive, annotations, disability profiles, older audiences |
| HTML / JSX / component code | Code audit, contrast, keyboard, forms (if present), tables (if present), copy, motion (if CSS included), cognitive, WCAG compliance, disability profiles |
| Full page (design + code) | All modules |
| Copy / content only | Copy audit, alt text (if images described), cognitive, older audiences |
| Form (design or code) | Forms, code, copy, contrast, keyboard, cognitive, WCAG compliance |
| Data table (design or code) | Tables, code, contrast, keyboard |
| Animated component | Motion, code, keyboard, epilepsy/vestibular profile |
| Mobile / touch UI | Mobile-touch, design audit, contrast, keyboard, cognitive, motor profile, older audiences |
| PDF or document | PDF-document, older audiences |
| Video / audio / podcast | Video-media, Deaf/HoH profile |
| Design handoff / Figma spec | Annotations, design audit, contrast, older audiences |
| URL or product description | All applicable modules based on what is described — default to running all 18 |

If the input is ambiguous, ask one question: "Are you sharing a design, code, or both?" Then proceed.

---

## Step 2: Intake Questions

Ask only if the answers aren't already clear from the input. Batch all questions into a single message.

1. What type of product? (web app, marketing site, mobile, kiosk, internal tool)
2. Target compliance level? (AA baseline, AAA enhanced, Section 508, all three)
3. Who is the primary audience? Any known user populations with disabilities?
4. Is this a new build or a remediation of existing work?
5. What is the deliverable format? (internal report, client deliverable, QA handoff, developer brief)

If the user says "just run it" or similar — default to WCAG 2.2 AAA + Section 508, assume public-facing web app, deliver a full report.

---

## Step 3: Run All Applicable Modules

Work through each module systematically. Do not skip modules because input seems incomplete — note gaps explicitly rather than silently omitting them.

### Module 1: Design / Visual Audit
*Apply: accessibility-audit skill*

Review all visual and layout elements:
- Color contrast — every text instance, every state (default, hover, focus, disabled, error)
- Color as sole information carrier — errors, status, required fields, charts
- Focus indicator design — visible, sufficient contrast, not clipped
- Touch targets — minimum 44×44px (AAA), 24×24px (AA minimum)
- Heading hierarchy — implied by visual design
- Reading and focus order — especially multi-column, card grids, floating elements
- Zoom and reflow — would this break at 400% or 320px?
- Sensory-only instructions — "click the green button", "see the box on the right"
- Whitespace and cognitive density

### Module 2: Color Contrast Deep Audit
*Apply: contrast-checker skill*

Run contrast math on every color pair present or described:
- Body text / background
- Heading text / background
- Link text / background (default, visited, hover, focus)
- Placeholder text / input background
- Disabled state text / background
- Error text / background
- Button text / button background
- Icon fill / adjacent background
- Input border / page background
- Focus ring / adjacent colors

Show luminance values and ratio for each pair. Flag every failure with the specific criterion.

### Module 3: Code Audit
*Apply: accessibility-code skill*

Review semantic structure, ARIA usage, and interaction logic:
- Semantic element choices (button vs div, nav vs div, etc.)
- Landmark regions and labels
- Heading hierarchy in DOM
- ARIA roles, states, properties — correctness and necessity
- Accessible name resolution for all interactive elements
- Live regions for dynamic content
- Focus management after state changes
- tabindex usage — flag any positive values

### Module 4: Keyboard & Focus Audit
*Apply: keyboard-focus-auditor skill*

Document the complete keyboard model:
- Tab order — map every focusable element in sequence
- Skip link — present, functional, keyboard visible
- Focus indicators — present on every interactive element
- Focus traps — correct for modals/overlays, absent elsewhere
- Keyboard operability — every action achievable without a mouse
- Focus management — dynamic content, route changes, deletions
- Focus obscured — sticky headers/footers hiding focused elements

### Module 5: Copy & Content Audit
*Apply: accessibility-copy skill*

Audit all text content for accessibility:
- Button and link labels — descriptive, unique in context
- Error messages — name the field, describe the problem, provide the fix
- Form instructions — before fields, not after
- Status and notification messages — programmatically determinable
- Reading level — target Grade 8 or below (WCAG AAA 3.1.5)
- Idioms, sensory references, directional language

### Module 6: Image & Alt Text Audit
*Apply: alt-text-generator skill*

Classify and evaluate every image:
- Decorative — confirm `alt=""` present
- Informative — evaluate alt text quality and context appropriateness
- Functional — confirm alt describes action, not appearance
- Complex (charts, infographics) — confirm short alt + long description
- Text in images — confirm alt includes verbatim text

### Module 7: Forms Audit (if forms present)
*Apply: accessible-forms skill*

Run only if forms, inputs, or data entry elements are present:
- Label association — explicit `<label for>`, no placeholder-only labels
- Input types and autocomplete tokens
- Required field marking — text or symbol with legend, not color only
- Inline hints — between label and input, linked via aria-describedby
- Validation timing — on blur, not on keystroke
- Error state implementation — aria-invalid, aria-describedby, role=alert
- Error summary — present on multi-field forms, receives focus on submit failure
- Fieldset + legend for grouped inputs
- Multi-step flow focus management

### Module 8: Tables Audit (if tables present)
*Apply: accessible-tables skill*

Run only if data tables are present:
- caption present and descriptive
- thead / tbody / tfoot structure
- scope on all th elements (or id/headers for complex tables)
- th vs td correct usage
- Sortable column ARIA (aria-sort)
- Responsive strategy — does it maintain semantic structure?
- Row selection ARIA (aria-selected)

### Module 9: Motion & Animation Audit (if motion present)
*Apply: motion-auditor skill*

Run only if animations, transitions, or auto-playing content are present:
- Flashing content — below 3Hz threshold (WCAG 2.3.1)
- prefers-reduced-motion — CSS and JS coverage
- Auto-playing content — pause/stop controls (WCAG 2.2.2)
- Vestibular risk — parallax, large viewport motion, zoom effects
- Third-party library configuration — Framer Motion, GSAP, Lottie, AOS

### Module 10: Screen Reader Test Plan
*Apply: screen-reader-scripting skill*

For the primary interactive components found in the audit, generate AT test scripts covering:
- NVDA + Chrome (Windows) — minimum
- VoiceOver + Safari (macOS) — minimum
- Key flows: navigation, primary action, form submission, error recovery

### Module 11: Cognitive Accessibility Audit
*Apply: cognitive-accessibility skill*
*Run for all input types — cognitive accessibility applies everywhere*

- Reading level — estimate grade level; flag if above Grade 8
- Plain language — passive voice, sentence length, jargon, idioms
- Typography — line length, line height, justified text, ALL CAPS
- Memory and attention load — simultaneous choices, steps without reference, distractions
- Consistency and predictability — navigation order, component naming, unexpected changes
- Error prevention — confirmation for destructive actions, undo availability
- Dark patterns — urgency manipulation, confirmshaming, hidden cancellation
- Accessible authentication — CAPTCHA, knowledge-based challenges, paste disabled
- Context-sensitive help — available at decision points without leaving flow
- Session and timeout handling — warnings, data preservation

### Module 12: Mobile & Touch Audit
*Apply: mobile-touch-auditor skill*
*Run when input is a mobile app, responsive web app, or any touch UI*

- Touch target sizing — 44×44px (AAA), 24×24px (AA minimum)
- Gesture alternatives — every swipe/pinch has a single-tap equivalent
- Pointer cancellation — actions on up-event, not down-event
- Motion actuation — shake/tilt alternatives, can be disabled
- Orientation — not locked to portrait or landscape
- Virtual keyboard — inputs trigger correct keyboard type; viewport not obscured
- Thumb zone — critical actions within comfortable reach zone
- iOS VoiceOver — accessibilityLabel, accessibilityViewIsModal, focus notifications
- Android TalkBack — contentDescription, announceForAccessibility, live regions
- Responsive web — viewport meta, touch-action, 320px reflow

### Module 13: PDF & Document Audit
*Apply: pdf-document-accessibility skill*
*Run when input includes or references PDFs, Word docs, PowerPoint, or downloadable files*

- Tagged PDF — structure tree present and correct
- Reading order — matches logical/visual order; columns read correctly
- Heading tags — H1–H6 used, not bold paragraphs
- Image alt text — all figures have Alt Text in tag; decorative tagged as Artifact
- Table structure — TH with scope, caption present
- Language declaration — document language set
- Title — descriptive title set; "display document title" enabled
- Links — active, descriptive link text
- Bookmarks — present for documents over 10 pages
- Forms (if present) — field tooltips, tab order, keyboard operable
- Fonts — embedded; actual text, not bitmap

### Module 14: Video & Media Audit
*Apply: video-media-accessibility skill*
*Run when input includes or references video, audio, podcasts, webinars, or animations with narration*

- Captions — present for all prerecorded video with audio (AA)
- Caption quality — accuracy, timing, speaker ID, sound effects, formatting
- Audio description — present for all prerecorded video (AA)
- Transcript — present for audio-only content; descriptive transcript for video
- Live captions — present for live video with audio (AA)
- Media player — keyboard accessible, all controls labeled, no hover-only UI
- Autoplay — not autoplaying with audio; pause/stop control if autoplaying

### Module 15: Design Handoff Annotations
*Apply: accessibility-annotations skill*
*Run when input is a design file, Figma spec, or when producing developer handoff documentation*

Generate annotation content for:
- Focus order — numbered tab stop sequence for all interactive elements
- Landmark map — all regions with labels
- Heading levels — H1–H6 assignment for every text element
- ARIA roles and names — per component
- Interactive states — hover, focus, active, disabled, error, selected, expanded
- Keyboard behavior — key mappings per component
- Reading order — DOM order where it differs from visual
- Live regions — role=alert, role=status placement
- Skip link — presence and destination

### Module 16: Full WCAG 2.1 / 2.2 Compliance Audit
*Apply: wcag-compliance-auditor skill*
*Run for all input types — this is the standards-reference layer*

Systematically work through all four WCAG principles against the input:

**Perceivable:** All 29 criteria including WCAG 2.1 additions (1.3.4, 1.3.5, 1.4.10-1.4.13)
**Operable:** All 31 criteria including WCAG 2.2 additions (2.4.11-2.4.13, 2.5.7-2.5.8)
**Understandable:** All 17 criteria including WCAG 2.2 additions (3.2.6, 3.3.7-3.3.9)
**Robust:** All criteria including 4.1.3 (WCAG 2.1)

For each failure: criterion number, level (A/AA/AAA), impact, and specific fix. Produce a conformance summary table.

### Module 17: Disability-Specific Experience Testing
*Apply: disability-testing skill*
*Run for all input types — applies lived-experience lens beyond WCAG compliance*

Evaluate through each applicable profile:
- Low vision, Blindness/screen reader, Color blindness
- Motor impairments, Deaf/HoH
- Dyslexia, ADHD, Anxiety, Autism spectrum, Cognitive disabilities
- Epilepsy/vestibular disorders

For each: how this user experiences the product, friction points, simulation guidance, targeted fixes.

### Module 18: Older Audiences Audit
*Apply: older-audiences-auditor skill*
*Run when product audience includes users 50+, or when no specific age restriction applies*

Evaluate across six age-related dimensions: Vision and Typography, Cognition and Clarity, Motor Control and Touch, Hearing and Audio, Trust and Error Recovery, Content and Language. Note curb-cut overlaps with disability profiles throughout.

---

## Step 4: Synthesize Into Unified Report

After running all applicable modules, compile findings into a single structured report. Do not produce separate reports per module — merge everything, deduplicate overlapping findings, and present a unified view.

### Report Structure

```
# Accessibility Audit Report

**Product / Component:** [name]
**Input Type:** [design / code / both / description]
**Standards:** WCAG 2.2 AAA, Section 508, ARIA APG
**Date:** [today]
**Auditor:** Full Accessibility Audit (Claude)

---

## Executive Summary

[3–5 sentences: overall state, total issue count by severity, highest-risk area,
one strength if present, and the single most important thing to fix first.]

**Issue Count:**
- P0 Critical: [n]
- P1 Major: [n]
- P2 Minor: [n]
- P3 Enhancement: [n]

**Compliance Estimate:** [Likely non-conformant / Partially conformant / Substantially conformant]
Note: Full conformance determination requires manual AT testing.

---

## Critical Issues — P0
*Must fix before launch. Legal exposure. Blocks task completion.*

### [Issue Title]
- **Module:** [which audit dimension caught this]
- **WCAG:** [criterion number and name]
- **Finding:** [what was observed]
- **Impact:** [who is affected and how — be specific about disability type]
- **Fix:** [specific, actionable remediation with code if applicable]

[repeat for each P0]

---

## Major Issues — P1
*Fix in current sprint. Significantly degrades experience.*

[same format]

---

## Minor Issues — P2
*Fix in next sprint. Workarounds exist.*

[same format]

---

## Enhancements — P3
*Best practice. Consider for AAA compliance or future iteration.*

[same format]

---

## Passed Checks
[Bulleted list of what was reviewed and confirmed accessible — gives the team
positive signal and establishes audit coverage.]

---

## Contrast Audit Summary
| Element | Foreground | Background | Ratio | AA | AAA | Notes |
|---------|------------|------------|-------|----|-----|-------|

---

## Keyboard Flow Map
[Tab order table for primary interactive elements]

---

## Images Inventory
| Image | Classification | Alt Text | Status |
|-------|---------------|----------|--------|

---

## Remediation Roadmap

### Phase 1 — Immediate (This Sprint)
[P0 fixes only, prioritized by user impact]

### Phase 2 — Short Term (Next 2 Sprints)
[P1 fixes, grouped by component or area to minimize context switching]

### Phase 3 — Planned (Next Quarter)
[P2 fixes and P3 enhancements, with suggested sequencing]

---

## Recommended Testing
[2–3 highest-value manual test cases from screen-reader-scripting output,
with AT combinations and exact steps]

---

## Audit Coverage
[Table showing which modules ran, which were N/A, and why]

| Module | Status | Notes |
|--------|--------|-------|
| Design / Visual | Ran | [summary] |
| Contrast | Ran | [n pairs checked] |
| Code | N/A | No code provided |
| Keyboard | Ran | [summary] |
| Copy | Ran | [summary] |
| Alt Text | Ran | [n images] |
| Forms | N/A | No forms present |
| Tables | Ran | [summary] |
| Motion | N/A | No animation present |
| Screen Reader Scripts | Ran | NVDA+Chrome, VoiceOver+Safari |
| Cognitive | Ran | [summary] |
| Mobile / Touch | N/A | Desktop web only |
| PDF / Document | N/A | No documents referenced |
| Video / Media | N/A | No media present |
| Annotations | Ran | Focus order + landmark map generated |
| WCAG 2.1/2.2 Compliance | Ran | [n criteria checked, n failures] |
| Disability Profiles | Ran | [profiles tested] |
| Older Audiences | Ran | [summary] |

---

## Caveats
- This audit is based on [design / code / description] provided. Results reflect
  what can be assessed from that input.
- Automated tools catch ~30% of WCAG issues. This audit applies manual methodology
  but cannot substitute for AT testing with real assistive technology.
- Contrast ratios are calculated from sampled or provided color values. Verify
  against final rendered output.
- Full conformance claims require testing with disabled users.
```

---

## Step 5: Offer Next Actions

After delivering the report, always offer:

1. **Detailed fix guidance** — "Want me to write corrected code for any of the P0 issues?"
2. **Full test plan** — "Want a complete QA test plan from the a11y-test-plan skill?"
3. **WCAG checklist** — "Want a scoped WCAG 2.2 checklist for this product type?"
4. **Stakeholder summary** — "Want a 1-page exec summary for a client or leadership?"
5. **Accessibility statement draft** — "Want a draft accessibility statement based on these findings?"

---

## Audit Quality Standards

Every audit produced by this skill must:

- Reference specific WCAG criterion numbers for every finding
- Include severity ratings (P0–P3) for every issue
- Provide actionable fixes, not just observations
- Show contrast math, not just pass/fail verdicts
- Distinguish between legal-minimum (AA) failures and best-practice (AAA) gaps
- Be honest about what can and cannot be determined from the input provided
- Never claim full conformance — always note AT testing requirement

If input is too limited to run a meaningful audit, say so specifically and ask for what's needed. A thin audit is worse than no audit — it creates false confidence.
