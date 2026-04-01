---
name: privacy-first-auditor
description: Audit prototypes, products, features, or design patterns against the 8 Principles of Privacy-First Design to surface trust failures, data overreach, and consent dark patterns — and produce a scored report with specific fixes. Use this skill whenever someone wants to evaluate a product for privacy compliance, data ethics, consent UX, or trust-building design. Trigger on phrases like "privacy audit", "privacy review", "data ethics", "GDPR check", "consent patterns", "is this privacy-first", "privacy by design", "trust audit", "data collection review", "privacy score", "are we collecting too much", "does this respect user privacy", or any request to evaluate how a product handles personal data. Always use this skill — do not attempt a privacy design audit without it.
---

# Privacy-First Design Auditor

Evaluate products and prototypes against the 8 Principles of Privacy-First Design. Produces a scored audit with specific, implementable fixes for each violation. Privacy is not a compliance checkbox — it is a trust contract with your users.

---

## The 8 Principles

These principles form the audit framework. Each maps to a scored dimension.

| # | Principle | Core Test |
|---|-----------|-----------|
| 1 | Data Minimization | Are you collecting only what is absolutely necessary? |
| 2 | Transparent Communication | Do users understand — in plain language — what's happening to their data? |
| 3 | User Control & Consent | Can users meaningfully opt in, opt out, and delete their data? |
| 4 | Security by Design | Is sensitive data protected architecturally, not bolted on? |
| 5 | Contextual Integrity | Is data being used in the context users expect, not repurposed? |
| 6 | Respect for Vulnerable Users | Are high-risk groups (children, people in crisis, marginalized communities) protected with extra care? |
| 7 | Privacy as a Value Proposition | Does the product treat privacy as a competitive asset, not a legal obligation? |
| 8 | Lean Data Lifecycle | Is there a clear, enforced policy for data retention, deletion, and expiration? |

---

## Audit Dimensions & Scoring

Score each principle 0–10. Weight as shown.

| Principle | Weight |
|-----------|--------|
| Data Minimization | 15% |
| Transparent Communication | 15% |
| User Control & Consent | 15% |
| Security by Design | 15% |
| Contextual Integrity | 15% |
| Respect for Vulnerable Users | 10% |
| Privacy as a Value Proposition | 10% |
| Lean Data Lifecycle | 5% |

Overall Score = sum of (score × weight) × 10

---

## Score Interpretation

| Score | Grade | Meaning |
|-------|-------|---------|
| 85–100 | A | Privacy-first — earns trust by design |
| 70–84 | B | Solid foundation with gaps to close |
| 55–69 | C | Compliance-minded but not user-centered |
| 40–54 | D | Significant trust liabilities present |
| 0–39 | F | Actively eroding user trust — stop and redesign |

---

## Audit Process

### Step 1 — Inventory the Data Surface

Before scoring, map out:
- Every data point the product collects (explicit and inferred)
- What each data point is used for
- Who else has access (third parties, analytics SDKs, ad networks)
- Where consent is asked for, and how
- What happens to data when a user deletes their account
- What the retention policy is (if any)

If auditing code: scan for tracking calls, third-party SDKs, cookie usage, localStorage, form field names, analytics endpoints, and any data leaving the device.

If auditing a design: look at every form, modal, onboarding screen, settings page, and notification for consent language and data-related copy.

### Step 2 — Score Each Principle

For each of the 8 principles:
1. Assign a score 0–10
2. List specific findings with severity tags (CRITICAL / MAJOR / MINOR)
3. Write a concrete, implementable action item for each finding

**Severity Definitions:**
- CRITICAL — Active legal or trust risk (GDPR/CCPA violation potential, data collection without consent, coercive design)
- MAJOR — Meaningfully undermines user trust or control
- MINOR — Improvement opportunity that would meaningfully increase trust

### Step 3 — Dark Pattern Check

Explicitly flag any of the following consent dark patterns if present:

- Pre-checked consent boxes
- "Accept all" prominent / "Manage settings" buried
- Consent bundled into Terms of Service acceptance
- Deceptive copy that frames privacy-protective options negatively ("degrade your experience")
- Withdrawal of consent made more difficult than granting it
- Repeated re-asking for consent that was previously denied
- Missing or broken "delete my account / data" flows
- Data collection that starts before consent is given

Each dark pattern is automatically CRITICAL severity.

---

## Principle Reference Guide

### 1. Data Minimization
Collect only what is absolutely necessary. Every data point you request increases risk — breach risk, regulatory risk, and trust risk. If a feature can work without personal information, don't ask for it.

Good test: Could we build this feature with less data? Could we use anonymized or aggregate data instead? Could we offer guest access?

Red flags: Email required for features that don't need it. Phone number collection without SMS use. Date of birth beyond age verification needs. Location data stored beyond the immediate request.

### 2. Transparent Communication
Users can't make informed decisions if they don't understand what's happening to their data. Transparency means plain language — not a 14-page privacy policy written for lawyers.

Good test: Could a 12-year-old read this and understand what they're agreeing to? Is there a plain-English summary? Are just-in-time disclosures shown at the moment data is collected?

Red flags: Privacy policy as the only disclosure. Vague language like "may share with trusted partners." No explanation of why specific data is needed.

### 3. User Control & Consent
Consent must be freely given, specific, informed, and revocable. Users should be able to withdraw consent as easily as they gave it, and have real control over their data.

Good test: Can users delete their account and all associated data? Can they export their data? Can they opt out of specific data uses without losing core functionality?

Red flags: No data deletion path. Consent bundled into ToS. No granular controls. Opting out removes access to core features unrelated to the data use.

### 4. Security by Design
Security is not a layer you add before launch. It is a design constraint from day one. Sensitive data should be encrypted, access should be role-limited, and breach plans should exist before any breach does.

Good test: Is sensitive data encrypted at rest and in transit? Is there a documented breach response plan? Are third-party dependencies audited for their own security posture?

Red flags: No HTTPS. Sensitive data in localStorage. Third-party SDKs with broad data access. No mention of encryption in technical documentation.

### 5. Contextual Integrity
Data should flow in ways that match user expectations. Sharing data in an unexpected context — even if technically permitted by the ToS — is a trust violation.

Good test: Would users be surprised to learn how their data is being used? Does the data use match the context in which it was collected?

Red flags: Behavioral data used for unrelated personalization. Health-adjacent data used for ad targeting. Data collected in one context reused in another without disclosure.

### 6. Respect for Vulnerable Users
Some users face higher risks from data exposure — children, people in mental health crisis, domestic abuse survivors, undocumented individuals, and other marginalized groups. Ethical design gives them extra protection, not just the same defaults.

Good test: Have you considered how this product could harm someone who is already vulnerable? Are there extra protections for minors? Does the product give users tools to protect themselves from others who might misuse their data?

Red flags: No age verification or age-appropriate data handling. No options to hide activity from household members. Mood or health data handled the same as behavioral data.

### 7. Privacy as a Value Proposition
Privacy-first design isn't just about compliance. It is a competitive differentiator and a brand promise. Companies that lead with privacy build deeper trust and long-term loyalty.

Good test: Does the product actively communicate its privacy stance as a feature? Does the business model require exploiting user data, or is there a path to sustainability without it?

Red flags: Privacy only mentioned in legal disclaimers. No privacy-positive copy in onboarding or marketing. Business model entirely dependent on selling behavioral data.

### 8. Lean Data Lifecycle
Data that isn't deleted is a liability. Clear retention policies, automated expiration, and verifiable deletion are the hygiene layer of privacy-first design.

Good test: Is there a documented retention policy? Does data expire automatically? When a user deletes their account, is deletion complete and permanent?

Red flags: No documented retention period. Deleted accounts still present in backups with no purge schedule. No confirmation mechanism for data deletion.

---

## Output Format

```
# Privacy-First Design Audit Report

**Product / Feature:** [name or description]
**Audit Date:** [date]
**Data Surface Summary:** [brief inventory of what's collected]

---

## Overall Privacy Score: [X/100] — [Grade]

[1–2 sentence summary of the product's privacy posture]

---

## Dimension Scores

| Principle | Score | Weight | Weighted |
|-----------|-------|--------|---------|
| Data Minimization | X/10 | 15% | X.X |
| Transparent Communication | X/10 | 15% | X.X |
| User Control & Consent | X/10 | 15% | X.X |
| Security by Design | X/10 | 15% | X.X |
| Contextual Integrity | X/10 | 15% | X.X |
| Respect for Vulnerable Users | X/10 | 10% | X.X |
| Privacy as a Value Proposition | X/10 | 10% | X.X |
| Lean Data Lifecycle | X/10 | 5% | X.X |
| **Total** | | | **X.X / 10** |

---

## Consent Dark Patterns Detected

[If none: "No consent dark patterns detected."]
[If present: list each with CRITICAL tag and action item]

---

## Findings & Action Items

### [Principle Name] — [X/10]

**[CRITICAL / MAJOR / MINOR]** [Finding]
> Action: [Specific, implementable fix]

---

## Top 5 Priority Fixes

1.
2.
3.
4.
5.

---

## Trust-Building Opportunities

[2–3 specific things the product could do that would actively communicate trust to users — not just avoid harm, but earn confidence]
```

---

## Reference Framework

Grounded in Matthew Stephens' 8 Principles of Privacy-First Design, which holds that:

- Privacy is a trust contract, not a compliance checkbox
- Users can't make informed decisions if they don't understand what's happening to their data
- Privacy used as a value proposition aligns the entire company with an ethical promise
- Research consistently shows users value privacy more each year and are willing to pay for it
- The goal is not just to avoid harm — it is to earn trust
