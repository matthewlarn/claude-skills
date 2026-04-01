# Design Review Cowork Skill

A comprehensive multi-perspective prototype review system that coordinates expert reviewers to analyze your work and produce actionable fix instructions you can use directly in Claude Code.

## What This Skill Does

When you've built a prototype in Claude Code (React component, HTML/CSS/JS, or any web UI), use this skill to get expert-level review from five perspectives:

1. **Senior UX Designer** - Evaluates user flows, information hierarchy, consistency
2. **Accessibility Specialist** - Audits WCAG compliance, keyboard nav, screen reader support
3. **Frontend Engineer** - Reviews code quality, performance, architecture
4. **Design Critic** - Challenges strategic decisions, identifies business impact
5. **Orchestrator** - Synthesizes all findings into a prioritized report with executable fixes

## How to Use It

### Step 1: Prepare Your Work

Have ready:
- Your code (paste full component/HTML)
- OR screenshots of the prototype
- Project goal (what is this trying to accomplish)
- Target audience (who uses this)
- Success criteria (how you measure if it works)
- Known constraints (browser support, accessibility target, performance goals)

### Step 2: Trigger the Review

In Cowork, provide your prototype with context:

```
I've built a form component for [project]. Please conduct a comprehensive design review.

Goal: [what this accomplishes]
Audience: [who uses it]
Criteria: [success measure]
Constraints: [known limits]

Code:
[paste your React/HTML/CSS/JS]
```

Or reference a file:

```
Please review the prototype in src/components/Form.tsx
Goal: User registration form for enterprise customers
Audience: 40+ year old IT managers, first-time users
Criteria: <30 second completion time, 90% success rate
Constraints: Must support IE11, WCAG AA compliant

The code is [paste full component]
```

### Step 3: Receive Multi-Perspective Analysis

The skill spawns five parallel agents that each independently review your work based on their specialty. You get a unified report with:

- Executive summary (what's working, critical blockers, strategic insights)
- Detailed findings organized by category (Accessibility, Design, Code, Strategy)
- Prioritized fix instructions you can copy into Claude Code
- Testing checklist to verify each fix

### Step 4: Execute Fixes in Claude Code

Each fix instruction is designed to work directly in Claude Code:

```
File: src/styles/buttons.css
Issue: Color contrast failure (WCAG AA)

Change line 47:
From: color: #666;
To: color: #333;

Verify: Use WebAIM contrast checker, confirm 5.2:1 ratio
```

You can copy the fix instruction and provide it to Claude Code:

```
Apply this fix from the design review:
[paste fix instruction]

File to update: src/styles/buttons.css
```

Claude Code will apply the change and you verify with the testing steps.

### Step 5: Track and Validate

The report includes a testing checklist. Go through each fix:

- [ ] Apply the code change
- [ ] Run the verify steps
- [ ] Confirm the fix works
- [ ] Move to next priority

## What the Report Looks Like

### Executive Summary
```
This form demonstrates solid UX fundamentals with clear task flow and good visual 
hierarchy. Three accessibility gaps block AA compliance (must fix before shipping). 
The component architecture creates maintainability risk as the product scales—investing 
in extraction now prevents 2x refactoring cost in 6 months. Overall trajectory is positive; 
prioritize accessibility compliance, then consider strategic UX enhancements.
```

### Priority Summary
```
CRITICAL (Blocking - 45 min):
- [ ] Color contrast failure on secondary buttons (WCAG AA)
- [ ] Form validation errors not announced to screen readers
- [ ] Button styles inconsistent (4 variants → consolidate to 2)

HIGH (Priority - 2 hours):
- [ ] Custom styling prevents design system evolution
- [ ] Reduced motion preference not respected
- [ ] Performance: unnecessary re-renders on form input

MEDIUM (Next Sprint - 1 hour):
- [ ] Add success toast confirmation
- [ ] Optimize image loading
```

### Specific Fix Instructions
```
FIX 1: Color Contrast - CRITICAL - 15 minutes
File: src/styles/buttons.css, line 47
Issue: Secondary button text (#666) on background (#f5f5f5) = 2.8:1 ratio (need 4.5:1)

Change:
  .btn-secondary {
    color: #666; /* DELETE */
    color: #333; /* ADD */
  }

Verify: WebAIM contrast checker shows 5.2:1 ratio ✓

---

FIX 2: Form Validation A11y - CRITICAL - 30 minutes
File: src/components/Form.tsx
Issue: Error messages not announced to screen readers

Change input (line 40):
  <input aria-invalid={!!error} aria-describedby={error ? `error-id` : undefined} />

Add to error message (line 45):
  <span id="error-id" role="alert">{error}</span>

Verify: 
- Tab to form field
- Type invalid input
- Submit form
- Screen reader should announce error message
```

## Expert Perspectives Explained

### UX Designer Lens
Evaluates task flows, information hierarchy, interaction patterns, visual consistency, and design system alignment. Looks for confusing mental models, missing feedback, unclear primary actions, and inconsistent styling.

**What you get**: Specific feedback like "Buttons 1 and 3 look identical but have different functions—add visual distinction" with code examples.

### Accessibility Specialist Lens
Audits WCAG 2.1 Level AA compliance (the legal baseline). Checks color contrast, keyboard navigation, screen reader semantics, motion preferences, and form accessibility.

**What you get**: Specific WCAG failures like "Input not associated with label → screen reader users don't know what field is for" with remediation code.

### Frontend Engineer Lens
Reviews code quality, component architecture, performance bottlenecks, browser compatibility, and testing coverage. Flags prop drilling, unnecessary re-renders, bundle impact, and maintainability risks.

**What you get**: Refactoring instructions like "Extract shared form logic into useForm hook → 40% fewer re-renders" with before/after code.

### Design Critic Lens
Challenges strategic decisions, surfaces business impact, flags scalability risks, and identifies differentiation opportunities. Asks hard questions about brand alignment, competitive positioning, and long-term costs.

**What you get**: Strategic insights like "Custom button system will cost 2x refactoring in 6 months—standardize now" with business case.

### Orchestrator
Synthesizes all findings, removes duplication, prioritizes by impact and effort, and generates a unified report with executable instructions.

## When to Use This Skill

✓ After building a prototype in Claude Code, before shipping  
✓ When you need multi-disciplinary feedback  
✓ When you want specific, actionable advice (not vague suggestions)  
✓ When you need to prioritize between competing fixes  
✓ When you need help understanding business impact  
✓ When you want accessibility audit  
✓ When you're building something reusable and want scalability review  

✗ Don't use for very early sketches (wait until mid-fidelity)  
✗ Don't use for content/copy strategy (separate skill)  
✗ Don't use for user research validation (requires actual user testing)  

## Tips for Best Results

1. **Provide complete context**: The more the skill knows about your goal and audience, the better the feedback.

2. **Be specific about constraints**: "WCAG AA compliant" vs. "AAA", "IE11 support" vs. "evergreen browsers", "under 100ms" vs. "performant".

3. **Paste full code, not snippets**: The skill needs complete context to understand interactions and patterns.

4. **Include screenshots if you have them**: Screenshots help the UX Designer see subtle visual issues that code alone doesn't convey.

5. **Be ready to execute**: The report is designed for immediate action. Have time to apply fixes in the same session if possible.

## Understanding the Priority Matrix

The skill uses three prioritization dimensions:

**Impact**: How much does this affect users or business?
- Critical: Blocks core task, accessibility failure, security issue
- High: Creates friction, performance problem, design debt
- Medium: Nice-to-have improvement
- Low: Edge case

**Effort**: How long to fix?
- Quick: 15-30 min
- Half day: 2-4 hours
- Full day: 4-8 hours
- Epic: 2+ days

**Dependencies**: Is this blocked or blocking?
- Independent: Can fix anytime
- Blocked: Requires other fix first
- Blocking: Other work depends on this

**Priority Order**: High Impact + Quick Effort first (bang for buck).

## Common Feedback Patterns

### Accessibility Findings
Usually include WCAG criterion number and specific remediation code. These are non-negotiable (legal compliance). Severity is Critical or High.

### Design Findings
Usually include before/after code and testing steps. These affect UX and consistency.

### Code Findings
Usually include performance impact and refactoring instructions. These affect maintainability and performance.

### Strategic Findings
Usually include business case (revenue impact, cost savings) and next steps. These inform prioritization decisions.

## Example: Full Workflow

**You**: I've built a form. Here's the code. Goal is 30-second completion for new users.

**Skill**: [Spawns five agents, they review independently]

**Report includes**:
- Executive summary: "Solid task flow, but 3 accessibility gaps block shipping"
- Fix 1 (Critical): Color contrast, 15 min
- Fix 2 (Critical): Form validation a11y, 30 min
- Fix 3 (High): Button consolidation, 1 hour
- Fix 4 (High): Performance optimization, 45 min

**You**: Copy Fix 1 into Claude Code
```
Fix the color contrast issue in src/styles/buttons.css. Current: color: #666. Should be #333.
```

**Claude Code**: Updates the file, you verify with WebAIM contrast checker

**You**: Repeat for all Critical fixes

**You**: All tests pass → ready to ship or move to High priority items

## Customization

Tell the skill about any special considerations:

- "Focus on accessibility" → Prioritizes A11y findings
- "This is for enterprise, needs IE11 support" → Flags compatibility issues
- "We have a design system" → Checks alignment
- "Performance is critical" → Focuses on perf optimizations

## Limitations

- Cannot fully simulate user testing (but flags usability red flags)
- Accessibility is structural/technical (not user-tested with real AT users)
- Performance analysis is static (real-world testing needed)
- Does not review content strategy or copy (separate skill needed)

## FAQ

**Q: Do I have to fix all the issues?**  
A: No. Critical items block shipping. High items should be in next sprint. Medium/Low can be deferred.

**Q: Can I use this for APIs or backend?**  
A: No, this skill is for UI/UX. Design review is for visual and interaction design.

**Q: What if I disagree with a finding?**  
A: The skill provides reasoning (why this matters). If you disagree with the reasoning, you can ask Claude to clarify or provide alternative perspectives.

**Q: Can this test with real users?**  
A: No, this is expert review, not user testing. After fixes, you should do user testing to validate.

**Q: How long does a review take?**  
A: Depends on prototype complexity. Usually 5-15 minutes for the agents to complete. You'll need 1-4 hours to apply fixes depending on severity and scope.

**Q: What if I have a really simple component?**  
A: The skill still provides value (accessibility audit, performance check, strategic questions). The report will be shorter.

## Next Steps After Review

1. Apply Critical fixes (should take <1 hour)
2. Run testing checklist to verify
3. Apply High priority fixes in next sprint
4. Schedule Medium/Low for future sprints
5. Consider strategic recommendations (Design Critic insights)
6. User test with real users before launch

---

For best results, provide complete context and be ready to execute. The skill's value is in specific, actionable guidance—not vague opinions.
