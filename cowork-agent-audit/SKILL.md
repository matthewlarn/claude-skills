---
name: design-review-cowork
description: Comprehensive prototype review from multiple expert perspectives. Use this skill whenever you have a prototype (HTML, React, screenshot, or code) and need critical feedback from a Senior UX Designer, Accessibility Specialist, Frontend Engineer, and Design Critic. This skill analyzes design decisions, accessibility compliance, code quality, business impact, and user experience—then generates a detailed report with specific, actionable instructions you can use directly in Claude Code to fix issues. Trigger whenever you've built something in Claude Code and want expert-level review before shipping.
compatibility: Requires the Anthropic Batch API or ability to spawn multiple parallel analysis agents
---

# Design Review Cowork Skill

A comprehensive multi-perspective prototype analysis system that coordinates five specialized expert reviewers to evaluate your work and produce a unified report with executable fix instructions.

## Overview

This skill brings together multiple expert viewpoints on a single prototype:

1. **Senior UX Designer** - evaluates user flows, information architecture, interaction patterns, and design consistency
2. **Accessibility Specialist** - audits WCAG compliance, keyboard navigation, screen reader compatibility, motion/animation concerns
3. **Frontend Engineer** - reviews code quality, performance, browser compatibility, best practices, and maintainability
4. **Design Critic** - challenges design decisions, surface business/brand alignment, and identifies missed opportunities
5. **Orchestrator** - synthesizes all findings into a unified report with prioritized, executable fix instructions

## Inputs

The skill accepts prototypes in several formats:

- **Code-based**: React components, HTML/CSS/JS artifacts, Web Components
- **Visual**: Screenshots, Figma exports, high-fidelity mockups
- **Mixed**: Code + screenshots for side-by-side analysis

Additionally, provide context:

- **Project goal**: What this prototype is trying to accomplish
- **Target audience**: Who will use this
- **Success criteria**: How you're measuring if it works
- **Constraints**: Browser support, accessibility level, performance targets, etc.

## Output Format

The skill generates a comprehensive report with these sections:

### 1. Executive Summary
- Overall assessment (What's working, critical gaps, strategic insights)
- Priority breakdown (Critical → High → Medium → Nice-to-have)

### 2. Detailed Findings by Discipline

**UX/Design**
- Flow analysis (task completion, cognitive load)
- Visual hierarchy and consistency
- Component patterns and reusability
- Specific issues with actionable fix instructions

**Accessibility**
- WCAG level assessment (A, AA, AAA)
- Critical failures with remediation steps
- Keyboard navigation gaps
- Screen reader compatibility issues
- Motion/animation concerns

**Frontend**
- Code structure and maintainability
- Performance bottlenecks
- Browser/framework best practices
- Specific refactoring instructions

**Strategic**
- Brand/business alignment
- Market positioning gaps
- Opportunity areas
- Competitive considerations

### 3. Unified Fix Instructions

Specific, Claude-Code-ready instructions organized by:
- Component/section affected
- Exact code changes needed
- Expected outcome
- Estimated effort (1-2 hours, half day, full day, etc.)

### 4. Testing Checklist

Before/after verification steps so you can validate fixes.

## How to Use This Skill

### Step 1: Provide Your Prototype

Share code, screenshots, or links to your work. Include:

```
Prototype: [paste code or describe]
Goal: [what this is trying to accomplish]
Audience: [who uses this]
Success criteria: [how you measure success]
Known constraints: [browser support, accessibility target, etc.]
```

### Step 2: Trigger Multi-Agent Analysis

The skill spawns five parallel analysis agents:

1. Each expert reviews independently based on their specialty
2. Agents produce detailed findings with specific issues
3. Orchestrator synthesizes, de-duplicates, and prioritizes
4. Report is organized for immediate action

### Step 3: Execute Fixes

Use the fix instructions directly in Claude Code. Each instruction includes:
- Exact location (component name, line range, etc.)
- Code before/after
- Why the change matters

### Step 4: Validate

Use the testing checklist to verify each fix works.

## Expert Perspectives (6 Specialist Agents)

### 1. UX Designer Lens

Evaluates:
- Task flows and cognitive paths
- Information hierarchy (visual + structural)
- Interaction patterns (consistency, intuitiveness, feedback)
- Micro-interactions (loading states, error states, success states)
- Design system adherence
- Whitespace, typography, color usage

Deliverable: Specific feedback like "The form uses four different button styles; consolidate to two (primary/secondary) in FormButtons component" with before/after code.

### 2. Accessibility Specialist Lens

Evaluates:
- WCAG 2.1 Level AA compliance (minimum standard)
- Color contrast ratios (4.5:1 for normal text, 3:1 for large)
- Keyboard navigation (tab order, focus indicators, skip links)
- Screen reader semantics (ARIA labels, landmark roles, heading hierarchy)
- Motion sensitivity (prefers-reduced-motion)
- Form accessibility (labels, error messages, validation feedback)
- Page structure and landmark roles

Deliverable: Specific failures mapped to WCAG criteria with exact remediation code.

### 3. Frontend Engineer Lens

Evaluates:
- React/component architecture and reusability
- State management and prop drilling
- Render performance (unnecessary re-renders, memoization needs)
- Event handling patterns
- CSS organization (specificity, naming, duplication)
- Bundle impact
- Browser compatibility
- TypeScript usage (if applicable)
- Testing coverage gaps

Deliverable: Refactoring instructions with before/after snippets and performance implications.

### 4. Performance Specialist Lens (OPTIONAL)

Evaluates:
- Core Web Vitals (LCP, INP, CLS)
- Bundle size and code splitting
- Rendering performance
- Image optimization
- Network waterfall and request consolidation
- User-perceived performance (loading states, optimistic updates)

Deliverable: Performance findings with baseline/target metrics and expected improvements (e.g., "LCP: 4.2s → target 2.5s, estimated 40% faster").

### 5. Brand Consistency Specialist Lens (OPTIONAL)

Evaluates:
- Brand alignment (visual identity, tone, messaging)
- Design system usage (color, typography, spacing, components)
- Design token consistency and coverage
- Component reusability and duplication
- Figma-to-code fidelity
- Scalability of design decisions

Deliverable: Design system findings with consolidation recommendations (e.g., "15 colors → consolidate to 6 semantic colors using CSS variables").

### 6. Business Strategy Specialist Lens (OPTIONAL)

Evaluates:
- Business model alignment
- User acquisition and conversion impact
- Retention and engagement implications
- Competitive positioning
- Platform and ecosystem strategy
- Pricing and monetization alignment

Deliverable: Strategic recommendations with business case (e.g., "Reducing onboarding steps from 12 to 3 could improve completion rate 40% → 65%, driving +$3k/month revenue").

### 7. Design Critic Lens

Evaluates:
- Strategic alignment (brand, market positioning, business goals)
- Differentiation vs. competitor patterns
- Missed opportunities for delight or engagement
- Risk areas (accessibility, performance, maintenance debt)
- Future-proofing and scalability concerns
- Design system leverage

Deliverable: Strategic recommendations framed as "This could increase conversion by..." or "This creates maintenance risk because..."

## Sample Output Structure

```
# Prototype Review Report: [Name]

## Executive Summary

OVERALL: Solid foundation with strong interaction patterns. Three accessibility gaps block AA compliance; two frontend refactors unlock 40% performance improvement.

CRITICAL (Fix before shipping):
- [ ] Color contrast on secondary buttons (WCAG AA failure)
- [ ] Form validation errors not announced to screen readers
- [ ] Loading state not announced (creates confusion for AT users)

HIGH (Fix in next sprint):
- [ ] Consolidate button styles (4 variants → 2)
- [ ] Extract shared form logic into useForm hook
- [ ] Add motion sensitivity support

MEDIUM (Nice-to-have):
- [ ] Add success toast confirmation
- [ ] Optimize image loading

---

## UX/Design Findings

### Issue: Button Style Inconsistency
**Location:** src/components/Button.tsx, src/components/FormButtons.tsx, src/pages/HomePage.tsx
**Problem:** Four different button styles used across app (primary solid, primary outline, secondary solid, secondary outline). Creates cognitive load and complicates maintenance.

**Fix Instructions:**
1. In Button.tsx, consolidate to two variants:
   - Primary: [exact code]
   - Secondary: [exact code]
2. Update FormButtons.tsx to use new Button component
3. Update HomePage to remove inline button styles

**Before/After Code:**
```jsx
// BEFORE
<button className="btn btn-secondary-outline">Cancel</button>
<button className="btn-secondary-solid">Save</button>

// AFTER
<Button variant="secondary">Cancel</Button>
<Button variant="primary">Save</Button>
```

**Expected Outcome:** Reduced CSS (12% smaller), easier to maintain, consistent user experience

---

## Accessibility Audit

### CRITICAL: Color Contrast Failure
**WCAG Criterion:** 1.4.3 Contrast (Minimum) - Level AA
**Location:** .btn-secondary in styles.css, line 47
**Issue:** Secondary button text (#666) on light gray background (#f5f5f5) = 2.8:1 ratio (fails AA requirement of 4.5:1)

**Fix Instructions:**
Change text color from `#666` to `#333` (or background from `#f5f5f5` to `#e8e8e8`)

**Testing:** Use WebAIM contrast checker to verify 4.5:1 ratio

### HIGH: Screen Reader Form Validation
**Location:** src/components/Form.tsx
**Issue:** Invalid form state visual indicator (red border) not announced to screen reader users

**Fix Instructions:**
Add aria-invalid and aria-describedby to input:
```jsx
<input 
  aria-invalid={hasError}
  aria-describedby={hasError ? "error-message" : undefined}
/>
<span id="error-message" role="alert">{errorMessage}</span>
```

---

## Frontend Code Review

### Performance: Unnecessary Re-renders
**Location:** src/components/FormSection.tsx, useEffect on line 23
**Problem:** Component re-renders on every keystroke due to form state update triggering parent re-render

**Fix Instructions:**
Wrap onChange handler with useCallback:
```jsx
const handleChange = useCallback((e) => {
  setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }));
}, []);
```

**Expected Impact:** 40% fewer re-renders on form input, smoother UX on lower-end devices

---

## Strategic Insights

### Opportunity: Micro-interactions
The current design feels functional but lacks delight. Adding subtle loading state animations and success confirmations could improve perceived performance by 30% (no actual performance change needed).

### Risk: Mobile Responsiveness
Current design assumes 320px minimum width but doesn't account for 280px devices. This will fail in some international markets using older phones.

---

## Unified Fix Instructions (Priority Order)

### Fix 1: Color Contrast (CRITICAL - 15 min)
**File:** src/styles/buttons.css
**Change:** Line 47, update `.btn-secondary` text color
**Code:** `color: #333;` (was `#666`)
**Verify:** [Testing steps]

### Fix 2: Form Accessibility (CRITICAL - 30 min)
**File:** src/components/Form.tsx
**Change:** Add aria-invalid and aria-describedby to all input elements
**Code:** [before/after snippet]
**Verify:** Test with screen reader

### Fix 3: Button Consolidation (HIGH - 1 hour)
**File:** src/components/Button.tsx, FormButtons.tsx, HomePage.tsx
**Change:** [step-by-step refactoring instructions]
**Verify:** Visual regression testing

### Fix 4: Loading State Announcement (HIGH - 45 min)
**File:** src/components/LoadingSpinner.tsx
**Change:** Add role="status" and aria-live="polite"
**Code:** [snippet]
**Verify:** Test with screen reader

---

## Testing Checklist

- [ ] All buttons pass WCAG AA contrast ratio (4.5:1)
- [ ] Form validation errors announced to screen readers
- [ ] Keyboard navigation works (Tab, Enter, Escape)
- [ ] Loading states announced
- [ ] Reduced motion respected (prefers-reduced-motion honored)
- [ ] No console errors
- [ ] Performance maintained (Lighthouse CWV scores)
- [ ] Visual regression testing passes
```

## Implementation Pattern

When invoked, this skill:

1. **Receives** your prototype and context
2. **Spawns** five parallel agents (UX Designer, A11y Specialist, Frontend Engineer, Design Critic, Orchestrator)
3. **Collects** independent findings from each
4. **Synthesizes** findings, removing duplication and organizing by priority
5. **Generates** the unified report with actionable fix instructions
6. **Returns** a document you can save and iterate against

## Using Fix Instructions in Claude Code

Each fix instruction is designed to be executable:

1. Copy the exact code snippet
2. Paste into Claude Code with context (file name + current code)
3. Claude Code makes the change
4. Run the testing steps to verify

Example:
```
I need to fix the color contrast issue. Here's the current code:
.btn-secondary { color: #666; }

Apply the fix from the design review report.
```

Claude Code will know to change it to `#333` and verify.

## Customization

This skill adapts to your needs:

- **Focus areas**: Tell it to emphasize accessibility or performance
- **WCAG level**: Specify if you need Level A, AA, or AAA
- **Browser support**: It will flag incompatibilities
- **Design system**: Reference your existing system, it will check alignment

## Limitations

- Cannot fully simulate user testing (but will flag usability red flags)
- Accessibility review is structural/technical, not user-tested
- Performance analysis is static; real-world testing needed
- Does not review content/copy strategy (separate skill)

---

For best results, provide:
1. Complete code or high-fidelity screenshots
2. Clear project goal and success criteria
3. Known constraints (accessibility target, browser support, performance goals)
4. Context on what you've already tried or prioritized
