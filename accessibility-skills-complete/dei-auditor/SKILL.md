---
name: dei-auditor
description: Audit prototypes, products, and digital experiences for DEI and inclusive design — evaluating representation, language, user modeling assumptions, cultural bias, and systemic exclusion patterns. Use this skill whenever someone wants to evaluate how inclusive a product is, check for representation gaps, audit content or imagery for bias, review personas or user models for default assumptions, or assess whether a product serves users across race, gender, age, ability, culture, and socioeconomic background. Trigger on phrases like DEI audit, inclusive design review, representation audit, bias in design, is this product inclusive, diversity check, cultural sensitivity review, who are we excluding, default user assumptions, inclusive UX, gender-inclusive design, or any request to evaluate whether a product truly serves a diverse user base. Always use this skill — do not attempt a DEI or inclusive design audit without it.
---

# DEI / Inclusive Design Auditor

Evaluate products and prototypes for who they serve — and who they don't. Inclusive design is not a feature or a checklist. It is the practice of questioning every assumption your team baked in about who the "default user" is, and then designing for the full range of human experience.

A product that works for your team but not for people different from your team is not a good product. It is a product that reflects the unchecked assumptions of the people who built it.

---

## The 7 Dimensions of Inclusive Design

| # | Dimension | Core Test |
|---|-----------|-----------|
| 1 | Representation | Do the people in your product — images, characters, names, examples — reflect the actual diversity of humanity? |
| 2 | Language & Tone | Is your copy free of gendered defaults, ableist language, culturally Western assumptions, and exclusionary idiom? |
| 3 | User Model Assumptions | Who did you assume your user was when making design decisions? Whose context, literacy, device, and bandwidth did you optimize for? |
| 4 | Socioeconomic Inclusion | Does the product require a high-end device, fast internet, credit card, formal address, or financial buffer to use? |
| 5 | Cultural & Regional Sensitivity | Does the product handle names, dates, addresses, currencies, colors, and idioms in ways that work globally, not just for Western markets? |
| 6 | Gender & Identity | Does the product handle gender respectfully, avoid binary-only assumptions, and allow for self-identification? |
| 7 | Systemic Exclusion Patterns | Are there features, flows, or mechanics that structurally disadvantage specific groups — even unintentionally? |

---

## Scoring

Score each dimension 0–10. All dimensions weighted equally (approx 14.3% each).

Overall Inclusive Design Score = average of all 7 × 10

| Score | Grade | Meaning |
|-------|-------|---------|
| 85–100 | A | Genuinely inclusive — designed for the full range of users |
| 70–84 | B | Strong foundation with specific gaps |
| 55–69 | C | Default assumptions present but addressable |
| 40–54 | D | Significant exclusion patterns — meaningful redesign needed |
| 0–39 | F | Actively excludes large segments of the population |

---

## Audit Process

### Step 1 — Identify the Assumed Default User

Before scoring, answer:
- Who was imagined as the primary user during design?
- What device, internet speed, literacy level, and language did the team design for by default?
- What body, gender, age, ethnicity, and socioeconomic situation did the team assume?
- Were any of these assumptions ever explicitly questioned?

Write these out. They are the root cause of most inclusive design failures.

### Step 2 — Score Each Dimension

For each dimension, assign 0–10, list findings with severity, and write specific action items.

**Severity Tags:**
- CRITICAL — Actively harmful or exclusionary to a specific group
- MAJOR — Significantly limits usability or belonging for a meaningful user segment
- MINOR — Improvement opportunity that would meaningfully expand inclusion

### Step 3 — Exclusion Pattern Check

Explicitly flag these known systemic patterns if present:

**Gendered Defaults**
Binary-only gender fields. He/him assumed as default. Female-coded roles (nurse, assistant) vs. male-coded roles (engineer, CEO) in examples or illustrations.

**Western/US-Centric Assumptions**
Phone number formats that reject international numbers. Address forms that require a state/ZIP. Date formats that aren't localized. Dollar signs as the only currency symbol. Colloquialisms that don't translate.

**Whiteness as Default**
Stock photography that defaults to white faces. Skin tone options in avatars or emoji that treat light skin as "standard." Names in examples (John, Sarah) that signal a specific cultural context.

**Able-Bodied Defaults**
Interactions designed only for two-handed use. Hover states as the only way to access information. Audio-only feedback with no visual equivalent. See the full accessibility audit skill suite for comprehensive coverage.

**High-Income Defaults**
Requiring a credit card to sign up for a free product. Requiring a residential address or phone number. Designing only for high-end devices or fast connections. No low-bandwidth or offline mode for connectivity-limited users.

**Age Defaults**
Assuming digital fluency. Small touch targets designed for precise motor control. Jargon or references that exclude older or younger users.

---

## Dimension Reference Guide

### 1. Representation
Representation in digital products communicates who belongs and who is an afterthought. This is true in images, illustrations, names used in examples, characters, and whose stories get told.

Audit questions:
- Do images and illustrations show people of multiple ethnicities, body types, ages, and abilities?
- Are characters in examples named with diverse names, not just Western defaults?
- Are the scenarios depicted in onboarding and marketing ones that multiple types of users can see themselves in?
- Is diversity shown incidentally (just people being people) or only in explicitly diversity-themed content?

### 2. Language & Tone
Language encodes assumptions. Ableist idioms ("tone-deaf," "blind spot," "falls on deaf ears") normalize exclusion. Gendered defaults ("hey guys," masculine pronouns as neutral) exclude. Formal language requirements exclude users for whom English is a second language or whose literacy is lower.

Audit questions:
- Does the product use gender-neutral language by default?
- Are there ableist idioms or metaphors in the copy?
- What reading level is the copy written at? Is that appropriate for the user base?
- Does the language assume a shared cultural context (American holidays, Western idioms)?

### 3. User Model Assumptions
Every product embeds a theory of who the user is. When that theory is never questioned, it reflects whoever was in the room when decisions were made — usually a small, homogeneous group.

Audit questions:
- What device is assumed? Is the experience degraded on mid-range Android phones?
- What connectivity is assumed? Does the product fail or slow dramatically on 3G?
- What digital literacy is assumed? Are there interactions that require prior experience with specific UI patterns?
- What language proficiency is assumed?

### 4. Socioeconomic Inclusion
Many products create invisible barriers that exclude users who don't have the same financial resources as the team that built them.

Audit questions:
- Can users access core functionality without a credit card?
- Is a residential address required for features that don't need it?
- Does the product require purchasing a device that a significant portion of the target population can't afford?
- Are there paywalls that disproportionately affect lower-income users?

### 5. Cultural & Regional Sensitivity
Designing for a global audience means questioning every default format, color association, and assumed context.

Audit questions:
- Are date and time formats localized or configurable?
- Does the address form work for international addresses (no mandatory state/ZIP for non-US)?
- Are phone number fields E.164-compatible?
- Do color choices carry unintended meaning in other cultures (red = danger in US; red = luck in China)?
- Are idioms in the copy translatable?

### 6. Gender & Identity
Binary gender assumptions in product design erase non-binary, transgender, and gender-nonconforming users. This is not a fringe concern — it affects a meaningful and growing portion of every user base.

Audit questions:
- Does the product require gender selection? If so, does it offer options beyond male/female?
- Are titles (Mr./Ms./Mrs.) required, or can they be omitted?
- Does the product use gendered language when referring to the user?
- Are names stored and displayed flexibly (chosen name vs. legal name)?

### 7. Systemic Exclusion Patterns
Some exclusions aren't in any single design decision — they emerge from the combination of many reasonable-seeming choices that together create a barrier for specific groups.

Audit questions:
- Is there a flow that requires a feature unavailable in certain countries?
- Does the verification or trust system disadvantage people without formal IDs, established credit, or stable addresses?
- Do recommendation algorithms or personalization systems risk encoding bias?
- Are there flows that assume family structures, relationship types, or living situations that not all users share?

---

## Output Format

```
# DEI / Inclusive Design Audit Report

**Product / Feature:** [name]
**Assumed Default User (identified):** [description of who the team designed for]
**Audit Date:** [date]

---

## Overall Inclusive Design Score: [X/100] — [Grade]

[1–2 sentence summary]

---

## Dimension Scores

| Dimension | Score | Finding Summary |
|-----------|-------|----------------|
| Representation | X/10 | |
| Language & Tone | X/10 | |
| User Model Assumptions | X/10 | |
| Socioeconomic Inclusion | X/10 | |
| Cultural & Regional Sensitivity | X/10 | |
| Gender & Identity | X/10 | |
| Systemic Exclusion Patterns | X/10 | |

---

## Exclusion Patterns Detected

[If none: "No systemic exclusion patterns detected."]
[If present: name each with severity and action]

---

## Findings & Action Items

### [Dimension] — [X/10]

**[CRITICAL/MAJOR/MINOR]** [Finding]
> Action: [Specific fix]

---

## Who This Product Is Currently Built For

[Honest characterization of the implicit user this product serves well]

## Who This Product Is Currently Missing

[Honest characterization of the users this product fails or excludes]

---

## Top 5 Priority Fixes

1.
2.
3.
4.
5.
```

---

## Reference Framework

Grounded in Matthew Stephens' practice of ethical, inclusive design, which holds that:

- Accessible design and inclusive design are complements, not the same thing — accessibility addresses barriers for disabled users; inclusive design addresses the full range of human diversity
- Representation matters because products communicate who belongs
- The default user is always a design choice — and usually an unchecked one
- Harm doesn't require bad intent — it only requires a failure to question assumptions
- Designing for the margins makes the product better for everyone
