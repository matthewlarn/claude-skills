---
name: wcag-compliance-auditor
description: Run a comprehensive WCAG 2.1 and 2.2 compliance audit across all four principles (Perceivable, Operable, Understandable, Robust) at AA and AAA conformance levels. Produces a full findings report with criterion references, severity ratings, remediation guidance, and a conformance declaration. Use this skill whenever someone needs a thorough, standards-based accessibility audit, a VPAT input, a compliance baseline, or a full accessibility report covering all WCAG success criteria. Trigger on phrases like full WCAG audit, WCAG compliance, accessibility compliance audit, VPAT audit, Section 508 audit, complete accessibility review, WCAG 2.1, WCAG 2.2, AA compliance, AAA compliance, conformance audit, accessibility baseline, or any request for a complete standards-based accessibility evaluation. Always use this skill for comprehensive WCAG coverage — use the specialist skills for single-dimension audits.
---

# Comprehensive WCAG Compliance Auditor

Full WCAG 2.1 and 2.2 audit across all four principles. Produces a standards-referenced findings report with criterion numbers, conformance levels, severity ratings, remediation guidance, and an overall conformance declaration.

This skill covers all 78 WCAG 2.1 success criteria plus the 9 new criteria added in WCAG 2.2. For single-dimension audits (keyboard, contrast, forms, etc.) use the specialist accessibility skills in the suite.

---

## WCAG Structure

**4 Principles → 13 Guidelines → 87 Success Criteria (WCAG 2.1 + 2.2)**

| Principle | What it means |
|-----------|---------------|
| Perceivable | Information must be presentable to users in ways they can perceive |
| Operable | UI components and navigation must be operable |
| Understandable | Information and UI operation must be understandable |
| Robust | Content must be robust enough for assistive technologies to reliably interpret |

**Conformance Levels:**
- **A** — Minimum. Blocking failures that prevent access entirely
- **AA** — Standard. The legal and industry baseline in most jurisdictions
- **AAA** — Enhanced. Best practice; not universally achievable for all content types

---

## Audit Scope

Before auditing, establish:
- URL(s) or prototype being audited
- Pages/views/flows in scope
- Assistive technologies to test with (minimum: NVDA + Chrome, VoiceOver + Safari)
- Target conformance level (AA is the standard target)
- Any known exceptions or limitations

---

## PRINCIPLE 1: PERCEIVABLE

### Guideline 1.1 — Text Alternatives

**1.1.1 Non-text Content (A)**
All non-text content has a text alternative that serves the equivalent purpose.
Exceptions: controls/inputs (use name), time-based media (use description), tests (use description), sensory content (use description), CAPTCHA (use text alternative), decoration (null alt or CSS).

Audit checks:
- [ ] All `<img>` elements have meaningful `alt` attributes — or `alt=""` if decorative
- [ ] Complex images (charts, diagrams) have extended descriptions (aria-describedby or figcaption)
- [ ] Icon fonts and SVG icons have accessible labels or `aria-hidden="true"`
- [ ] Image buttons have descriptive `alt` text describing the action
- [ ] Background images carrying meaning are also represented in text
- [ ] CAPTCHA has an audio or other alternative format

---

### Guideline 1.2 — Time-Based Media

**1.2.1 Audio-only and Video-only — Prerecorded (A)**
Prerecorded audio-only: text transcript. Prerecorded video-only: text transcript or audio description.

**1.2.2 Captions — Prerecorded (A)**
Captions provided for all prerecorded audio in synchronized media.

**1.2.3 Audio Description or Media Alternative — Prerecorded (A)**
Audio description or full text alternative provided for prerecorded synchronized media.

**1.2.4 Captions — Live (AA)**
Captions provided for all live audio in synchronized media.

**1.2.5 Audio Description — Prerecorded (AA)**
Audio description provided for all prerecorded video in synchronized media.

**1.2.6 Sign Language — Prerecorded (AAA)**
Sign language interpretation provided for all prerecorded audio.

**1.2.7 Extended Audio Description — Prerecorded (AAA)**
Extended audio description provided where foreground audio pauses are insufficient.

**1.2.8 Media Alternative — Prerecorded (AAA)**
Alternative for time-based media provided for all prerecorded synchronized media.

**1.2.9 Audio-only — Live (AAA)**
Alternative for live audio-only content provided.

Audit checks:
- [ ] All video has accurate captions (not auto-generated uncorrected)
- [ ] Captions include speaker identification and non-speech audio
- [ ] Audio description tracks available for video with visual-only information
- [ ] Transcripts available for all audio content
- [ ] Live streams have real-time captions where applicable

---

### Guideline 1.3 — Adaptable

**1.3.1 Info and Relationships (A)**
Information, structure, and relationships conveyed through presentation can be programmatically determined or available in text.

Audit checks:
- [ ] Headings use `<h1>`–`<h6>` semantically, not styled `<div>` or `<span>`
- [ ] Lists use `<ul>`, `<ol>`, `<dl>` not styled paragraphs
- [ ] Tables use `<th>` with `scope` attributes; no layout tables
- [ ] Form inputs have associated `<label>` elements (not placeholder-only)
- [ ] Required fields indicated programmatically (`aria-required` or HTML required)
- [ ] Error messages programmatically associated with their inputs
- [ ] Groupings use `<fieldset>` and `<legend>` for radio/checkbox groups
- [ ] Visual relationships conveyed in markup, not only through CSS

**1.3.2 Meaningful Sequence (A)**
Reading order in DOM matches logical reading sequence.

Audit checks:
- [ ] DOM order matches visual reading order
- [ ] CSS-only reordering (flexbox order, absolute positioning) does not break reading sequence
- [ ] Tab order is logical and follows visual flow

**1.3.3 Sensory Characteristics (A)**
Instructions do not rely solely on sensory characteristics (shape, color, size, visual location, orientation, sound).

Audit checks:
- [ ] Instructions do not say "click the green button" or "see the box on the right"
- [ ] All sensory references have text alternatives

**1.3.4 Orientation (AA) — WCAG 2.1**
Content does not restrict its view and operation to a single display orientation unless essential.

Audit checks:
- [ ] No CSS or JS that locks orientation to portrait or landscape
- [ ] Content functions in both portrait and landscape

**1.3.5 Identify Input Purpose (AA) — WCAG 2.1**
Input purpose for user interface components that collect personal information can be programmatically determined.

Audit checks:
- [ ] Personal data inputs use `autocomplete` attributes (name, email, tel, address, etc.)
- [ ] Reference: https://www.w3.org/TR/WCAG21/#input-purposes

**1.3.6 Identify Purpose (AAA) — WCAG 2.1**
Purpose of UI components, icons, and regions can be programmatically determined.

---

### Guideline 1.4 — Distinguishable

**1.4.1 Use of Color (A)**
Color is not the only visual means of conveying information, indicating action, or distinguishing visual elements.

Audit checks:
- [ ] Form errors marked with text/icon, not only red color
- [ ] Links distinguishable from surrounding text without relying on color alone
- [ ] Charts/graphs use patterns or labels, not only color
- [ ] Status indicators use shape/icon in addition to color

**1.4.2 Audio Control (A)**
Any audio that plays automatically for more than 3 seconds can be paused, stopped, or volume adjusted.

Audit checks:
- [ ] No auto-playing audio without immediate control
- [ ] Volume control independent of system volume

**1.4.3 Contrast — Minimum (AA)**
Text and images of text have a contrast ratio of at least 4.5:1 (3:1 for large text: 18pt/24px regular or 14pt/18.67px bold).

Audit checks:
- [ ] All body text ≥ 4.5:1 against background
- [ ] Large text ≥ 3:1
- [ ] Placeholder text ≥ 4.5:1 (commonly fails — placeholders are text)
- [ ] Disabled elements are exempt but avoid using disabled styling for active elements
- [ ] Test all color combinations including hover/focus states

**1.4.4 Resize Text (AA)**
Text can be resized up to 200% without assistive technology and without loss of content or functionality.

Audit checks:
- [ ] Page functions at 200% zoom in browser
- [ ] No horizontal scrolling required at 200% zoom
- [ ] No content hidden or truncated at 200% zoom
- [ ] Text set in relative units (rem/em), not fixed px for body

**1.4.5 Images of Text (AA)**
If technologies can achieve visual presentation, text is used instead of images of text — except for logotypes.

Audit checks:
- [ ] No images of text (buttons with text baked into an image)
- [ ] Decorative text images are exempt; logos are exempt

**1.4.6 Contrast — Enhanced (AAA)**
Contrast ratio of at least 7:1 for text (4.5:1 large text).

**1.4.7 Low or No Background Audio (AAA)**
For prerecorded audio with speech: no background sound, background can be turned off, or background is 20dB lower than foreground.

**1.4.8 Visual Presentation (AAA)**
For blocks of text: foreground/background selectable, width no more than 80 characters, not full justified, line spacing at least 1.5, text resizable.

**1.4.9 Images of Text — No Exception (AAA)**
Images of text only used for pure decoration or essential configuration.

**1.4.10 Reflow (AA) — WCAG 2.1**
Content reflows to single column at 320 CSS px (400% zoom on 1280px viewport) without horizontal scrolling.

Audit checks:
- [ ] Page functions at 400% zoom without horizontal scrollbar
- [ ] Content reflows to single column at 320px viewport width
- [ ] No fixed-width containers that cause overflow

**1.4.11 Non-text Contrast (AA) — WCAG 2.1**
UI components and graphical objects have a contrast ratio of at least 3:1 against adjacent colors.

Audit checks:
- [ ] Form input borders ≥ 3:1 against background
- [ ] Button boundaries ≥ 3:1
- [ ] Focus indicators ≥ 3:1
- [ ] Chart data points/lines ≥ 3:1
- [ ] Icons that convey meaning ≥ 3:1

**1.4.12 Text Spacing (AA) — WCAG 2.1**
No loss of content or functionality when the following properties are overridden: line height ≥ 1.5× font size, letter spacing ≥ 0.12× font size, word spacing ≥ 0.16× font size, spacing after paragraphs ≥ 2× font size.

Audit checks:
- [ ] Apply the Text Spacing bookmarklet and verify no content loss
- [ ] No content clipped, hidden, or overlapping under these spacing conditions

**1.4.13 Content on Hover or Focus (AA) — WCAG 2.1**
Additional content that appears on hover or focus is: dismissible (Escape key), hoverable (pointer can move over it), and persistent (remains until dismissed or trigger removed).

Audit checks:
- [ ] Tooltips can be dismissed with Escape without moving pointer
- [ ] Tooltips remain visible when pointer moves over them
- [ ] Tooltip content does not auto-hide after a timeout

---

## PRINCIPLE 2: OPERABLE

### Guideline 2.1 — Keyboard Accessible

**2.1.1 Keyboard (A)**
All functionality is operable through a keyboard interface without requiring specific timing.

Audit checks:
- [ ] Every interactive element is reachable and operable via Tab/Shift+Tab
- [ ] Custom components handle keyboard correctly (dropdowns, modals, date pickers)
- [ ] No keyboard traps (focus enters but cannot leave without mouse)
- [ ] All mouse-triggered events (click, hover) have keyboard equivalents

**2.1.2 No Keyboard Trap (A)**
If keyboard focus can be moved to a component, focus can be moved away using standard keys.

Audit checks:
- [ ] No focus traps in non-modal contexts
- [ ] Modals have intentional focus trap with Escape to close

**2.1.3 Keyboard — No Exception (AAA)**
All functionality operable via keyboard with no exceptions.

**2.1.4 Character Key Shortcuts (A) — WCAG 2.1**
Single-character keyboard shortcuts can be turned off, remapped, or only active when component has focus.

Audit checks:
- [ ] Any single-key shortcuts can be disabled or remapped in settings

---

### Guideline 2.2 — Enough Time

**2.2.1 Timing Adjustable (A)**
For each time limit, user can turn it off, adjust it (10× minimum), or extend it (20+ second warning, at least 10 times extendable).

**2.2.2 Pause, Stop, Hide (A)**
For moving/blinking/scrolling/auto-updating content: user can pause, stop, or hide it if it starts automatically, lasts more than 5 seconds, and is presented in parallel with other content.

Audit checks:
- [ ] Auto-playing carousels have pause control
- [ ] Auto-advancing slides can be stopped
- [ ] Animated content (non-decorative) can be paused

**2.2.3 No Timing (AAA)**
Timing is not an essential part of the event or activity — except real-time or competitive events.

**2.2.4 Interruptions (AAA)**
Interruptions can be postponed or suppressed by the user.

**2.2.5 Re-authenticating (AAA)**
After session expires, user can re-authenticate and continue without losing data.

**2.2.6 Timeouts (AA) — WCAG 2.1**
Users are warned of the duration of inactivity that will cause data loss, unless data is preserved for 20+ hours.

---

### Guideline 2.3 — Seizures and Physical Reactions

**2.3.1 Three Flashes or Below Threshold (A)**
No content flashes more than 3 times per second, or flash is below general and red flash thresholds.

Audit checks:
- [ ] No rapidly flashing animations
- [ ] Any video content reviewed for flash risk (PEAT tool if needed)

**2.3.2 Three Flashes (AAA)**
No content flashes more than 3 times per second.

**2.3.3 Animation from Interactions (AAA) — WCAG 2.1**
Motion animation triggered by interaction can be disabled unless essential.

Audit checks:
- [ ] `prefers-reduced-motion` media query respected for all non-essential animations
- [ ] Parallax, scroll-triggered animations, and page transitions respect reduced motion preference

---

### Guideline 2.4 — Navigable

**2.4.1 Bypass Blocks (A)**
A mechanism exists to bypass blocks of content that are repeated on multiple pages (skip links).

Audit checks:
- [ ] Skip to main content link present — visible on focus, functional
- [ ] Skip link works in all major screen reader + browser combinations

**2.4.2 Page Titled (A)**
Web pages have descriptive titles that describe topic or purpose.

Audit checks:
- [ ] Every page/view has a unique, descriptive `<title>`
- [ ] SPA routes update the `<title>` on navigation

**2.4.3 Focus Order (A)**
If a page can be navigated sequentially, focus order preserves meaning and operability.

Audit checks:
- [ ] Tab order follows logical visual reading order
- [ ] Modal dialogs receive focus when opened
- [ ] Focus returns to trigger element when modal closes
- [ ] Dynamic content insertion does not disrupt focus order

**2.4.4 Link Purpose — In Context (A)**
The purpose of each link can be determined from the link text alone, or from context (surrounding text, list, table, heading).

Audit checks:
- [ ] No "click here," "read more," "learn more" as the only link text
- [ ] All icon links have accessible labels (`aria-label`)
- [ ] Links in context are distinguishable from their destination

**2.4.5 Multiple Ways (AA)**
More than one way to locate a page within a set of pages — except where a step in a process.

Audit checks:
- [ ] Site has navigation + search, or navigation + sitemap, or similar secondary path

**2.4.6 Headings and Labels (AA)**
Headings and labels describe topic or purpose.

Audit checks:
- [ ] All headings accurately describe their section content
- [ ] Form labels clearly describe their input's purpose
- [ ] No vague headings ("More information," "Details")

**2.4.7 Focus Visible (AA)**
Any keyboard-operable interface has a visible keyboard focus indicator.

Audit checks:
- [ ] `:focus` styles never suppressed without replacement (`outline: none` without alternative)
- [ ] Focus indicator has ≥ 3:1 contrast against adjacent colors (WCAG 2.2 strengthens this)
- [ ] Focus indicator visible on all interactive elements

**2.4.8 Location (AAA)**
Information about user's location in a set of pages is available (breadcrumb, step indicator, sitemap).

**2.4.9 Link Purpose — Link Only (AAA)**
Purpose of each link can be determined from the link text alone.

**2.4.10 Section Headings (AAA)**
Section headings are used to organize content.

**2.4.11 Focus Not Obscured — Minimum (AA) — WCAG 2.2**
When a keyboard-focusable component receives focus, it is not entirely hidden by author-created content (sticky headers, banners, cookie notices).

Audit checks:
- [ ] Sticky headers and footers do not completely cover focused elements
- [ ] Cookie banners do not cover focused elements below

**2.4.12 Focus Not Obscured — Enhanced (AAA) — WCAG 2.2**
Focused component is fully visible — not partially obscured.

**2.4.13 Focus Appearance (AAA) — WCAG 2.2**
Focus indicator: area ≥ perimeter of unfocused component × CSS px; contrast change ≥ 3:1 between focused/unfocused states.

---

### Guideline 2.5 — Input Modalities (WCAG 2.1)

**2.5.1 Pointer Gestures (A)**
All functionality using multipoint or path-based gestures operable with a single pointer.

Audit checks:
- [ ] Swipe actions have button alternatives
- [ ] Pinch-to-zoom has button alternatives
- [ ] Map/canvas gestures have keyboard/button alternatives

**2.5.2 Pointer Cancellation (A)**
For functionality with single pointer: no down-event activation (or up-event cancels), up-event reverses action, or activation on down-event is essential.

Audit checks:
- [ ] Click/tap actions fire on mouseup/pointerup, not mousedown/pointerdown
- [ ] Drag operations can be cancelled by releasing outside the target

**2.5.3 Label in Name (A)**
For UI components with visible text labels, the accessible name contains the visible text.

Audit checks:
- [ ] aria-label values include the visible button/link text (not replace it)
- [ ] No mismatches between visible text and accessible name

**2.5.4 Motion Actuation (A)**
Functionality triggered by device motion can be operated via UI and disabled to prevent accidental activation.

Audit checks:
- [ ] Shake-to-undo and similar motion features have UI alternatives
- [ ] Motion triggers can be turned off in settings

**2.5.5 Target Size — Enhanced (AAA)**
Touch target size is at least 44×44 CSS pixels.

**2.5.6 Concurrent Input Mechanisms (AAA)**
Web content does not restrict use of input modalities available on a platform.

**2.5.7 Dragging Movements (AA) — WCAG 2.2**
All functionality using dragging movements operable with single pointer without drag.

Audit checks:
- [ ] Sortable lists have up/down button alternatives
- [ ] Sliders have numeric input alternatives or arrow key support
- [ ] Drag-to-resize panels have keyboard alternatives

**2.5.8 Target Size — Minimum (AA) — WCAG 2.2**
Target size is at least 24×24 CSS pixels — except where inline, native browser default, or essential.

Audit checks:
- [ ] All interactive targets meet 24×24px minimum
- [ ] Spacing between targets compensates for smaller sizes (spacing + target ≥ 24px)

---

## PRINCIPLE 3: UNDERSTANDABLE

### Guideline 3.1 — Readable

**3.1.1 Language of Page (A)**
Default human language of each page can be programmatically determined.

Audit checks:
- [ ] `<html lang="en">` (or appropriate language code) present on every page
- [ ] Language code is valid BCP 47 tag

**3.1.2 Language of Parts (AA)**
Language of each passage or phrase can be programmatically determined when different from page language.

Audit checks:
- [ ] `lang` attribute used on elements containing text in a different language
- [ ] Foreign words and phrases marked with appropriate lang

**3.1.3 Unusual Words (AAA)**
Mechanism to identify definitions of unusual words or jargon.

**3.1.4 Abbreviations (AAA)**
Mechanism to identify expanded form of abbreviations.

**3.1.5 Reading Level (AAA)**
When text requires reading ability more advanced than lower secondary education, supplemental content or simpler version available.

**3.1.6 Pronunciation (AAA)**
Mechanism to identify pronunciation of words where meaning is ambiguous without pronunciation.

---

### Guideline 3.2 — Predictable

**3.2.1 On Focus (A)**
Receiving focus does not initiate a change of context.

Audit checks:
- [ ] No form auto-submission on field focus
- [ ] No navigation on focus (dropdowns that navigate on hover/focus)
- [ ] No page redirect triggered by focus

**3.2.2 On Input (A)**
Changing a UI component's setting does not automatically cause a change of context unless user is advised in advance.

Audit checks:
- [ ] Select/radio changes don't auto-navigate without user confirmation
- [ ] Form field changes don't trigger surprising page updates
- [ ] If auto-update occurs on input, user is warned in advance

**3.2.3 Consistent Navigation (AA)**
Navigation that appears on multiple pages occurs in the same relative order.

Audit checks:
- [ ] Site navigation order is consistent across all pages
- [ ] Footer links appear in consistent order

**3.2.4 Consistent Identification (AA)**
Components with the same functionality are identified consistently.

Audit checks:
- [ ] Search fields consistently labeled as "Search"
- [ ] Same icon used for same function throughout the product
- [ ] Button labels consistent for same action across the product

**3.2.5 Change on Request (AAA)**
Changes of context initiated only by user request, or mechanism to turn off such changes available.

**3.2.6 Consistent Help (A) — WCAG 2.2**
Help mechanisms (human contact, automated contact, self-help, fully automated contact) appear in consistent location when present on multiple pages.

Audit checks:
- [ ] Help links, chat widgets, and support buttons appear in the same location across pages

---

### Guideline 3.3 — Input Assistance

**3.3.1 Error Identification (A)**
If an input error is detected, the item in error is identified and described in text.

Audit checks:
- [ ] Errors identified by text, not only by color or icon
- [ ] Error messages describe what is wrong specifically
- [ ] Error messages associated programmatically with their input (aria-describedby)

**3.3.2 Labels or Instructions (A)**
Labels or instructions provided when content requires user input.

Audit checks:
- [ ] Every form field has a visible label
- [ ] Format instructions (MM/DD/YYYY, phone format) provided before input, not only in placeholder
- [ ] Required fields indicated clearly

**3.3.3 Error Suggestion (AA)**
If an error is detected and suggestions for correction are known, suggestions are provided — unless it would jeopardize security.

Audit checks:
- [ ] Error messages tell users how to fix the problem
- [ ] Password field errors explain the requirements
- [ ] Format errors show the correct format

**3.3.4 Error Prevention — Legal, Financial, Data (AA)**
For pages that cause legal, financial, or data commitments: submissions are reversible, verified (user can review and correct), or confirmed (checkbox/dialog before submission).

Audit checks:
- [ ] Order confirmations show full details before final submission
- [ ] Irreversible actions have a confirmation step
- [ ] User can review and edit before submitting legal/financial forms

**3.3.5 Help (AAA)**
Context-sensitive help is available.

**3.3.6 Error Prevention — All (AAA)**
For all pages requiring input: submissions are reversible, verified, or confirmed.

**3.3.7 Redundant Entry (A) — WCAG 2.2**
Information already entered and still required in the same process is auto-populated or available for selection.

Audit checks:
- [ ] Multi-step forms don't re-ask for information provided in earlier steps
- [ ] Shipping address can be copied to billing address
- [ ] Name/email not re-requested if already logged in

**3.3.8 Accessible Authentication — Minimum (AA) — WCAG 2.2**
Cognitive function test (e.g., remembering a password) is not required for authentication unless an alternative method exists, help is available, or the test identifies objects or personal content.

Audit checks:
- [ ] Login allows password manager use (no restriction of paste)
- [ ] CAPTCHA alternatives available (audio, logical, or exception)
- [ ] "Remember me" or biometric alternatives available

**3.3.9 Accessible Authentication — Enhanced (AAA) — WCAG 2.2**
Cognitive function test not required for any authentication step.

---

## PRINCIPLE 4: ROBUST

### Guideline 4.1 — Compatible

**4.1.1 Parsing (A)** *(Obsolete in WCAG 2.2 — pass by default)*
In WCAG 2.1 this required valid HTML. WCAG 2.2 has removed this as a success criterion.

**4.1.2 Name, Role, Value (A)**
For all UI components: name, role, and value can be programmatically determined; states, properties, and values can be set by user; changes are notified to assistive technologies.

Audit checks:
- [ ] All interactive elements have accessible names
- [ ] ARIA roles used correctly (not overriding native semantics unnecessarily)
- [ ] ARIA states updated dynamically (aria-expanded, aria-selected, aria-checked)
- [ ] Custom components follow ARIA Authoring Practices Guide (APG) patterns
- [ ] Live regions (aria-live) used for dynamic content updates
- [ ] Modals use `role="dialog"` with `aria-labelledby`
- [ ] Tabs use `role="tablist"`, `role="tab"`, `role="tabpanel"` correctly

**4.1.3 Status Messages (AA) — WCAG 2.1**
Status messages can be programmatically determined through role or properties so they can be conveyed by assistive technologies without receiving focus.

Audit checks:
- [ ] Success messages use `role="status"` or `aria-live="polite"`
- [ ] Error messages use `role="alert"` or `aria-live="assertive"`
- [ ] Loading indicators announced appropriately
- [ ] Cart count updates announced
- [ ] Form submission success/failure announced without requiring focus move

---

## Audit Process

### Step 1 — Automated Scan
Run automated tools as a first pass. Automated testing catches ~30–40% of WCAG issues.

Recommended tools:
- **axe DevTools** (browser extension) — most accurate automated scanner
- **WAVE** (WebAIM) — good visual overlay
- **Lighthouse Accessibility** (Chrome DevTools) — integrated, good for CI
- **IBM Equal Access Checker** — comprehensive automated checks

Automated tests reliably catch: missing alt text, missing form labels, color contrast, invalid ARIA, missing lang attribute, duplicate IDs.

Automated tests cannot catch: keyboard trap testing, focus order logic, meaningful alt text quality, label accuracy, cognitive load, motion issues.

### Step 2 — Manual Keyboard Testing
- Tab through entire page — verify all interactive elements are reachable
- Verify focus order is logical
- Test Enter/Space on all interactive elements
- Test Escape on all overlays/modals/drawers
- Test arrow keys in components that use them (menus, tabs, date pickers)
- Verify no keyboard traps

### Step 3 — Screen Reader Testing
Minimum matrix:
- NVDA + Chrome (Windows) — most common AT combination
- VoiceOver + Safari (macOS/iOS)
- TalkBack + Chrome (Android) for mobile

Test: navigation by heading, landmark navigation, form completion, modal interaction, dynamic content updates, error messages.

### Step 4 — Zoom & Reflow Testing
- Browser zoom to 200%, 400%
- Text spacing override (use the Text Spacing bookmarklet)
- Test at 320px viewport width (simulates 400% zoom on 1280px)

### Step 5 — Color & Contrast
- Test all text/background combinations with a contrast checker
- Test non-text contrast (inputs, focus indicators, icons)
- Test in Windows High Contrast Mode (Forced Colors)

---

## Output Format

```
# WCAG Compliance Audit Report

**Product / URL:** [name or URL]
**Pages/Views Audited:** [list]
**Target Conformance Level:** [AA / AAA]
**WCAG Version:** [2.1 / 2.2]
**Test Methods:** [automated tools used, AT combinations tested]
**Audit Date:** [date]

---

## Conformance Declaration

**Overall Conformance:** [Passes AA / Partially Conforms / Does Not Conform]

[If partial or non-conforming: brief statement of which criteria fail and their impact]

---

## Summary Counts

| Level | Total Criteria | Pass | Fail | N/A |
|-------|---------------|------|------|-----|
| A | [#] | [#] | [#] | [#] |
| AA | [#] | [#] | [#] | [#] |
| AAA (if audited) | [#] | [#] | [#] | [#] |

---

## Failures by Principle

### Perceivable
**[SC Number] [SC Name] ([Level])**
Issue: [What is failing]
Location: [Where in the product]
Impact: [Who is affected and how]
> Fix: [Specific remediation]

[Repeat per failure]

### Operable
[Same format]

### Understandable
[Same format]

### Robust
[Same format]

---

## Priority Remediation

**Critical — Blocks access entirely (address immediately):**
1.
2.

**High — Significantly impairs use for AT users:**
1.
2.

**Medium — Meaningful barrier for specific user groups:**
1.

**Low — Enhancement to improve experience:**
1.

---

## Automated Scan Summary

[Tool used, date run, number of violations detected, key categories flagged]

---

## Manual Testing Notes

[AT combinations used, key observations, anything automated testing missed]

---

## Recommended Follow-Up

[Next testing cycle, additional pages to audit, AT combinations not yet tested, user research recommendations]
```

---

## WCAG 2.2 Delta — New Criteria

For teams already at WCAG 2.1 AA compliance, these are the 9 new criteria in WCAG 2.2 to audit:

| SC | Level | What's New |
|----|-------|-----------|
| 2.4.11 Focus Not Obscured (Minimum) | AA | Focused element not entirely hidden by sticky content |
| 2.4.12 Focus Not Obscured (Enhanced) | AAA | Focused element fully visible |
| 2.4.13 Focus Appearance | AAA | Focus indicator size and contrast requirements |
| 2.5.7 Dragging Movements | AA | Drag interactions have single-pointer alternatives |
| 2.5.8 Target Size (Minimum) | AA | 24×24px minimum touch targets |
| 3.2.6 Consistent Help | A | Help mechanisms in consistent location |
| 3.3.7 Redundant Entry | A | Previously-entered information is auto-populated |
| 3.3.8 Accessible Authentication (Minimum) | AA | No cognitive tests without alternatives |
| 3.3.9 Accessible Authentication (Enhanced) | AAA | No cognitive tests required |

Note: 4.1.1 Parsing (A) was removed in WCAG 2.2 — it passes by default.

---

## Reference Framework

This skill implements the full WCAG 2.1 and 2.2 success criteria per the W3C Web Content Accessibility Guidelines specification. Grounded in Matthew Stephens' accessibility practice, which holds that:

- Accessibility is infrastructure — build it in, don't bolt it on
- Automated testing catches 30–40% of issues; manual testing is required for real conformance
- The business case for accessibility has never been stronger — AI agents are the new screen readers
- WCAG compliance is a floor, not a ceiling — meet it, then go further
