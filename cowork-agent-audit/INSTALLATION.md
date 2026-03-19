# Design Review Cowork Skill - Installation & Activation

## What You're Getting

A complete Cowork skill that coordinates five expert reviewers (UX Designer, Accessibility Specialist, Frontend Engineer, Design Critic, Orchestrator) to analyze your Claude Code prototypes and produce actionable fix instructions.

**Total size**: ~107KB of analysis frameworks and agent instructions  
**Ready to use**: Yes, immediately  
**Customizable**: Yes, all agent instructions are editable  

## File Structure

```
design-review-skill/
│
├── SKILL.md                          # ← Skill metadata and main definition
├── README.md                         # ← User guide with examples and FAQs
├── QUICKSTART.md                     # ← This overview (what you're reading)
├── EXAMPLE_REPORT.md                 # ← Full sample report output
│
└── agents/                           # ← Expert instruction modules
    ├── ux-designer.md                # UX/Design perspective
    ├── accessibility.md              # WCAG compliance perspective
    ├── frontend.md                   # Code quality perspective
    ├── design-critic.md              # Strategic/business perspective
    └── orchestrator.md               # Synthesis & report generation
```

## How to Activate

### Option 1: Copy to Cowork Skills Directory

If Cowork has a skills directory:

```bash
cp -r /home/claude/design-review-skill /path/to/cowork/skills/
```

Then restart Cowork. Skill will appear in available skills list.

### Option 2: Load Directly in Claude

When you're ready to use the skill, simply provide your prototype and say:

```
I've built a form component and need a comprehensive design review.

[paste code]

Please analyze this using a multi-perspective approach:
1. UX Designer perspective
2. Accessibility audit (WCAG AA)
3. Frontend code quality
4. Strategic/business implications
5. Consolidated fix instructions

Use the design-review-cowork skill approach.
```

Claude will load the skill instructions and execute the review.

### Option 3: Manual Setup

If you're not in Cowork or need manual setup:

1. Read `SKILL.md` (understand the framework)
2. Read agent files in `agents/` directory
3. When analyzing a prototype, have Claude reference these instructions
4. Claude will follow the expert frameworks and produce the report

## How to Use (Basic Workflow)

### Step 1: Have a Prototype Ready
Build something in Claude Code. Have it ready to share.

### Step 2: Provide Context
```
I've built a registration form for [project].

Goal: [what this accomplishes]
Audience: [who uses this]
Success criteria: [how you measure success]
Constraints: [browser support, a11y target, performance goals]

Code:
[paste your full component]
```

### Step 3: Trigger Review
```
Please conduct a design review of this form using the design-review-cowork skill.
```

### Step 4: Get the Report
You'll receive a structured report with:
- Executive summary
- Findings by category (Accessibility, Design, Code, Strategy)
- Prioritized fix instructions
- Testing checklist

### Step 5: Execute Fixes
Copy fix instructions into Claude Code:
```
Apply Fix 1 from the design review: Change color in src/styles/buttons.css from #666 to #333
```

Claude Code applies the fix. Test and move to next fix.

## Customization

### Focus Specific Areas

Edit agent files to adjust emphasis:

**To focus on accessibility**:
- Increase weight of accessibility.md findings
- Decrease strategic findings
- Adjust prioritization to mark A11y as CRITICAL even if effort is high

**To focus on performance**:
- Increase frontend.md performance sections
- Add performance metrics to orchestrator.md prioritization

**To focus on scalability**:
- Increase design-critic.md weight
- Flag technical debt earlier
- Add long-term maintenance costs to business case

### Modify for Your Tech Stack

**React-specific**:
- agent/frontend.md already covers React patterns
- Good as-is for React projects

**Vue/Svelte**:
- Update frontend.md to reference Vue/Svelte patterns
- Concepts stay same, syntax changes

**TypeScript**:
- frontend.md already includes TypeScript checks
- Can add more strict type checking if needed

**CSS framework** (Tailwind, Bootstrap, etc.):
- Update design system checks in ux-designer.md
- Reference your specific system

### Adjust Prioritization Rules

In `agents/orchestrator.md`, modify priority matrix:

**Current** (default):
- High Impact + Quick Effort → DO FIRST
- High Impact + Long Effort → DO EARLY
- Low Impact + Quick Effort → DO LATER
- Low Impact + Long Effort → DEFER

**Alternative** (if accessibility is paramount):
- CRITICAL: All accessibility failures (regardless of effort)
- HIGH: Design/code issues + strategic improvements
- MEDIUM: Optimization opportunities

## Reference Guide

### When Each Expert Perspective Helps

**UX Designer** (ux-designer.md)
- Use when: Building consumer-facing features
- Focus on: Task completion, information hierarchy, consistency
- Example findings: "Buttons have 4 styles, consolidate to 2"

**Accessibility Specialist** (accessibility.md)
- Use when: Ship-blocking review needed (legal requirement)
- Focus on: WCAG AA compliance (minimum), WCAG AAA (aspirational)
- Example findings: "Color contrast 2.8:1 fails AA requirement of 4.5:1"

**Frontend Engineer** (frontend.md)
- Use when: Code quality and performance matter
- Focus on: Architecture, maintainability, bundle size, re-render efficiency
- Example findings: "Prop drilling 3 levels deep, extract to context"

**Design Critic** (design-critic.md)
- Use when: Long-term product strategy needed
- Focus on: Scalability, differentiation, technical debt, ROI
- Example findings: "Custom button system creates 2x refactoring cost in 6 months"

**Orchestrator** (orchestrator.md)
- Always used: Synthesis layer that brings all perspectives together
- Removes duplication, prioritizes, generates executable fixes

### WCAG Compliance Levels

**Default: Level AA** (legal minimum in most countries)
- Normal text contrast: 4.5:1
- Large text contrast: 3:1
- Keyboard navigation required
- Screen reader compatible

**Optional: Level AAA** (higher bar, not always required)
- Normal text contrast: 7:1
- Large text contrast: 4.5:1
- Enhanced captions for video
- Sign language interpretation

**Enterprise**: Often requires Level AA minimum, sometimes AAA for specific sections

## Understanding the Output

### Severity Levels

**Critical**: 
- Blocks core task functionality
- Legal compliance failure (WCAG)
- Security issue
- Brand/business damage

**High**:
- Creates significant user friction
- Performance issue
- Design system debt
- Maintenance burden

**Medium**:
- Nice-to-have improvement
- Optimization opportunity
- Edge case issue

**Low**:
- Future consideration
- Very minor issue
- Depends on future priorities

### Effort Estimates

**Quick** (15-30 min):
- CSS change
- Simple refactor
- A11y attribute addition

**Half day** (2-4 hours):
- Component extraction
- Multiple related fixes
- Moderate refactor

**Full day** (4-8 hours):
- Major architectural change
- Design system refactor
- Significant re-architecture

**Epic** (2+ days):
- System-wide changes
- Major redesign
- Complex refactoring

### Impact Categories

**User Impact**:
- Does this affect task completion?
- Does this affect user satisfaction?
- Does this block a segment of users?

**Business Impact**:
- Could this affect conversion?
- Could this increase support costs?
- Could this create compliance risk?

**Technical Impact**:
- Does this create debt?
- Does this affect maintainability?
- Does this affect performance?

## Examples by Use Case

### Example 1: Building a Form for ZAG (B2B SaaS)

**You'd want to emphasize**:
- Accessibility (enterprise procurement often requires it)
- Code quality (forms are reused across product)
- Performance (enterprise users on VPNs)
- Design consistency (brand trust matters)

**Expert priority**: Accessibility > Frontend > UX Design > Strategy

### Example 2: Building Interactive Component for Clap (Consumer Video)

**You'd want to emphasize**:
- Performance (video content is resource-heavy)
- Accessibility (motion affects video content)
- UX Design (consumer expectations high)
- Design consistency (brand recognition)

**Expert priority**: Frontend > UX Design > Accessibility > Strategy

### Example 3: Building Dashboard for Chronosphere (Monitoring)

**You'd want to emphasize**:
- Performance (real-time data needs fast updates)
- Code quality (shared component library)
- Accessibility (accessible monitoring is critical for security)
- Strategic (competitive analysis vs. other monitoring tools)

**Expert priority**: Frontend > Accessibility > Design Critic > UX Design

### Example 4: Building Course Module for Vaughn Physics (Education)

**You'd want to emphasize**:
- Accessibility (students may have disabilities)
- UX Design (clear information hierarchy for learning)
- Scalability (course content grows)
- Design consistency (pedagogical approach)

**Expert priority**: Accessibility > UX Design > Frontend > Strategy

## Modifying for Your Workflow

### If You Want Faster Reviews

In `orchestrator.md`, reduce findings:
- Set severity threshold: only report Critical + High
- Skip Medium findings
- Keep focus narrow

Result: Faster report, less noise

### If You Want More Detail

In expert files, increase specificity:
- Add more test cases
- Include more examples
- Provide more alternatives
- Explain more context

Result: Longer report, more learning

### If You Want Business-Focused

In `design-critic.md`, emphasize:
- ROI calculations
- Competitive analysis
- Risk assessment
- Future cost implications

Result: Strategic report, business case driven

## Common Patterns to Look For

### Accessibility Red Flags
- Hard-coded colors without contrast check
- No keyboard support for interactive elements
- Forms without labels or error announcements
- Animations without motion sensitivity check
- No focus indicators

**Fix time**: Usually 15-60 min

### Design System Red Flags
- 4+ button variants
- 10+ color values
- Inconsistent spacing
- Multiple heading styles
- Duplicated component logic

**Fix time**: Usually 1-4 hours

### Performance Red Flags
- Prop drilling 3+ levels
- Unnecessary re-renders
- No memoization where needed
- Inline object/array creation
- Large bundle size for simple component

**Fix time**: Usually 30-90 min

### Strategic Red Flags
- Patterns different from market leaders
- Visual design misaligned with brand
- Scalability limits becoming visible
- Custom solutions for common problems
- Increasing technical debt

**Fix time**: Usually 2+ hours (refactor or redesign)

## FAQ

**Q: How long does a review take?**  
A: 5-15 minutes for agents to complete. You'll need 1-4 hours to apply fixes depending on severity.

**Q: Can I use this for multiple projects?**  
A: Yes, the skill is completely reusable. Each prototype gets independent review.

**Q: What if I only want specific expert perspectives?**  
A: Edit `orchestrator.md` to only include perspectives you want. Or ask Claude to focus specific areas.

**Q: Can I customize the output format?**  
A: Yes, edit `orchestrator.md` report structure section to match your preferences.

**Q: What if I disagree with a finding?**  
A: The skill explains *why* (e.g., "WCAG 1.4.3 requires 4.5:1 contrast ratio"). You can argue the reasoning, but facts (like WCAG requirements) are objective.

**Q: How do I know if the fixes worked?**  
A: Each fix has a "Verify" section with testing steps. Follow those before marking complete.

## Next Steps

1. **Read SKILL.md** (~5 min) - Understand skill definition
2. **Read EXAMPLE_REPORT.md** (~10 min) - See what output looks like
3. **Build a prototype** - Something real to review
4. **Trigger review** - Use skill on your prototype
5. **Apply fixes** - Copy instructions to Claude Code
6. **Iterate** - Fix issues and re-review

---

## Support & Troubleshooting

### Skill Not Triggering

If Claude isn't using the skill:
- Make sure you've mentioned it explicitly: "Use the design-review-cowork skill"
- Provide complete prototype code (not snippets)
- Give clear context about what you're building

### Feedback Not Helpful

If a finding seems irrelevant:
- Check the reasoning (Why does this matter?)
- Read the WCAG criterion if it's a11y related
- Consider if it applies to your context
- Adjust agent files to better match your needs

### Want to Adjust Prioritization

Edit `orchestrator.md` "Prioritization Framework" section to match your business needs.

### Want to Add Custom Checks

Add to relevant agent file:
- New accessibility checks → accessibility.md
- New design patterns → ux-designer.md
- New performance checks → frontend.md
- New business considerations → design-critic.md

---

**Ready to use?** You have everything you need. Start with a prototype review and iterate from there.
