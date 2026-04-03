# Accessibility Skills Suite

27 production-grade accessibility skills organized by workflow stage.

## Folder Structure

```
strategy/     → Scoping, business case, maturity assessment
audit/        → Core accessibility audit skills (design, code, content, standards)
audience/     → Audience-specific lenses (older adults, children, DEI)
ethics/       → Responsible product design (AI transparency, privacy)
test/         → Testing artifacts and QA planning
handoff/      → Design-to-dev documentation
```

## Skills by Category

### strategy/ (2 skills)
| Skill | Purpose |
|-------|---------|
| accessibility-advisor | Business case, maturity assessment, stakeholder communication, remediation roadmaps |
| wcag-checklist | Scoped WCAG 2.2 checklists by product type with effort/severity ratings |

### audit/ (16 skills)
| Skill | Purpose |
|-------|---------|
| full-accessibility-audit | **Orchestrator** — coordinates all audit skills into unified report |
| accessibility-audit | Design layer — visual, layout, interactive, content review |
| accessibility-code | Code layer — semantic HTML, ARIA, keyboard, React/Vue/Svelte |
| wcag-compliance-auditor | Criterion-by-criterion WCAG 2.2 compliance audit |
| contrast-checker | Color contrast ratios (WCAG 2.x + APCA), palette audits |
| keyboard-focus-auditor | Tab order, focus indicators, focus traps, skip links |
| motion-auditor | Animation harm (seizure, vestibular, cognitive), prefers-reduced-motion |
| cognitive-accessibility | Cognitive load, plain language, consistency, COGA guidance |
| mobile-touch-auditor | Touch targets, gestures, VoiceOver/TalkBack, responsive |
| accessible-forms | Labels, validation, error handling, multi-step, date pickers |
| accessible-tables | Simple/complex tables, responsive strategies, data grids |
| alt-text-generator | Context-aware alt text, classification, long descriptions |
| accessibility-copy | Microcopy, ARIA labels, error messages, plain language |
| pdf-document-accessibility | PDF/UA, tagged PDF, remediation workflows |
| video-media-accessibility | Captions, transcripts, audio description, media players |
| disability-testing | 11 disability profiles, simulation tools, tester recruitment |

### audience/ (3 skills)
| Skill | Purpose |
|-------|---------|
| older-audiences-auditor | Vision, cognition, motor, hearing, trust for 50+ users (3 age bands) |
| kids-ux-auditor | Age-appropriateness, safety, COPPA, caregiver integration |
| dei-auditor | Representation, language, user model assumptions, systemic exclusion |

### ethics/ (2 skills)
| Skill | Purpose |
|-------|---------|
| ai-transparency-auditor | Disclosure, explainability, consent, bias, human oversight |
| privacy-first-auditor | Data minimization, consent, GDPR/CCPA, cookie audit, SDK audit |

### test/ (3 skills)
| Skill | Purpose |
|-------|---------|
| a11y-test-plan | QA test plans, AT+browser matrix, CI/CD integration, effort estimates |
| screen-reader-scripting | NVDA/JAWS/VoiceOver/TalkBack test scripts with expected announcements |
| playwright-accessibility-auditor | Browser-level testing — axe-core scans, multi-viewport screenshots, keyboard smoke tests, zoom/reflow, dark mode |

### handoff/ (1 skill)
| Skill | Purpose |
|-------|---------|
| accessibility-annotations | Focus order, ARIA roles, landmark regions, keyboard behavior specs |

## Recommended Workflow

1. **Strategy** → Run accessibility-advisor to assess maturity and build the business case. Use wcag-checklist to scope what applies.
2. **Audit** → Run full-accessibility-audit to orchestrate a comprehensive review, or run individual audit skills for targeted assessment.
3. **Audience** → Layer on audience-specific lenses based on your user base.
4. **Ethics** → Apply ai-transparency-auditor and privacy-first-auditor for AI-powered or data-intensive products.
5. **Test** → Generate test plans and screen reader scripts for QA teams.
6. **Handoff** → Produce accessibility annotations for design-to-dev handoff.

## Conventions

All skills use consistent severity tags: **CRITICAL** (active harm/legal exposure), **MAJOR** (meaningfully undermines accessibility), **MINOR** (improvement opportunity). Scoring skills use 0-10 per dimension with weighted A-F grades.
