---
name: kids-ux-auditor
description: Evaluate prototypes, apps, or digital experiences for how well they work for children. Use this skill whenever the user wants to audit a product designed for kids or used by kids — including learning apps, games, entertainment tools, or any digital experience with a child audience. Trigger on phrases like "kids app audit", "children's UX", "is this good for kids", "child-safe design", "age-appropriate", "review this for children", "kids product review", "ethical kids design", "COPPA compliance check", or any request to evaluate a prototype or product against children's design standards. Always use this skill for kids-focused audits — do not attempt to evaluate child UX without it.
---

# Kids UX Auditor

Evaluate vibe-coded prototypes and digital products for how well they serve children. Produces a scored audit with specific, actionable improvement items organized by priority.

---

## What This Skill Produces

A structured audit with:
- An overall Kids UX Score (0–100)
- Scores across 7 dimension categories
- Severity-tagged findings (Critical / Major / Minor)
- Specific, copy-paste-ready action items for each issue
- An ethical flag section for dark patterns and predatory mechanics

---

## Audit Dimensions

Score each dimension 0–10. Weight them as shown to calculate the overall score.

| # | Dimension | Weight | What to Evaluate |
|---|-----------|--------|-----------------|
| 1 | Age-Appropriateness | 20% | Motor skill accommodation, reading level, cognitive load, vocabulary, age-banded design decisions |
| 2 | Safety & Ethics | 20% | No manipulative reward loops, no hidden costs, no data collection beyond necessity, no dark patterns, COPPA awareness |
| 3 | Accessibility & Inclusion | 15% | Screen reader support, color not sole communication channel, flexible pacing, sensory overload risk, diverse representation |
| 4 | Caregiver Integration | 15% | Parent/guardian dashboard clarity, co-play modes, positive limit framing, transparent controls |
| 5 | Interaction Design | 15% | Touch target sizing, forgiving taps, error recovery, undo availability, no irreversible destructive actions |
| 6 | Feedback & Delight | 10% | Clear positive feedback loops, encouraging (not punishing) tone, celebration of effort over performance |
| 7 | Learning & Autonomy | 5% | Scaffolded challenge, child agency and choice, creativity support without blank-canvas paralysis |

Overall Score = sum of (dimension score × weight)

---

## Scoring Scale

| Score | Grade | Meaning |
|-------|-------|---------|
| 90–100 | A | Exceptional — safe, joyful, inclusive |
| 75–89 | B | Good — minor improvements needed |
| 60–74 | C | Adequate — several meaningful gaps |
| 45–59 | D | Problematic — significant issues present |
| 0–44 | F | Not suitable for child audiences without major rework |

---

## Audit Process

### Step 1 — Gather Context

Before scoring, identify or ask for:
- Target age range (0–2 / 3–5 / 6–8 / 9–12 / 13–17)
- Primary use context (solo play, classroom, co-play, unsupervised home)
- Is a caregiver expected to be present?
- Is there monetization? Any UGC or social features?

If reviewing code: scan for touch targets, font sizes, ARIA labels, data collection calls, timer-based mechanics, reward loops, and navigation patterns.

If reviewing a screenshot or description: evaluate visually observable patterns against the dimensions above.

### Step 2 — Score Each Dimension

For each of the 7 dimensions:
1. Assign a score 0–10
2. List specific findings with severity tags
3. Write action items in plain, implementable language

**Severity Definitions:**
- CRITICAL — Child safety, ethics, or legal risk (data collection, manipulative dark patterns, content inappropriate for age)
- MAJOR — Meaningfully harms usability or wellbeing for child users
- MINOR — Polish and improvement opportunities

### Step 3 — Ethical Flag Check

Explicitly check for and call out the following if present:

- Variable reward / slot machine mechanics
- Fake urgency or countdown timers to pressure purchases
- Social pressure mechanics ("your friends are waiting")
- Hidden or misleading subscription flows
- Excessive data collection or third-party tracking
- Autoplay without parental opt-in
- Content or characters that prime brand loyalty or purchase intent
- Punishing or shaming failure states

Each flag is automatically CRITICAL severity.

### Step 4 — Render the Report

Use the output format below. Do not skip sections. All action items must be specific enough to implement without further clarification.

---

## Output Format

```
# Kids UX Audit Report

**Product / Prototype:** [name or description]
**Target Age Range:** [age range]
**Audit Date:** [date]

---

## Overall Score: [X/100] — [Grade]

[1–2 sentence summary of the product's child-readiness]

---

## Dimension Scores

| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|---------|
| Age-Appropriateness | X/10 | 20% | X.X |
| Safety & Ethics | X/10 | 20% | X.X |
| Accessibility & Inclusion | X/10 | 15% | X.X |
| Caregiver Integration | X/10 | 15% | X.X |
| Interaction Design | X/10 | 15% | X.X |
| Feedback & Delight | X/10 | 10% | X.X |
| Learning & Autonomy | X/10 | 5% | X.X |
| **Total** | | | **X.X / 10** |

---

## Findings & Action Items

### [Dimension Name] — [X/10]

**[CRITICAL / MAJOR / MINOR]** [Finding description]
> Action: [Specific, implementable fix]

[Repeat per finding]

---

## Ethical Flags

[If none: "No ethical flags detected."]

[If present:]
**[FLAG NAME]** — CRITICAL
[Description of the pattern found]
> Action: [How to remove or replace it]

---

## Top 5 Priority Fixes

1. [Most critical fix]
2.
3.
4.
5.

---

## What's Working

[Callout 2–4 things the prototype does well for child audiences. Balanced feedback matters.]
```

---

## Age Band Reference

Use this when evaluating age-appropriateness. The prototype should match its stated age range across all of these.

**Ages 0–2 (Toddler)**
- Large tap targets (48px+ minimum, prefer 72px+)
- No text — icons, sound, and animation only
- Immediate, satisfying audio/visual feedback
- No timed pressure
- Extremely forgiving input — no penalty for wrong taps

**Ages 3–5 (Preschool)**
- Simple, high-contrast visuals
- Voice instruction support preferred over text
- 1–2 tap interactions max per screen
- Friendly characters to guide navigation
- Celebration for any engagement, not just "correct" answers

**Ages 6–8 (Early Elementary)**
- Short words, simple sentences if text is present
- Introduce mild challenge with strong scaffolding
- Audio support still valuable
- Timed mechanics OK only if low-stakes and repeatable
- Clear undo / go-back path always available

**Ages 9–12 (Tween)**
- Can handle more complex navigation
- Peer and creative features become motivating
- Privacy becomes especially important — no social features without parental controls
- Avoid comparison mechanics that shame low performance

**Ages 13–17 (Teen)**
- Abstract reasoning is developed — nuanced interfaces OK
- Identity exploration is central — respect autonomy
- Highest risk for manipulative engagement mechanics — flag aggressively
- Strong privacy and data transparency requirements

---

## Notes on Vibe-Coded Prototypes

Vibe-coded prototypes often have:
- Hardcoded placeholder interactions that don't reflect real child input patterns
- Missing ARIA / accessibility scaffolding
- Adult-default font sizes and tap targets
- No error states or recovery flows

When auditing code, always check:
- Touch target sizes (minimum 44x44px, recommended 48–72px for under-8)
- Font sizes (minimum 16px body, 18–20px preferred for under-10)
- Color contrast ratios (4.5:1 minimum for text)
- Whether color is the only way information is communicated
- Whether any form of data collection, analytics, or third-party scripts are present
- Whether reward mechanics use variable/random reward schedules

---

## Reference Framework

This skill is grounded in Matthew Stephens' ethical framework for children's digital design, which holds that:

- Children are not small adults — cognitive, motor, and emotional development must shape every decision
- Engagement metrics like "time in app" are the wrong success criteria for children's products
- Parents and caregivers are co-users, not obstacles
- Accessible design is the baseline, not a feature
- Ethical design puts learning, safety, and joy above revenue optimization

These principles align with UNICEF's Child Rights by Design guidance, the RITEC-8 framework for children's digital play, and COPPA requirements in the US.
