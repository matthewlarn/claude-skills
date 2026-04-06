# I Built 33 Claude Skills to Fix the "Vibe Design" Accessibility Gap

**Why AI-generated prototypes are almost never accessible by default, and how I built a system to codify the manual fixes**

I've been vibe designing for months now, and one thing I've noticed is that the default outputs of these models are almost never accessible by default.

There is always something: tiny text that is hard to read, inaccessible contrast ratios, or zero keyboard support. The prototypes look great at a glance, but they fail the moment you look under the hood. As I set out to improve the prototypes I was building for my clients, I started saving my manual fixes as I went.

Eventually, those fixes became a suite of 33 Claude skills designed to close the gap between a "cool demo" and a usable product.

## The 70% Coverage Gap

Automated scanners like Lighthouse, axe, and WAVE are essential, but they have a structural ceiling. They can only programmatically test about 30% of WCAG success criteria. The rest still depends on human judgment, context, and lived experience.

A scanner can tell you if alt text is missing. It cannot tell you whether that alt text gives a blind user the information they actually need in that moment. It can verify that a user can technically tab to every element, but it cannot tell you whether the focus order feels coherent to someone navigating with a screen reader.

That 70% gap is where most accessibility work actually lives. This suite picks up exactly where the automated tools stop.

## Think of It Like a Small Accessibility Agency

The easiest way to understand this suite is not as a checklist, but as a team. Each skill has a specific area of expertise. Some are specialists that go deep on a single domain. Others are audience advocates who ask "does this work for *this* kind of person?" And one acts as the Orchestrator, routing work across the right specialists and synthesizing findings into a single report.

The suite is organized into six workflow stages that mirror how accessibility work actually happens in practice. You scope the work, audit it, consider your audiences, check for ethical risks, test the fixes, and hand it off. Here's how each stage works.

## Stage 1: Strategy — Building the Case and Scoping the Work

Before you audit anything, you need to know what applies and how to get buy-in.

**Accessibility Advisor** handles the business side. It frames maturity assessments, builds remediation roadmaps, handles stakeholder objections ("we don't have the budget," "our users don't need this"), and connects accessibility to the language leadership actually responds to: legal risk, market size, and competitive advantage.

**WCAG Checklist** generates scoped checklists by product type. Instead of dumping all 86 WCAG 2.2 criteria on a team regardless of context, it asks what you're building and gives you the criteria that actually apply, with effort estimates and severity ratings for each one.

**Futures Wheel** keeps teams from stopping at the obvious fix. It maps first-, second-, and third-order consequences so you can see how an accessibility decision will ripple through the product, the workflow, and the people using it.

## Stage 2: Audit — The Specialist Skills

This is the core of the suite — 18 skills that cover every dimension of accessibility, from design to code to content to compliance.

**The Orchestrator: Full Accessibility Audit.** This is the system-level intelligence layer. You can give it a design, code, screenshot, or form flow, and it decides which specialists are relevant. A copy-heavy landing page triggers the Copy and Cognitive specialists. A complex dashboard triggers Forms, Code, Keyboard, and Contrast. The output is a single structured report with severity ratings, WCAG references, and a phased remediation roadmap. The hard rule: it never claims "full compliance" without real manual AT testing. False confidence is dangerous.

**Design Layer (Accessibility Audit)** focuses on screenshots and Figma files before code even exists. It catches contrast failures, heading hierarchy, and touch target sizing early — which is when they are cheapest to fix.

**Code Layer (Accessibility Code)** reviews HTML, CSS, React, Vue, and Svelte for semantic structure and ARIA misuse. It distinguishes between code that is technically "valid" and code that is actually "correct" for the interaction pattern. It includes automated testing integration patterns for axe-core and jest-axe, so the fixes stick.

**Standards Compliance (WCAG Compliance Auditor)** does the criterion-by-criterion audit against all 86 WCAG 2.2 success criteria, with severity ratings, effort estimates, and business impact narratives. This is the skill you need for conformance declarations and VPAT preparation.

**Content and Cognitive Load (Accessibility Copy)** is one of the most under-reviewed parts of accessibility. A button that says "Submit" technically works, but a button that says "Submit Application" reduces uncertainty. This skill reviews microcopy, ARIA labels, error messages, and reading complexity for users with ADHD, dyslexia, or anxiety.

**Cognitive Accessibility** goes deeper on cognitive load: working memory demands, decision fatigue, consistency patterns, notification overload, and the dark patterns that exploit cognitive vulnerabilities. It scores against WCAG AAA criteria and the W3C's Cognitive and Learning Disabilities Accessibility (COGA) supplemental guidance.

**Component and Interaction Specialists.** The suite includes dedicated specialists for the patterns that break most often: **Accessible Forms** covers labels, validation timing, error recovery, multi-step flows, and date pickers. **Accessible Tables** handles complex headers, responsive strategies, and data grids. **Contrast Checker** does luminance math across all states including hover, focus, disabled, and dark mode, with APCA as a secondary reference. **Alt Text Generator** writes context-aware descriptions that distinguish decorative from informative from functional images. **Keyboard & Focus Auditor** covers tab order, focus traps, roving tabindex, and Windows High Contrast Mode. **Motion Auditor** tests seizure thresholds, vestibular harm, and prefers-reduced-motion implementation. **Mobile & Touch Auditor** handles touch targets, gesture alternatives, and platform-specific VoiceOver and TalkBack testing.

**Document and Media Specialists.** **PDF Document Accessibility** audits tagged PDF structure and remediation workflows. **Video & Media Accessibility** covers captions, transcripts, audio description writing, and accessible media player controls. **Disability Testing** provides 11 disability-specific profiles with simulation tools and guidance on recruiting disabled testers.

**Prototype and system reviewers.** **Design Review Cowork** gives a multi-perspective critique of prototypes with readiness scoring, Ship/No Ship guidance, and actionable fixes. **Design System Drift** looks for accessibility regressions in tokens, components, and implementation so the system stays coherent as it scales.

## Stage 3: Audience — Who Are You Building For?

These skills add audience-specific lenses on top of the core audit. The same product can score differently depending on who is using it.

**Older Audiences Auditor** evaluates across three age bands (50–65, 65–80, 80+), accounting for the real physiological changes that come with aging: presbyopia, reduced contrast sensitivity, slower processing speed, and the trust deficit that comes from decades of being burned by bad technology.

**Kids UX Auditor** scores across age-appropriateness, safety, accessibility, and caregiver integration. It includes COPPA compliance checks and explicit detection of dark patterns aimed at children: variable reward loops, fake urgency, social pressure mechanics, and hidden subscription costs.

**DEI / Inclusive Design Auditor** asks the question most teams skip: who did you assume your user was when you made these design decisions? It audits representation, language, user model assumptions, socioeconomic barriers, and systemic exclusion patterns.

## Stage 4: Ethics — Responsible Product Design

Accessibility is one dimension of building products that don't cause harm. These skills extend the suite into adjacent ethical territory.

**AI Transparency Auditor** evaluates AI-powered features across six dimensions: disclosure, explainability, consent, bias and fairness, human oversight, and failure transparency. It includes EU AI Act risk classification references and specific patterns for detecting undisclosed AI, consent laundering, and feedback loop bias.

**Privacy-First Design Auditor** audits data minimization, consent flows, third-party SDKs, and cookie patterns against GDPR, CCPA, and emerging state-level regulation. It treats privacy as a trust contract, not a compliance checkbox.

**Black Mirror Auditor** pressure-tests worst-case futures and unintended-harm scenarios so teams can see where a product could go off the rails. **Gamification Auditor** evaluates engagement mechanics for manipulation, addiction patterns, and dark-pattern risk.

## Stage 5: Test — Making the Findings Stick

Auditing is only useful if someone verifies the fixes. This stage has three skills that cover planning, browser-level verification, and assistive technology scripting.

**Playwright Accessibility Auditor** is the most practical addition to the suite. While everything else works from source material, this works from what actually renders in the browser. It captures the UI across desktop, tablet, and mobile viewports, in both light and dark mode, at 200% and 400% zoom. It runs axe-core against the live DOM, smoke-tests keyboard navigation by tabbing through the page and capturing focus at every stop, and verifies that prefers-reduced-motion is properly respected. This combination matters because a scanner might catch missing semantics, but a screenshot can reveal a focus ring that technically exists but is visually unusable at mobile width, or a layout that collapses into an illegible mess at 200% zoom. For fast prototype testing, this is usually the best place to start.

**A11y Test Plan** generates QA-ready test plans with a prioritized assistive technology and browser matrix, effort estimates per test category, regression testing triggers, and CI/CD integration examples for axe-core and pa11y.

**Screen Reader Scripting** writes executable test scripts for NVDA, JAWS, VoiceOver, and TalkBack — documenting the exact keystrokes, expected announcements, and pass/fail criteria so a QA engineer can run the tests without being a screen reader expert.

## Stage 6: Handoff — Bridging Design and Engineering

**Accessibility Annotations** produces the annotation content that goes into Figma files or design specs for developer handoff: focus order numbers, ARIA roles and labels, landmark regions, heading levels, keyboard behavior specs, and interaction state documentation. This is the skill that prevents the "the design was accessible, but the developer didn't know what to build" failure mode.

**Design Handoff** turns the audit and fix work into polished handoff documentation so the team can move from findings to implementation without losing context.

## What the Skills Still Can't Replace

These skills do not replace real assistive technology testing or research with disabled users. They do not make the leadership decisions required to prioritize this work. They do not catch every issue — nothing does.

What they do is lower the barrier to entry. They codify the judgment calls that experienced accessibility practitioners make intuitively, so that the floor of every prototype is higher before it ever reaches a human reviewer.

The goal is not perfection. The goal is that your vibe designs aren't just pretty — they're actually built for everyone.
