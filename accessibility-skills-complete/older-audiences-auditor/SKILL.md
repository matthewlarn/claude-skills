---
name: older-audiences-auditor
description: Audit prototypes, apps, and digital products for how well they serve users aged 50 and older — scoring across vision, cognition, motor control, hearing, trust, and content clarity, with specific age-informed fixes. Use this skill whenever someone needs to evaluate a product for older user audiences, check if a design accommodates age-related physical or cognitive changes, audit typography and touch targets for older adults, or ensure a product isn't inadvertently excluding users over 50. Trigger on phrases like older audiences audit, designing for seniors, older adults UX, age-inclusive design, 50+ users, elder UX, senior-friendly design, aging population design, older user accessibility, is this usable for older adults, or any request to evaluate how well a product serves users experiencing age-related changes. Always use this skill — do not attempt an older audiences audit without it.
---

# Older Audiences Auditor

Evaluate products and prototypes for how well they serve users aged 50 and older. By 2030, 1 in 6 people worldwide will be over 60. Designing for age-related challenges almost always improves usability for everyone — reduced vision, hearing changes, and limited dexterity mirror what any user experiences in suboptimal conditions. This is not niche design. It is good design.

Grounded in Matthew Stephens' UX Collective article "Designing for Older Audiences: Checklist + Best Practices" and the Loud + Clear Parkinson's fitness app.

---

## The 6 Audit Dimensions

| # | Dimension | What Changes With Age |
|---|-----------|----------------------|
| 1 | Vision & Typography | Lens hardening (presbyopia), reduced contrast sensitivity, slower dark adaptation, narrowing field of view, increased glare sensitivity |
| 2 | Cognition & Clarity | Slower processing speed, shorter working memory, reduced fluid reasoning, higher cognitive load sensitivity |
| 3 | Motor Control & Touch | Reduced dexterity, tremors, arthritis, less precise finger control, slower reaction time |
| 4 | Hearing & Audio | Presbycusis (age-related hearing loss), difficulty distinguishing speech from background noise, reduced high-frequency hearing |
| 5 | Trust & Error Recovery | Higher anxiety around irreversible actions, greater concern about fraud and data security, more reliance on help and confirmations |
| 6 | Content & Language | Preference for plain language, lower tolerance for jargon, different digital literacy baseline, greater reliance on familiar patterns |

---

## Scoring

Score each dimension 0–10. All dimensions weighted equally (~16.7% each).

Overall Score = average of all 6 × 10

| Score | Grade | Meaning |
|-------|-------|---------|
| 85–100 | A | Genuinely age-inclusive — serves older adults without compromising younger users |
| 70–84 | B | Mostly there with specific gaps |
| 55–69 | C | Passes casual use but creates real friction for older users |
| 40–54 | D | Significant barriers present — meaningful redesign needed |
| 0–39 | F | Actively exclusionary for users with age-related changes |

---

## Dimension Reference Guide

### 1. Vision & Typography

**What's happening physiologically:** The lens of the eye hardens, making it harder to focus on close objects. Contrast sensitivity decreases. Eyes become more sensitive to glare. The visual field may narrow slightly. Color differentiation becomes harder, especially blues and greens.

**Audit checklist:**
- [ ] Body text minimum 16px — 18–20px preferred for primary content
- [ ] Line height minimum 1.5× font size
- [ ] Letter spacing slightly looser than default (0.01–0.02em improvement for legibility)
- [ ] Typeface is a legible sans-serif — Atkinson Hyperlegible or Hyperlegible Sans preferred for products serving older audiences or low-vision users. Avoid decorative, condensed, or light-weight fonts
- [ ] Color contrast meets WCAG AA (4.5:1 normal text, 3:1 large text) — aim for AAA (7:1) for critical content
- [ ] Information is never conveyed by color alone
- [ ] No white text on light backgrounds or dark text on dark backgrounds
- [ ] Avoid light-weight type (100, 200 weight) for body content — minimum 400 weight
- [ ] Zoom to 200% does not break layout or hide content
- [ ] Dark mode available and well-implemented (reduced glare benefit for older users)
- [ ] No auto-playing video or animations with high contrast flicker

**Red flags:**
- 12–14px body text (common in "clean" modern designs)
- Very thin typeface weights
- Light gray text on white (#999 or lighter on white fails contrast)
- Information conveyed by color in charts or status indicators

### 2. Cognition & Clarity

**What's happening physiologically:** Processing speed slows with age. Working memory capacity decreases — users can hold fewer items in mind at once. Multi-step tasks become harder without clear progress indicators. Novel interface patterns require more effort to decode.

**Audit checklist:**
- [ ] One primary action per screen — avoid competing CTAs
- [ ] Progressive disclosure used for complex information (don't show everything at once)
- [ ] Clear visual hierarchy guides the eye to the most important content first
- [ ] Navigation is consistent and predictable — no surprise redirections
- [ ] Breadcrumbs or persistent navigation cues show where the user is
- [ ] Multi-step flows have visible progress indicators
- [ ] Error messages are specific and tell users exactly what to fix
- [ ] Confirmation screens present before irreversible actions
- [ ] No timed interactions that expire without warning
- [ ] No auto-advancing carousels or content that moves without user control
- [ ] Recognition over recall — labels on icons, not icons alone
- [ ] Familiar UI patterns used for familiar tasks (no novel navigation metaphors without explanation)

**Red flags:**
- Hamburger menus as the only navigation pattern
- Icon-only buttons with no labels
- Auto-advancing sliders or timers
- Long multi-step forms without save/resume
- Jargon in error messages ("Error 403: Forbidden")

### 3. Motor Control & Touch

**What's happening physiologically:** Joint changes and reduced muscle control affect fine motor precision. Arthritis is common. Tremors may be present (as in Parkinson's, which affects ~1% of adults over 60). Touchscreens require pinpoint accuracy that becomes harder with age.

**Audit checklist:**
- [ ] Touch targets minimum 44×44px — prefer 56–72px for primary actions
- [ ] Minimum 8px spacing between adjacent touch targets to prevent accidental activation
- [ ] Primary actions positioned in the lower third of the screen (thumb-reachable, lower effort)
- [ ] No interactions requiring precise drag, pinch, or multi-finger gestures as the only path
- [ ] Keyboard navigation fully supported as an alternative to touch/mouse
- [ ] Voice input supported where possible
- [ ] No double-tap or long-press as the only way to access important actions
- [ ] Swipe-to-delete or swipe-to-dismiss have a confirmation or easy undo
- [ ] Buttons are clearly shaped as buttons — not ghost/borderless styles that reduce the perceived tap area
- [ ] Sliders have numeric input alternatives
- [ ] Forms have large input fields — minimum 44px height

**Practical note from Loud + Clear:** Every tappable element was maximized in size, including buttons, inputs, and links. The motor simulator in Funkify ("Trembling Trevor" persona) was used during testing to validate that large elements were still usable with reduced dexterity.

**Red flags:**
- Small close buttons (×) on modals — especially in corners
- Tightly clustered navigation items
- Drag-only interactions (sorting lists, sliders)
- Touch targets under 44px

### 4. Hearing & Audio

**What's happening physiologically:** Presbycusis causes progressive high-frequency hearing loss. Background noise becomes harder to filter. Speech intelligibility decreases, especially at lower volumes. Many older adults use hearing aids that interact differently with device audio.

**Audit checklist:**
- [ ] All video content has accurate closed captions
- [ ] All audio-only content has a text transcript
- [ ] Captions are positioned to not obscure important visual content
- [ ] Captions can be styled/resized by the user
- [ ] No audio-only alerts or feedback — pair all audio cues with visual equivalents
- [ ] Audio controls are accessible and visible — not hidden or auto-playing
- [ ] Speech-based interfaces have a non-speech alternative
- [ ] Volume controls are accessible and prominently placed
- [ ] No sounds that autoplay on page load without warning

**Red flags:**
- Video with no captions
- Audio-only error alerts (beeps with no visual equivalent)
- Auto-playing audio on page load

### 5. Trust & Error Recovery

**What's happening culturally and psychologically:** Older adults have lived through more technology failures and scams. They are appropriately more cautious. They may be less tolerant of ambiguity about what an action will do, and more anxious about making mistakes they can't undo. They are also more likely to read help text, tooltips, and confirmation dialogs — so these actually need to be well-written.

**Audit checklist:**
- [ ] Confirmation dialogs before all destructive or irreversible actions
- [ ] Clear "undo" or "cancel" path wherever possible
- [ ] Security and trust signals present during sensitive flows (payments, data submission, account changes)
- [ ] Privacy practices explained in plain language at the point of data collection
- [ ] Help content is findable, up to date, and written in plain language
- [ ] Error messages are supportive, not alarming — no red all-caps ERRORS
- [ ] Session timeout warnings give users enough time to respond
- [ ] No dark patterns that exploit caution (fake urgency, "your account will be deleted in 24 hours")
- [ ] Contact/support options are visible and reachable without deep navigation
- [ ] Password and login flows accommodate slower typing and likely use of password managers

**Red flags:**
- Alarmist error messages ("CRITICAL ERROR — ACTION REQUIRED")
- No confirmation before account deletion or irreversible data changes
- Security badges that look like ads or pop-ups
- Trust signals buried in footer

### 6. Content & Language

**What's happening:** Older adults are not less intelligent. They are less tolerant of digital jargon they've had less time to absorb — and they're right to be. Unclear language wastes time and erodes trust. They also benefit from content chunked into manageable pieces.

**Audit checklist:**
- [ ] Reading level targets Grade 8 or below for general audiences (use Hemingway App to verify)
- [ ] No unexplained acronyms or technical jargon
- [ ] Active voice used throughout
- [ ] Sentences are short (average under 20 words)
- [ ] Content chunked with clear headings — not long unbroken paragraphs
- [ ] Instructions are numbered steps, not narrative paragraphs
- [ ] Tooltips and contextual help available for any unfamiliar term or action
- [ ] Button labels describe actions, not states ("Download your report" not "Download")
- [ ] Avoid age-biased language in copy ("easy," "simple," "even a grandparent could use it")
- [ ] Culturally appropriate idioms — no slang or pop-culture references that may not land
- [ ] Emoji and icons accompanied by text labels

---

## Testing Recommendations

### Funkify Chrome Extension
Use Funkify to simulate age-related and disability-related experiences during design review:

- **Vision simulator:** Blurs and warps content — simulates low vision and presbyopia
- **Motor simulator ("Trembling Trevor"):** Makes the pointer harder to control — simulates tremors and reduced dexterity
- **Cognition simulator:** Slows and fragments interactions — simulates cognitive load and processing speed changes
- **Color blindness simulator:** Validates color-independent communication

### How Might We framing
When Funkify sessions surface issues, frame them as HMW opportunities:
- "HMW make the 'Next' button easier to tap with reduced dexterity?"
- "HMW communicate this status without relying on the color red?"
- "HMW reduce the number of steps needed to complete this task?"

### Test with real users
Simulations are a starting point, not a substitute. Include users 55+ in usability testing — not just as accommodation, but as standard practice. Older adults who struggle with a UI are often surfacing usability problems that affect all users.

---

## Output Format

```
# Older Audiences Audit Report

**Product / Feature:** [name]
**Primary target age range:** [stated or estimated]
**Audit Date:** [date]

---

## Overall Score: [X/100] — [Grade]

[1–2 sentence summary]

---

## Dimension Scores

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Vision & Typography | X/10 | |
| Cognition & Clarity | X/10 | |
| Motor Control & Touch | X/10 | |
| Hearing & Audio | X/10 | |
| Trust & Error Recovery | X/10 | |
| Content & Language | X/10 | |

---

## Findings & Action Items

### [Dimension] — [X/10]

**[CRITICAL/MAJOR/MINOR]** [Finding]
> Action: [Specific, implementable fix]

---

## Top 5 Priority Fixes

1.
2.
3.
4.
5.

---

## What's Working

[2–4 things the product does well for older audiences]

---

## Recommended Testing Next Steps

[Specific Funkify tests, user recruitment notes, or prototype changes to validate]
```

---

## The Curb Cut Effect

Every improvement you make for older users improves the experience for everyone. Large touch targets help users on public transit. High contrast helps users in sunlight. Plain language helps users reading quickly. Captions help users in noisy environments. There is no version of this work that is "just for old people." It is just good design.

---

## Reference Framework

Grounded in Matthew Stephens' "Designing for Older Audiences: Checklist + Best Practices" (UX Collective, 2025) and the Loud + Clear Parkinson's fitness app, which holds that:

- Designing for people with age-related challenges almost always improves usability for everyone
- Older adults are not less capable — they are less tolerant of poor design, and correctly so
- Good accessibility is good design — the overlap between age-related needs and disability design is substantial
- Test with real older users — simulations are a start, not a finish
- Atkinson Hyperlegible (and Hyperlegible Sans) are the recommended typefaces for products where legibility is critical
