---
name: ai-transparency-auditor
description: Audit AI-powered features and products for transparency, explainability, consent, bias risk, and human oversight — producing a scored report with specific fixes. Use this skill whenever someone needs to evaluate an AI feature before shipping, check if an AI product is honest with users about what it is and how it works, audit for model bias or fairness concerns, review consent flows for AI data use, or ensure human override paths exist for high-stakes AI decisions. Trigger on phrases like AI transparency audit, AI ethics review, is this AI feature ethical, explainability audit, AI bias check, AI consent review, does this disclose AI use, AI fairness audit, human oversight review, AI accountability, labeling AI content, or any request to evaluate whether an AI-powered product is honest, fair, and safe. Always use this skill — do not attempt an AI transparency audit without it.
---

# AI Transparency Auditor

Evaluate AI-powered features and products against a framework of transparency, fairness, consent, and human control. AI amplifies everything — including harm. A bias in a recommendation system at scale is not a bug. It is a policy. This skill surfaces the gaps before they ship.

Judgment — not prompting — is the critical skill in the AI era. This audit applies that judgment to AI product decisions.

---

## The 6 Dimensions of AI Transparency

| # | Dimension | Core Test |
|---|-----------|-----------|
| 1 | Disclosure | Do users know when they are interacting with AI-generated or AI-influenced content, decisions, or responses? |
| 2 | Explainability | Can the system explain its outputs in terms users can understand and act on? |
| 3 | Consent & Data Use | Have users meaningfully consented to their data being used for AI training, personalization, or inference? |
| 4 | Bias & Fairness | Does the AI system perform equitably across demographic groups? Who was underrepresented in training? |
| 5 | Human Oversight | Are there meaningful human override paths for high-stakes AI decisions? Can users contest outputs? |
| 6 | Failure Transparency | Does the system communicate clearly when it is uncertain, wrong, or operating outside its competence? |

---

## Scoring

Score each dimension 0–10. Weighted as shown.

| Dimension | Weight |
|-----------|--------|
| Disclosure | 20% |
| Explainability | 15% |
| Consent & Data Use | 20% |
| Bias & Fairness | 20% |
| Human Oversight | 15% |
| Failure Transparency | 10% |

Overall Score = sum of (score × weight) × 10

| Score | Grade | Meaning |
|-------|-------|---------|
| 85–100 | A | Accountable AI — honest, fair, user-controlled |
| 70–84 | B | Responsible foundation with gaps to close |
| 55–69 | C | Technically functional but ethically underbuilt |
| 40–54 | D | Significant trust and accountability failures |
| 0–39 | F | Deploying AI in ways that will cause harm |

---

## Audit Process

### Step 1 — Map the AI Surface

Before scoring, identify:
- Every place AI is used in the product (generation, classification, ranking, recommendation, personalization, moderation, synthesis)
- What data trains or informs each AI component
- What decisions the AI makes, and what the stakes of those decisions are
- Whether users know AI is involved at each touchpoint
- What happens when the AI is wrong

### Step 2 — Score Each Dimension

For each dimension, assign 0–10, list findings with severity, and write specific action items.

**Severity Tags:**
- CRITICAL — Active harm risk, regulatory exposure (EU AI Act, emerging US regulation), or fundamental breach of user trust
- MAJOR — Meaningfully undermines fairness, honesty, or user agency
- MINOR — Improvement opportunity that would strengthen trust and accountability

### Step 3 — AI-Specific Risk Flag Check

Explicitly check for and flag these patterns:

**Undisclosed AI**
Users are interacting with AI-generated content, AI-made decisions, or AI-influenced recommendations without knowing it. This includes AI-written copy presented as human, AI-scored applications, and AI-ranked feeds with no disclosure.

**Consent Laundering**
AI data use consent is buried in Terms of Service rather than asked for specifically at the point of data collection or use. Users technically consented but could not have meaningfully done so.

**Feedback Loop Bias**
The AI trains on its own outputs or on user behavior shaped by its prior recommendations, encoding and amplifying existing biases over time.

**Opaque High-Stakes Decisions**
AI makes or significantly influences decisions that affect access to services, opportunities, or resources (credit, hiring, content moderation, healthcare) with no explanation or appeal path.

**Confidence Theater**
The system presents outputs with apparent certainty when underlying confidence is low. No uncertainty communication. No "I don't know."

**Demographic Performance Gaps**
The system performs measurably worse for specific demographic groups — accuracy, relevance, safety, or experience quality — without disclosure or mitigation.

---

## Dimension Reference Guide

### 1. Disclosure
Users have a right to know when AI is shaping what they see, hear, or receive. This is not about labeling every spell-check suggestion. It is about meaningful touchpoints where AI materially affects the user's experience or outcomes.

Audit questions:
- Is AI-generated content clearly labeled at the point of consumption?
- Do users know when a recommendation, ranking, or decision is AI-driven?
- Is the disclosure specific ("this summary was generated by AI") or vague ("we use AI to improve your experience")?
- Does disclosure happen at the moment it's relevant, not just in a privacy policy?

### 2. Explainability
Users should be able to understand why AI made a decision that affected them, in terms they can act on. "Our algorithm decided" is not an explanation.

Audit questions:
- Can the system explain its outputs at the user level ("you were recommended this because...")?
- For high-stakes decisions, can users receive a human-readable rationale?
- Are explanations useful for contesting or improving outcomes, or just performative?
- Is explainability available to the user, or only to developers?

### 3. Consent & Data Use
AI consent must be specific, informed, and separate from general ToS agreement. "By using this product you agree to our AI training" buried in 40 pages of legal text is not consent.

Audit questions:
- Is there a specific, plain-language consent moment for AI data use?
- Can users opt out of AI personalization without losing core functionality?
- Can users opt out of their data being used for model training?
- If user data trains the model, is that disclosed at the point of data collection?
- Is consent revocable, and is the revocation path as easy as consent?

### 4. Bias & Fairness
AI systems reflect the data they were trained on and the objectives they were optimized for. When training data underrepresents certain groups, or when optimization objectives proxy for demographic characteristics, the result is a system that treats people unequally.

Audit questions:
- Has the model been tested for performance differences across demographic groups?
- Was the training dataset audited for representation gaps?
- Does the system's optimization objective (engagement, clicks, conversions) correlate with demographic characteristics in ways that produce disparate outcomes?
- Is there ongoing monitoring for bias drift post-launch?
- For AI that generates images or text: does it reproduce harmful stereotypes or exhibit demographic skew?

### 5. Human Oversight
The higher the stakes of an AI decision, the more important it is that a human can review, override, and correct it. This is not a temporary limitation — it is a permanent design principle.

Audit questions:
- For high-stakes AI decisions (content moderation, financial, medical, hiring-adjacent): is there a human review path?
- Can users flag or contest AI outputs?
- Is there a documented escalation path when AI behavior causes harm?
- Are there hard-coded human checkpoints for irreversible AI actions?
- Is the human review path real or performative (i.e., does it actually change outcomes)?

### 6. Failure Transparency
AI systems fail in ways that are often invisible to users. Confident-sounding wrong answers. Silent personalization failures. Model drift that degrades performance over time. Honest AI communicates uncertainty and failure.

Audit questions:
- Does the system communicate uncertainty when confidence is low?
- Are there graceful degradation paths when AI fails or is unavailable?
- Is there a mechanism to detect and communicate model performance degradation post-launch?
- Does the system avoid presenting hallucinated or low-confidence outputs as authoritative?

---

## Output Format

```
# AI Transparency Audit Report

**Product / Feature:** [name]
**AI Components Identified:** [list of AI touchpoints]
**Highest-Stakes AI Decision:** [what AI decision has the most impact on users]
**Audit Date:** [date]

---

## Overall AI Transparency Score: [X/100] — [Grade]

[1–2 sentence summary]

---

## Dimension Scores

| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|---------|
| Disclosure | X/10 | 20% | X.X |
| Explainability | X/10 | 15% | X.X |
| Consent & Data Use | X/10 | 20% | X.X |
| Bias & Fairness | X/10 | 20% | X.X |
| Human Oversight | X/10 | 15% | X.X |
| Failure Transparency | X/10 | 10% | X.X |
| **Total** | | | **X.X / 10** |

---

## AI Risk Flags Detected

[If none: "No AI-specific risk flags detected."]
[If present: name each with severity and action item]

---

## Findings & Action Items

### [Dimension] — [X/10]

**[CRITICAL/MAJOR/MINOR]** [Finding]
> Action: [Specific fix]

---

## Top 5 Priority Fixes

1.
2.
3.
4.
5.

---

## The Accountability Question

[One paragraph answering: if this AI system causes harm, who is accountable and what is the path to redress? This question surfaces whether accountability has been designed in or assumed away.]
```

---

## Reference Framework

Grounded in Matthew Stephens' ethical AI practice, which holds that:

- Judgment — not prompting — is the critical skill in the AI era
- AI without consent becomes manipulation
- A bias at scale is not a bug — it is a policy, and it needs to be treated as one
- Transparency is not a disclaimer — it is a design feature
- Human oversight is a permanent design principle, not a temporary limitation while AI matures
- The EU AI Act (2024) and emerging US AI regulation are hardening these principles into legal obligations — building to them now is cheaper than retrofitting later
