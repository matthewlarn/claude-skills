# Design Review Skill - Expert Agents Guide

This document explains each specialist agent, when to use them, and what they provide.

## Core Agents (Always Included)

### 1. UX Designer Agent
**File**: agents/ux-designer.md (4KB)

**What it does**:
- Evaluates user task flows and information architecture
- Assesses interaction patterns and micro-interactions
- Reviews visual consistency and design system alignment
- Identifies usability gaps and friction points

**Example findings**:
- "Button styles inconsistent (4 variants) - consolidate to 2"
- "Form has unclear primary action - users won't know what to do"
- "Whitespace is too tight - breathing room needed"

**When to use**:
- Every prototype (always run)
- When user experience matters
- When design consistency is important

**Effort to fix**: 15 min to 2 hours (usually medium)

---

### 2. Accessibility Specialist Agent
**File**: agents/accessibility.md (9KB)

**What it does**:
- Audits WCAG 2.1 Level AA compliance (legal standard)
- Checks color contrast, keyboard navigation, screen reader compatibility
- Verifies form accessibility and motion sensitivity
- Maps findings to specific WCAG criteria

**Example findings**:
- "Color contrast 2.8:1 fails WCAG AA (need 4.5:1) - change #666 to #333"
- "Input not associated with label - screen reader users don't know field purpose"
- "Animations ignore prefers-reduced-motion preference"

**When to use**:
- Every prototype (required for shipping)
- When government/enterprise customers required (often mandate AA)
- Legal compliance critical

**Effort to fix**: 15 min to 2 hours (usually critical but quick)

---

### 3. Frontend Engineer Agent
**File**: agents/frontend.md (10KB)

**What it does**:
- Reviews component architecture and reusability
- Flags prop drilling, state management issues
- Identifies performance bottlenecks (unnecessary re-renders)
- Checks browser compatibility and TypeScript safety
- Assesses code quality and testing gaps

**Example findings**:
- "Prop drilling 3 levels deep - extract to context or hook"
- "Form input re-renders entire form (40+ unnecessary re-renders) - memoize components"
- "4 button variants without documentation - consolidate and document"
- "No type safety on props - add TypeScript interfaces"

**When to use**:
- Every prototype (always run)
- When code reusability matters
- When performance is critical
- When scalability will be needed

**Effort to fix**: 30 min to 4 hours (often medium-high)

---

### 4. Design Critic Agent (Strategic)
**File**: agents/design-critic.md (12KB)

**What it does**:
- Assesses strategic alignment with brand and business goals
- Identifies competitive gaps and differentiation opportunities
- Flags scalability risks and technical debt
- Calculates business impact and ROI
- Evaluates future-proofing and long-term costs

**Example findings**:
- "Custom button system costs 2x refactoring in 6 months - standardize now"
- "Form onboarding friction could cost $3k/month in lost transactions"
- "Market leaders use this pattern - we should too for competitiveness"
- "Design decisions not documented - creates training burden as team scales"

**When to use**:
- Every prototype (always run)
- When business impact matters
- When scalability is a concern
- When competitive positioning is important

**Effort to fix**: 2 hours to 2+ days (varies widely)

---

## Optional Specialist Agents (Request as Needed)

### 5. Performance Optimization Agent
**File**: agents/performance.md (13KB)

**What it does**:
- Audits Core Web Vitals (LCP, INP, CLS)
- Analyzes bundle size and code splitting
- Identifies rendering performance issues
- Reviews image optimization
- Evaluates network efficiency
- Assesses user-perceived performance

**Example findings**:
- "LCP: 4.2s, target <2.5s - optimize images (75% improvement possible)"
- "Bundle 450KB gzipped, target <100KB - code split by route"
- "Input re-renders entire form - 40% performance improvement with memoization"
- "Images not lazy loaded - loading 6 below-fold images unnecessarily"

**When to use**:
- When performance is critical (mobile, slow networks)
- When user experience must be fast
- When Core Web Vitals matter (SEO, business metrics)
- Enterprise platforms where performance = reliability

**Request with**: "Include performance specialist" or "Focus on Core Web Vitals"

**Effort to fix**: 30 min to 2+ hours (depends on issue)

---

### 6. Brand Consistency Agent
**File**: agents/brand-consistency.md (14KB)

**What it does**:
- Reviews brand alignment (visual identity, tone, messaging)
- Audits design system usage (colors, typography, spacing)
- Identifies component duplication and extraction opportunities
- Checks Figma-to-code fidelity
- Assesses design token implementation

**Example findings**:
- "15 unique colors with no system - consolidate to 6 semantic colors with tokens"
- "Button component defined 4 times - extract to single reusable component"
- "Typography has 12 sizes (no scale) - define 6-size scale"
- "Figma design ≠ code implementation - use Code Connect to keep in sync"

**When to use**:
- When design system matters (team will scale)
- When brand consistency is critical
- When you have a design system to maintain
- When Figma-to-code alignment is needed

**Request with**: "Include brand consistency specialist" or "Design system audit"

**Effort to fix**: 2 hours to 2+ days (system-wide changes are larger)

---

### 7. Business Strategy Agent
**File**: agents/business-strategy.md (15KB)

**What it does**:
- Analyzes business model alignment
- Calculates user acquisition and conversion impact
- Assesses retention and engagement implications
- Evaluates competitive positioning
- Identifies monetization and ecosystem opportunities

**Example findings**:
- "Onboarding friction could reduce conversion 60% → 80% (+$3k/month revenue)"
- "Alert creation 8 steps → 3 steps could improve engagement 60% and retention 25%"
- "Creator premium tier could add $2k/month revenue at low effort"
- "Real-time impact tracking differentiates vs. competitors (defensible moat)"

**When to use**:
- When business impact is critical
- For user acquisition or retention features
- When monetization is a consideration
- For founder/leadership stakeholders

**Request with**: "Include business strategist" or "Business impact analysis"

**Effort to fix**: Variable (often requires product decisions, not just code fixes)

---

## How to Use Optional Agents

### Option 1: Request Specific Agents
```
Review this form using the design-review-cowork skill.
Include these agents: UX Designer, Accessibility, Frontend Engineer, Performance Specialist
Goal: [your goal]
...
```

### Option 2: Request Focus Area
```
Review this dashboard with focus on performance (Core Web Vitals).
Goal: [your goal]
...
```

### Option 3: Request All Specialists
```
Comprehensive review: include all available agents.
Goal: [your goal]
...
```

### Option 4: Default (Core Agents Only)
```
Review this component.
Goal: [your goal]
...
```
→ Uses UX Designer, Accessibility, Frontend Engineer, Design Critic (always included)

---

## Agent Selection by Project

### ZAG (Circular Economy Marketplace)
- **Always**: UX Designer, Accessibility, Frontend Engineer, Design Critic
- **Often**: Business Strategy (transaction volume impact), Brand Consistency (B2B trust)
- **Sometimes**: Performance (real-time impact tracking is compute-heavy)

### Chronosphere (Monitoring Platform)
- **Always**: UX Designer, Accessibility, Frontend Engineer, Design Critic
- **Often**: Performance (core competency), Business Strategy (engagement loops)
- **Sometimes**: Brand Consistency

### Clap (Interactive Video)
- **Always**: UX Designer, Accessibility, Frontend Engineer, Design Critic
- **Often**: Business Strategy (creator/brand onboarding), Performance (video rendering)
- **Sometimes**: Brand Consistency

### Vaughn Physics (Education)
- **Always**: UX Designer, Accessibility, Frontend Engineer, Design Critic
- **Often**: Business Strategy (engagement/retention), Performance (learning outcomes)
- **Sometimes**: Brand Consistency

---

## Agent Capability Matrix

| Agent | UX | A11y | Code | Performance | Design System | Business | Strategy |
|-------|----|----|------|-----------|--------------|----------|----------|
| UX Designer | ⭐⭐⭐ | ⭐ | | | ⭐⭐ | | ⭐⭐ |
| Accessibility | ⭐ | ⭐⭐⭐ | | | | | |
| Frontend | | | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | | |
| Performance | ⭐ | | ⭐⭐ | ⭐⭐⭐ | | ⭐ | |
| Brand | ⭐⭐⭐ | | ⭐⭐ | | ⭐⭐⭐ | | ⭐⭐ |
| Business | | | | ⭐ | | ⭐⭐⭐ | ⭐⭐⭐ |
| Design Critic | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ |

---

## Effort Estimates by Agent Type

| Agent | Typical Effort Range | Quick Wins | Big Efforts |
|-------|-----|-----------|-----------|
| UX Designer | 15 min - 2 hours | Button consolidation | Complete redesign |
| Accessibility | 15 min - 2 hours | Color contrast, a11y attrs | Keyboard nav overhaul |
| Frontend | 30 min - 4 hours | Memoization, refactoring | Arch redesign, new hooks |
| Performance | 1 hour - 2+ days | Image optimization, lazy loading | Code splitting, rewrite |
| Brand | 2 hours - 2+ days | Color consolidation, token setup | System-wide redesign |
| Business | Variable | Onboarding reorder | Feature redesign, new tiers |
| Design Critic | 2 hours - 2+ days | Technical debt surfacing | Major strategic decisions |

---

## Quick Decision Tree

**Choosing which agents to request:**

```
START
  ├─ Is this going to ship to users?
  │  └─ YES → Always include: UX Designer, Accessibility, Frontend, Design Critic
  │
  ├─ Is performance critical?
  │  └─ YES → Add: Performance Specialist
  │
  ├─ Does this need to scale?
  │  └─ YES → Add: Brand Consistency (design system) or Business Strategy
  │
  ├─ Is this user-facing and revenue-impacting?
  │  └─ YES → Add: Business Strategy
  │
  ├─ Is design consistency important?
  │  └─ YES → Add: Brand Consistency
  │
  └─ DONE → You have your agent selection
```

---

## Common Review Scenarios

### Scenario 1: "Quick Design Review Before Ship"
Agents: UX Designer, Accessibility, Frontend Engineer
Time: ~30 minutes for review, 1-2 hours for fixes
Focus: Usability, a11y compliance, code quality

### Scenario 2: "Comprehensive Product Review"
Agents: All (7 agents)
Time: ~1 hour for review, 4-8 hours for major fixes
Focus: Everything - ship-ready, scalable, strategic

### Scenario 3: "Performance Optimization Pass"
Agents: Performance, Frontend Engineer, Design Critic
Time: ~30 minutes for review, 2-6 hours for fixes
Focus: Core Web Vitals, bundle size, rendering efficiency

### Scenario 4: "Design System Implementation"
Agents: Brand Consistency, UX Designer, Frontend Engineer
Time: ~30 minutes for review, 4-8 hours for implementation
Focus: Colors, typography, spacing, component extraction

### Scenario 5: "Business Impact Analysis"
Agents: Business Strategy, Design Critic, UX Designer
Time: ~30 minutes for review, variable for implementation
Focus: Revenue, retention, competitive positioning

### Scenario 6: "Scaling Check" (before handoff)
Agents: Brand Consistency, Design Critic, Business Strategy
Time: ~20 minutes for review, variable for fixes
Focus: Will this scale? What debt are we creating?

---

## Requesting Multiple Reviews

You can request multiple reviews of the same component:

**First pass**: UX Designer + Accessibility (usability + compliance)
→ Fix and ship

**Second pass** (next sprint): Frontend + Performance (code quality + speed)
→ Technical debt cleanup

**Third pass** (planning): Brand Consistency + Business Strategy (scaling)
→ Next quarter planning

This staggered approach lets you ship quickly while building quality incrementally.

---

## When to Request Each Agent Alone

**Just UX Designer**: "Is this intuitive? Will users understand how to use it?"
→ Early sketches, user testing prep

**Just Accessibility**: "Does this meet legal compliance?"
→ Compliance audit, enterprise sales prep

**Just Frontend**: "Is this well-architected and maintainable?"
→ Code review, refactoring session

**Just Performance**: "Can we make this faster?"
→ Performance optimization sprint

**Just Brand Consistency**: "Does this fit our design system?"
→ Design system adherence check

**Just Business Strategy**: "What's the business impact of this feature?"
→ Product strategy, business case building

**Just Design Critic**: "Is this the right decision long-term?"
→ Strategic planning, risk assessment

---

## Agent Handoff Protocol

If you're working with a team:

1. **Share the agent files** with your team
2. **Assign agents** based on expertise (designer → UX, engineer → Frontend)
3. **Each person reviews** independently using their agent's framework
4. **Orchestrator synthesizes** all findings into unified report
5. **Team prioritizes** fixes together

This ensures consistent, thorough review regardless of who's reviewing.

---

## Tips for Best Results

1. **Provide complete context**: Each agent works better with full information
2. **Be clear on constraints**: "WCAG AA required" or "performance critical"
3. **Request focus areas**: "Prioritize accessibility and design system" narrows output
4. **Review findings with team**: Discuss why findings matter before prioritizing
5. **Implement systematically**: Do critical fixes, then strategic improvements, then optimizations

---

All agents are available at `/home/claude/design-review-skill/agents/`

