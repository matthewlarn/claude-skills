# Design Review Cowork Skill - Quick Start

Sir, I've created a comprehensive Cowork skill that brings multiple expert perspectives to review your Claude Code prototypes. Here's what you've got.

## Skill Overview

**Name**: design-review-cowork  
**Purpose**: Multi-perspective prototype analysis that generates specific, actionable fix instructions  
**Output**: Prioritized report with WCAG audit, performance review, code quality feedback, and strategic insights

## Directory Structure

```
design-review-skill/
├── SKILL.md                    # Main skill definition (how to use, inputs, output format)
├── README.md                   # Comprehensive user guide with examples
├── EXAMPLE_REPORT.md           # Full example showing what a report looks like
└── agents/                     # Specialized expert instructions
    ├── ux-designer.md          # UX Designer perspective
    ├── accessibility.md        # Accessibility Specialist (WCAG compliance)
    ├── frontend.md             # Frontend Engineer (code quality, performance)
    ├── design-critic.md        # Design Critic (strategy, business impact)
    └── orchestrator.md         # Orchestrator (synthesis, prioritization, fix instructions)
```

## How It Works

### For You
1. Build a prototype in Claude Code
2. Paste it (+ context) to this skill: "Review this form component..."
3. Skill spawns five parallel agents
4. Each agent independently reviews based on their specialty
5. You get a unified report with:
   - Executive summary
   - Detailed findings by category
   - Prioritized fix instructions you can copy into Claude Code
   - Testing checklist

### For Each Expert Agent

**UX Designer** (ux-designer.md)
- Evaluates task flows, information hierarchy, interaction patterns
- Flags usability issues, inconsistency, design system misalignment
- Reports like: "Buttons have 4 styles (primary, secondary, outline, ghost)—consolidate to 2"

**Accessibility Specialist** (accessibility.md)
- Audits WCAG 2.1 AA compliance (legal standard)
- Checks: color contrast, keyboard nav, screen reader compatibility, motion sensitivity
- Reports like: "Input not associated with label → screen reader users don't know field purpose"
- Every finding includes WCAG criterion number and remediation code

**Frontend Engineer** (frontend.md)
- Reviews component architecture, performance, browser compatibility
- Flags prop drilling, unnecessary re-renders, bundle bloat, testing gaps
- Reports like: "Prop drilling 3 levels deep → extract to context or hook"
- Includes refactoring instructions with before/after code

**Design Critic** (design-critic.md)
- Challenges strategic decisions, surfaces business impact
- Identifies scalability risks, competitive gaps, brand misalignment
- Reports like: "Custom button system creates 2x refactoring cost in 6 months"
- Includes ROI analysis ("Fixing X could improve conversion by Y%")

**Orchestrator** (orchestrator.md)
- Synthesizes all findings into one report
- De-duplicates overlapping feedback
- Prioritizes by impact + effort (CRITICAL → HIGH → MEDIUM)
- Generates specific, Claude-Code-ready fix instructions

## What a Report Looks Like

### Structure
1. **Executive Summary** (1 paragraph): What's working, critical blockers, strategic insight
2. **Finding Summary Table**: Quick overview of all issues
3. **Detailed Findings**: Organized by category with code examples
4. **Unified Fix Instructions**: Prioritized list you can execute immediately
5. **Testing Checklist**: Verification steps for each fix

### Example Fix Instruction (copy-paste ready)
```
FIX 1: Color Contrast - CRITICAL - 15 minutes

File: src/styles/buttons.css, line 47
Issue: Secondary button text (#666) fails WCAG AA contrast (2.8:1, need 4.5:1)

Change:
  .btn-secondary {
    color: #666; /* DELETE */
    color: #333; /* ADD */
  }

Verify:
  - WebAIM contrast checker: #333 on #f5f5f5 = 5.5:1 ✓
  - Visual test: buttons clearly readable
```

You copy this into Claude Code:
```
Fix the color contrast issue in src/styles/buttons.css from #666 to #333
```

Claude Code makes the change. Done.

## Key Features

### 1. Executable Fix Instructions
Every fix includes:
- Exact file and line number
- Current code
- Fixed code
- Why it matters
- Verification steps

### 2. Multiple Perspectives
No "I think this is bad." Instead:
- UX Designer: "Inconsistent styles affect user predictability"
- Frontend Engineer: "4 button variants require touching 4 CSS files on changes"
- Accessibility: "Fails WCAG 1.4.3, contrast ratio 2.8:1 (need 4.5:1)"
- Design Critic: "Technical debt that scales to 8+ variants in 6 months"

All viewpoints together = better decisions.

### 3. Prioritization by Business Impact
Three dimensions:
- **Impact**: Does this block shipping, affect users, or create debt?
- **Effort**: 15 min, half day, full day, epic?
- **Dependencies**: Can I fix this now, or is it blocked?

Results in clear priority order: High Impact + Quick Effort first.

### 4. Strategic Insights
Beyond "fix this code." Includes:
- Business case ("Could improve conversion by 30%")
- Scalability risk ("Will create 2x refactoring cost later")
- Competitive positioning ("Market leaders use this pattern")
- Research recommendations ("Test with users before implementing")

## Using the Skill in Cowork

### Step 1: Have Your Prototype Ready
```
I've built a registration form for enterprise customers.

Goal: User registration in <2 minutes, 90% success rate
Audience: 40-60 year old IT managers, first-time users
Constraints: WCAG AA compliant, IE11 support
Known Issues: Haven't tested accessibility yet

Code:
[paste full React component or HTML/CSS/JS]
```

### Step 2: Trigger the Review
Tell Claude to use the design-review-cowork skill:
```
Please conduct a comprehensive design review of this form component 
using the design-review-cowork skill. Focus on accessibility compliance 
and scalability issues.
```

### Step 3: Receive the Report
Skill coordinates five agents, each analyzes independently, then synthesizes findings.

### Step 4: Apply Fixes
Take the priority list, start with CRITICAL items:
```
Apply Fix 1 from the design review report to src/styles/buttons.css
```

## What's Included

### Main Files
- **SKILL.md** (13KB): Skill definition, inputs/outputs, expert perspectives explained
- **README.md** (12KB): Comprehensive user guide with examples and FAQs
- **EXAMPLE_REPORT.md** (28KB): Full sample report showing exact output format

### Expert Instructions (agents/)
- **ux-designer.md** (4KB): UX analysis framework and reporting format
- **accessibility.md** (9KB): WCAG audit checklist with specific violations
- **frontend.md** (10KB): Code quality checks, performance analysis, refactoring patterns
- **design-critic.md** (12KB): Strategic assessment, business impact, risk analysis
- **orchestrator.md** (11KB): Synthesis, de-duplication, prioritization, report generation

**Total**: ~107KB of comprehensive review instructions

## Customization Options

### Focus Areas
"Focus on accessibility" → Prioritizes A11y findings  
"Performance is critical" → Emphasizes perf optimizations  
"We have a design system" → Checks alignment  

### Compliance Level
"WCAG AA" (default) = legal standard  
"WCAG AAA" = higher bar for accessibility  
"Enterprise" = adds IE11 compatibility, security checks  

### Constraints
"Mobile-first" → checks responsive design  
"Evergreen browsers only" → skips IE11 checks  
"<50KB bundle" → performance threshold  

## Real-World Example

**You**: "Review my checkout form"

**Skill executes**:
1. UX Designer scans form → "Button styles inconsistent (4 variants)"
2. A11y Specialist audits → "Color contrast fails on secondary buttons"
3. Frontend Engineer reviews → "Prop drilling through 3 levels, 40% unnecessary re-renders"
4. Design Critic analyzes → "Custom styling creates 2x refactoring cost in 6 months"
5. Orchestrator synthesizes → Report with 5 fixes (1 CRITICAL, 2 HIGH, 2 MEDIUM)

**Report includes**:
```
CRITICAL - 45 minutes (ship blockers)
  - Color contrast fix: 15 min
  - Form validation a11y: 30 min

HIGH - 2 hours (next sprint)
  - Button consolidation: 1 hour
  - Eliminate prop drilling: 1 hour

MEDIUM - 1 hour
  - Add reduced motion support: 20 min
  - Extract custom styles to design tokens: 40 min
```

**You apply fixes**:
- Copy Fix 1 to Claude Code
- Claude Code updates CSS
- Run WebAIM contrast checker ✓
- Repeat for Fixes 2-5
- Test with checklist
- Ship confident

## For Your ZAG/Chronosphere/Clap Work

This skill is especially valuable for:

**ZAG** (circular economy platform)
- Audit forms for enterprise compliance
- Ensure brand consistency across components
- Performance review for industrial partners
- A11y audit for government procurement (often required)

**Chronosphere** (monitoring platform)
- Complex UI review for performance
- Accessibility audit for charts/dashboards
- Code quality review for fast iteration
- Strategic feedback on data viz patterns

**Clap** (interactive video)
- Form accessibility (critical for user onboarding)
- Performance review for video rendering
- Motion accessibility (important for video content)
- UX consistency across video interactions

**Vaughn Physics** (course platform)
- Form a11y for student enrollment
- Pedagogy-aware design review
- Performance for video-heavy content
- Accessibility for science simulations

## Important Notes

### What This Skill Does Well
✓ Accessibility audit (objective, WCAG-based)  
✓ Code quality review (architecture, performance)  
✓ Design consistency check (patterns, spacing, colors)  
✓ Strategic feedback (business impact, scalability)  
✓ Actionable fixes (specific code with verification)  

### What This Skill Can't Do
✗ User testing (requires real users)  
✗ Usability testing (requires observation)  
✗ Content/copy strategy (different skill)  
✗ Visual design aesthetics (subjective)  
✗ Business strategy (outside scope)  

### Limitations to Know
- Accessibility is structural/technical (not tested with real AT users)
- Performance analysis is static (real-world testing needed)
- Design feedback is pattern-based (not high-fidelity visual critique)
- Strategic recommendations are educated guesses (validate with data)

## Next Steps

### To Use This Skill
1. Copy the `/home/claude/design-review-skill` folder into your Cowork skills directory
2. When you have a prototype in Claude Code, reference it
3. Ask Claude to use the design-review-cowork skill
4. Follow the fix instructions in Claude Code

### To Customize
- Edit `agents/` files to adjust focus areas
- Update `SKILL.md` description for your team's needs
- Modify prioritization logic if your business has different priorities

### To Extend
- Add agent for "Brand Voice" if needed
- Add agent for "Mobile/Responsive" if that's a focus
- Add agent for "Performance Metrics" if you have specific targets
- Add reference docs for your design system

## File Locations

All files are in: `/home/claude/design-review-skill/`

Key files to understand:
- **Start here**: SKILL.md (skill definition)
- **See example**: EXAMPLE_REPORT.md (what you'll get)
- **Learn experts**: agents/*.md (how each perspective works)
- **Quick ref**: README.md (FAQs and usage tips)

---

## Summary

You now have a production-ready Cowork skill that brings together:

1. **5 expert perspectives** (UX, A11y, Frontend, Strategy, Orchestration)
2. **Structured analysis** (each expert has clear evaluation framework)
3. **Executable output** (specific fixes with code examples)
4. **Business context** (ROI, risk, strategic implications)
5. **Scalable process** (can be used for every prototype)

This is designed specifically for your workflow:
- Build prototype in Claude Code
- Trigger review with skill
- Get prioritized fixes
- Copy fixes back to Claude Code
- Ship confident

The skill is ready to use. You can activate it in Cowork, or integrate it into your Claude Code workflow for continuous review.

---

**Ready to review your first prototype?** Have one built and paste it with context. The skill will handle the rest.
