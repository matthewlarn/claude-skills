# Design Review Cowork Skill - Complete Index

**Status**: ✓ Complete and ready to use  
**Size**: 145KB | 11 files  
**Location**: `/home/claude/design-review-skill/`

---

## Quick Navigation

### Getting Started (Read These First)
1. **README_DELIVERY.md** ← START HERE - What was built, why it matters, how to use
2. **QUICKSTART.md** - Overview, key concepts, usage examples
3. **SKILL.md** - Formal skill definition, inputs/outputs

### Understanding the System
4. **README.md** - Comprehensive user guide, FAQ, best practices
5. **EXAMPLE_REPORT.md** - Full sample report showing exact output format

### Expert Perspectives (Reference)
6. **agents/ux-designer.md** - UX/design analysis framework
7. **agents/accessibility.md** - WCAG compliance audit framework
8. **agents/frontend.md** - Code quality and performance analysis
9. **agents/design-critic.md** - Strategic and business impact assessment
10. **agents/orchestrator.md** - Synthesis, prioritization, fix instruction generation

### Setup & Customization
11. **INSTALLATION.md** - Activation instructions, customization, troubleshooting

---

## File Descriptions

### Core Skill Definition
**SKILL.md** (13KB)
- Formal skill metadata (name, description, compatibility)
- Input format (prototype types, context requirements)
- Output structure (report sections, findings format)
- Expert perspectives explained
- Limitations and scope

**Use when**: Understanding what the skill officially does and expects

---

### User Documentation
**README_DELIVERY.md** (7KB) ← **Start here**
- What was built and why
- How it works (3-step overview)
- Key capabilities
- Real-world examples
- Why this approach matters
- For your current projects (ZAG, Chronosphere, Clap, Vaughn Physics)
- Next steps

**Use when**: First time understanding the skill, getting oriented

**README.md** (12KB)
- Comprehensive user guide
- How to use (step-by-step)
- What the report looks like
- Expert perspectives explained in detail
- When to use this skill
- Tips for best results
- Understanding priority matrix
- Common feedback patterns
- FAQ (12 questions answered)

**Use when**: Actually using the skill, need help with specifics

**QUICKSTART.md** (5KB)
- Overview of components
- Directory structure
- How it works (condensed)
- What's included
- For each of your projects
- Tips for best results
- Common patterns to look for

**Use when**: Quick reference, orientation

**INSTALLATION.md** (9KB)
- How to activate in Cowork
- Basic usage workflow
- Customization options
- Reference guide (when each expert helps)
- WCAG compliance levels
- Understanding the output
- Examples by use case
- Modifying for your workflow
- Common patterns to look for
- FAQ (specific setup questions)
- Support & troubleshooting

**Use when**: Setting up the skill, customizing for your needs

---

### Learning by Example
**EXAMPLE_REPORT.md** (28KB)
- Complete sample report for a registration form
- Executive summary (how to read it)
- Finding summary table
- Detailed findings organized by category (Accessibility, Design, Code, Strategy)
- All findings include: severity, effort, location, problem, fix, verification
- Unified fix instructions (5 examples, all copy-paste ready)
- Testing checklist
- Effort estimate breakdown
- Next steps and strategic recommendations

**Use when**: Seeing what output actually looks like before running first review

---

### Expert Instruction Modules (agents/)

**agents/ux-designer.md** (4KB)
- Analysis framework: task flow, visual hierarchy, interaction patterns, consistency, accessibility-aware design
- Specific checks for: forms, navigation, buttons, lists/tables, modals
- Report structure: strengths, usability gaps, design system alignment, fix instructions, testing recommendations
- Output format with examples

**agents/accessibility.md** (9KB)
- WCAG 2.1 framework (4 principles: Perceivable, Operable, Understandable, Robust)
- Core checks (priority order): color contrast, keyboard navigation, screen reader compatibility, motion sensitivity, form accessibility
- For each check: criteria number, specific requirements, common failures, test method, report format with code examples
- Test tools and severity levels
- Comprehensive checklist

**agents/frontend.md** (10KB)
- Analysis areas: component architecture, state management, performance optimization, browser compatibility, code quality, TypeScript usage, testing
- Common React anti-patterns (7 examples with fixes)
- Performance metrics and baselines
- Code review checklist (10 items)
- Output format with examples

**agents/design-critic.md** (12KB)
- Analysis framework: strategic alignment, differentiation, risk assessment, business impact, future-proofing, competitive analysis
- Specific interrogation areas: design system debt, brand coherence, content and copy
- Red flags to investigate (15+ categories)
- Output format with business cases
- Strategic questions to ask (8 key questions)
- Tone and approach guidance

**agents/orchestrator.md** (11KB)
- De-duplication strategy (how to combine overlapping findings)
- Prioritization framework (impact + effort + dependencies)
- Priority matrix
- Report structure (7 sections)
- Expert perspectives (how to present findings)
- Handling disagreements between agents
- What NOT to include
- Edge cases
- Final checklist before returning report
- Success criteria for the report

---

## Quick Reference by Task

### "I want to understand what this is"
1. Read: README_DELIVERY.md
2. Skim: QUICKSTART.md
3. Review: SKILL.md

**Total time**: ~10 minutes

### "I want to see an example"
1. Read: EXAMPLE_REPORT.md

**Total time**: ~15 minutes

### "I want to use it right now"
1. Have your prototype ready
2. Go to "How to Activate" in INSTALLATION.md
3. Provide context + code to Claude
4. Request design review
5. Get report back
6. Follow fix instructions

**Total time**: ~30 minutes

### "I want to understand each expert"
1. Read: agents/ux-designer.md
2. Read: agents/accessibility.md
3. Read: agents/frontend.md
4. Read: agents/design-critic.md
5. Read: agents/orchestrator.md

**Total time**: ~30 minutes

### "I want to customize for my needs"
1. Read: INSTALLATION.md "Customization" section
2. Edit relevant agent files
3. Update orchestrator.md if changing prioritization
4. Test on a prototype
5. Iterate

**Total time**: ~1-2 hours

### "I need setup help"
1. Read: INSTALLATION.md entirely

**Total time**: ~15 minutes

---

## Content Map

### Accessibility
- **SKILL.md**: High-level overview
- **README.md**: Detailed explanation with examples
- **agents/accessibility.md**: Complete WCAG audit framework (most detailed)
- **EXAMPLE_REPORT.md**: Real-world accessibility findings with fixes

### Design & UX
- **SKILL.md**: Description of UX perspective
- **README.md**: What UX Designer looks for
- **agents/ux-designer.md**: UX analysis framework
- **EXAMPLE_REPORT.md**: UX findings with consolidation examples

### Code Quality
- **SKILL.md**: Description of Frontend Engineer perspective
- **README.md**: What Frontend Engineer looks for
- **agents/frontend.md**: Comprehensive code analysis framework
- **EXAMPLE_REPORT.md**: Code quality findings with refactoring examples

### Strategy & Business
- **SKILL.md**: Description of Design Critic perspective
- **README.md**: Strategic assessment explanation
- **agents/design-critic.md**: Strategic analysis framework (most detailed)
- **EXAMPLE_REPORT.md**: Strategic findings with business case

### Synthesis & Execution
- **SKILL.md**: Overview of orchestration
- **README.md**: How findings are prioritized
- **agents/orchestrator.md**: Complete synthesis framework
- **EXAMPLE_REPORT.md**: Unified fix instructions and testing checklist

---

## Usage Scenarios

### Scenario 1: "I'm building a form for ZAG"
Files to read:
- README_DELIVERY.md (focus on "For Your Current Projects" section)
- README.md (focus on "What the Report Looks Like")
- EXAMPLE_REPORT.md (form example is most relevant)

Steps:
1. Build form in Claude Code
2. Trigger review with: "Review this ZAG form using design-review-cowork skill. Goal: Enterprise customer onboarding, Audience: 40-60 year old IT managers, Constraints: WCAG AA, IE11"
3. Follow Critical fixes first (accessibility)
4. Apply High priority next (code quality)

### Scenario 2: "I need accessibility audit"
Files to read:
- agents/accessibility.md (the authoritative WCAG reference)
- EXAMPLE_REPORT.md (accessibility section, lines XXX-XXX)

Steps:
1. Trigger review with emphasis: "Focus on accessibility compliance (WCAG AA)"
2. Review all Critical findings (legal compliance)
3. Use testing checklist to validate fixes
4. Run with real screen reader before shipping

### Scenario 3: "I want to understand performance impact"
Files to read:
- agents/frontend.md (section: "Performance Optimization")
- EXAMPLE_REPORT.md (frontend section)

Steps:
1. Trigger review with: "Focus on performance optimization"
2. Read performance findings
3. Apply refactoring instructions
4. Measure with Lighthouse before/after

### Scenario 4: "I'm customizing for my team"
Files to read:
- INSTALLATION.md (Customization section)
- agents/*.md (the specific frameworks you want to modify)

Steps:
1. Identify which agent(s) to modify
2. Read their instruction file
3. Make your changes
4. Test on a prototype
5. Iterate until satisfied

### Scenario 5: "I disagree with a finding"
Files to read:
- agents/[relevant-expert].md (to understand the framework)
- README.md ("Common Feedback Patterns" or "FAQ")

Steps:
1. Find the finding in the agent file
2. Understand the reasoning (usually WCAG criterion or proven best practice)
3. If it's objective (WCAG), it's not optional; if strategic, you can disagree with business reasoning
4. Adjust agent file if you disagree with framework

---

## File Sizes

| File | Size | Type |
|------|------|------|
| EXAMPLE_REPORT.md | 28KB | Documentation |
| agents/design-critic.md | 12KB | Agent Framework |
| agents/orchestrator.md | 11KB | Agent Framework |
| README.md | 12KB | Documentation |
| agents/frontend.md | 10KB | Agent Framework |
| agents/accessibility.md | 9KB | Agent Framework |
| SKILL.md | 13KB | Definition |
| INSTALLATION.md | 9KB | Setup |
| README_DELIVERY.md | 7KB | Overview |
| QUICKSTART.md | 5KB | Reference |
| agents/ux-designer.md | 4KB | Agent Framework |
| **TOTAL** | **145KB** | **11 Files** |

---

## What Each File Teaches You

**To understand the philosophy**: README_DELIVERY.md  
**To understand the output**: EXAMPLE_REPORT.md  
**To understand how to use it**: README.md  
**To understand how it works**: agents/orchestrator.md  
**To understand accessibility**: agents/accessibility.md  
**To understand UX perspective**: agents/ux-designer.md  
**To understand code quality**: agents/frontend.md  
**To understand strategy**: agents/design-critic.md  
**To understand business impact**: README_DELIVERY.md + agents/design-critic.md  
**To set it up**: INSTALLATION.md  
**To customize it**: INSTALLATION.md + agents/*.md  
**To troubleshoot**: INSTALLATION.md, FAQ in README.md  
**For quick reference**: QUICKSTART.md  

---

## Getting Help

**"How do I use this?"**  
→ README.md + EXAMPLE_REPORT.md

**"How do I set it up?"**  
→ INSTALLATION.md

**"Why should I use this?"**  
→ README_DELIVERY.md

**"What will I get?"**  
→ EXAMPLE_REPORT.md

**"How do I customize it?"**  
→ INSTALLATION.md + agents/[specific].md

**"What if I disagree?"**  
→ agents/[relevant-expert].md (understand the reasoning first)

**"What's the best way to run a review?"**  
→ README.md "Tips for Best Results"

**"What accessibility standard should I use?"**  
→ INSTALLATION.md "WCAG Compliance Levels"

**"How do I know if the fix worked?"**  
→ EXAMPLE_REPORT.md (see "Verify" sections) or README.md (Testing Checklist)

---

## Checklist: Before Your First Review

- [ ] Read README_DELIVERY.md (5 min)
- [ ] Read EXAMPLE_REPORT.md (10 min)
- [ ] Have a prototype built in Claude Code
- [ ] Understand your goal (what is this component for?)
- [ ] Know your audience (who uses this?)
- [ ] Identify constraints (WCAG level? Browser support? Performance target?)
- [ ] Provide complete code (not snippets)
- [ ] Trigger the review in Cowork

---

## Checklist: For First Customization

- [ ] Read INSTALLATION.md "Customization" section
- [ ] Identify which agent(s) to modify
- [ ] Read the relevant agents/*.md file(s)
- [ ] Make your changes
- [ ] Run a test review on a prototype
- [ ] Iterate until satisfied
- [ ] Document your customizations

---

## Next Action

**Right now:**
Pick one file above and start reading based on what you need to know.

**In 5 minutes:**
You'll understand what this skill does.

**In 30 minutes:**
You can trigger your first review.

**In 3 hours:**
You can have a prototype analyzed, critical fixes applied, and ready to ship.

---

**Everything is ready. Start with README_DELIVERY.md, then build something to review.**

Sir, you have the tools. Let's use them.
