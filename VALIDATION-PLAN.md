# Cooking with Basil — Validation Plan

> Last updated: 2026-03-20
> Decision framework: low-cost, reversible decisions; kill fast if assumptions fail

---

## Guiding Principle
Validate the **problem** before building the **solution**. Each phase has an explicit kill/continue decision gate.

## Phase 0: Competitor Immersion
**Goal:** Confirm the gap is real, not just intuition.
**Duration:** 2-4 weeks
**Cost:** $0-20 (app subscriptions)

### Tasks
- [ ] Sign up for Plan to Eat — use as primary meal planner for 2 full weeks
- [ ] Sign up for Paprika — use as primary recipe manager for 2 full weeks
- [ ] Also briefly try: Mealime, Whisk, Notion meal planning templates
- [ ] For each, document in `competitor-notes/`:
  - What works well
  - What's frustrating or missing
  - How close it comes to the "plan-first" workflow
  - Would you keep using it? Why or why not?

### Decision Gate
| Signal | Action |
|--------|--------|
| An existing app solves 80%+ of the problem | **Kill or pivot** — contribute to that ecosystem instead |
| Clear gaps in plan-first workflow across all apps | **Continue to Phase 1** |
| Gaps exist but are minor / cosmetic | **Pause** — not worth building for marginal improvement |

## Phase 1: n=1 Prototype
**Goal:** Build the minimum tool Chris would actually use every week.
**Duration:** 4-6 weeks
**Cost:** Time + hosting (~$0-20/mo)

### Tasks
- [ ] Define MVP feature set (informed by Phase 0 gaps)
- [ ] Technical spike: URL recipe import (JSON-LD, microdata, fallback scraper)
- [ ] Build bare-bones: recipe storage + weekly planner + shopping list export
- [ ] Use it personally for 4+ consecutive weeks
- [ ] Track: did I actually use it? What did I reach for instead?

### Decision Gate
| Signal | Action |
|--------|--------|
| Chris uses it every week and it replaces current workflow | **Continue to Phase 2** |
| Chris uses it sometimes but reverts to old habits | **Iterate** — identify what's pulling you back |
| Chris stops using it within 2 weeks | **Kill or fundamentally rethink** |

## Phase 2: Consumer Signal
**Goal:** Does anyone else want this?
**Duration:** 4-8 weeks
**Cost:** $100-500 (landing page, basic marketing)

### Tasks
- [ ] Share prototype with 5-10 friends/family who meal plan
- [ ] Collect qualitative feedback: what resonates, what's confusing
- [ ] Build landing page with positioning + waitlist
- [ ] Test 2-3 positioning angles (e.g., "plan-first" vs. "no-fluff recipes" vs. "efficient home cooking")
- [ ] Light marketing: share in relevant communities, social
- [ ] Track: waitlist signups, engagement quality, willingness to pay signal

### Decision Gate
| Signal | Action |
|--------|--------|
| 100+ waitlist signups with organic interest | **Continue to Phase 3** (build for real) |
| Strong qualitative signal but low volume | **Refine positioning**, extend Phase 2 |
| Low interest / "nice but I wouldn't pay" | **Kill or reposition** as personal tool only |

## Phase 3: Build & Launch (Future — details TBD)
Only plan this after Phase 2 validates demand.

---

## Assumptions Tracker
Cross-referenced with venture file. Update as evidence emerges.

| # | Assumption | Validated? | Evidence | Date |
|---|-----------|------------|----------|------|
| A1 | Existing apps fail at plan-first workflow | — | Pending Phase 0 | — |
| A2 | URL recipe import is technically feasible | — | Pending Phase 1 spike | — |
| A3 | Users think in weekly plans, not individual recipes | — | True for Chris (n=1) | 2026-03-20 |
| A4 | Modular component reuse appeals to home cooks | — | Aspirational even for Chris | 2026-03-20 |
| A5 | No-ads clean experience is sufficient differentiation | — | Pending Phase 2 | — |
| A6 | Shopping list export (not in-app ordering) is sufficient v1 | Assumed | Chris uses Apple Notes | 2026-03-20 |

## Risk Register
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Competitor already does this well enough | Medium | High (kills venture) | Phase 0 immersion |
| Recipe URL parsing is unreliable | Medium | Medium | Multiple extraction strategies; manual fallback |
| "Modular" cooking is niche behavior | High | Medium | Core app must work without modular features |
| Solo developer capacity (Chris has a day job) | High | Medium | Keep scope tiny; no-code/low-code where possible |
| Market is crowded and acquisition is expensive | High | Medium | Brand differentiation > feature differentiation |
