# Cooking with Basil — Product Concept

> Last updated: 2026-03-20
> Status: Exploring (napkin sketch → structured concept)
> Canonical venture file: fv-admin/memory/ventures/modular-meals.md

---

## The Problem

Home meal planning is broken in three ways:

1. **Recipe discovery is hostile.** The recipe internet is ad-stuffed, SEO-gamed, and disrespectful of the user's time. Finding and saving a recipe means wading through life stories, autoplay videos, and pop-ups.

2. **Recipe storage is fragmented.** Recipes live across bookmarks, screenshots, Notes, cookbooks, and texts from friends. There's no clean, consolidated personal library.

3. **Planning a week is manual and tedious.** Building a coherent week of meals — balancing variety, ingredient efficiency, schedule, and preferences — is done on paper or in someone's head. The gap between "what should we eat" and "what do we need to buy" has no good bridge.

## The Insight

Most recipe/meal apps are **recipe-first**: browse, save, maybe plan. The actual job-to-be-done for a busy household is **plan-first**: "Help me build a good week of meals from one shopping trip."

The planning layer — not the recipe database — is where the value lives.

## Core Experience (v1 Vision)

### 1. Clean Recipe Library
- Import recipes via URL — the app strips ads, narratives, and noise; extracts structured recipe data
- Manual add for family recipes, modifications, personal notes
- Recipes stored as clean, structured data: ingredients (parsed), steps, tags, prep/cook time

### 2. Weekly Meal Planner (Primary Interface)
- Drag-and-drop weekly view: assign meals to days/slots (dinner, lunch, etc.)
- The system shows ingredient overlap between planned meals
- Visual indicator of shopping efficiency ("these 4 meals share 60% of ingredients")
- Constraints: schedule (busy Tuesday = leftovers), preferences, dietary needs

### 3. Smart Shopping List
- Auto-generated from the week's meal plan
- Ingredients consolidated and de-duplicated across recipes
- Grouped by store section (produce, dairy, pantry, etc.)
- Exportable — v1: share sheet / copy to clipboard → Apple Notes

### 4. (Future) Modular Components
- Identify reusable components across recipes (sauces, bases, grains, proteins)
- Suggest batch-prep opportunities: "Make chimichurri Sunday, use in 3 meals this week"
- This is aspirational — the app must be valuable WITHOUT this feature

## What This Is NOT
- Not a social recipe platform (no feeds, no followers, no engagement metrics)
- Not a diet/nutrition tracker (no calorie counting, no macros as primary feature)
- Not a meal kit / grocery delivery service
- Not an AI chef that tells you what to cook (the user's creativity and taste are primary)

## Brand Principles
| Principle | Meaning |
|-----------|---------|
| **Respect the user's time** | No fluff, no friction, fast to useful output |
| **Enable creativity** | The user explores their own taste, not an algorithm's suggestions |
| **Authenticity** | No ads, no dark patterns, no engagement farming |
| **Clean data** | Recipes are structured, parseable, portable — the user owns their data |

## User Model (n=1 → Consumer)

### Chris's Household (n=1 validation target)
- 2 adults, 1 toddler (nearly 3)
- Ideal week: 3-4 home-cooked meals, 1 eating out, leftovers fill remaining
- 1 shopping trip per week
- Values: efficiency (shared ingredients), variety, creativity
- Current tools: scattered bookmarks, Apple Notes shared shopping list
- Planning approach: hybrid inspiration + logistics (mood-dependent)

### Hypothesized Consumer Profile
- Home cook who plans meals (or wants to)
- Frustrated by recipe site experience
- Values efficiency and organization
- Likely 28-45, household with 2+ people
- Willing to pay for a tool that respects their time (anti-free-with-ads)

## Competitive Positioning

The hypothesis: existing apps are either recipe-first with planning bolted on, or prescriptive meal planners that remove user agency. There's a gap for a plan-first tool that treats the user as a creative cook, not a passive consumer.

**Must validate by actually using competitors.** See validation plan.

## Open Design Questions
1. Mobile-first or web-first? (Planning may be desktop; cooking is mobile)
2. How opinionated should the ingredient parser be? (Units, substitutions, quantities)
3. Does the weekly view support flexible household patterns? (Not everyone does M-F dinner)
4. How does the app handle recipes that serve different household sizes?
5. Is there a "pantry" concept (what you already have) that reduces the shopping list?

## Revenue Model (TBD)
Options to evaluate:
- One-time purchase (aligns with "respect the user" brand, limits recurring revenue)
- Low-cost subscription ($3-5/mo for premium features)
- Freemium (core free, planning features gated)
- No decision needed until post-validation

---

## Validation Roadmap

### Phase 0: Competitor Immersion (Next 2-4 weeks)
- [ ] Use Plan to Eat as primary meal planner for 2 weeks
- [ ] Use Paprika as primary recipe manager for 2 weeks
- [ ] Document: what works, what's missing, what's frustrating
- [ ] Decision: is the gap real enough to build for?

### Phase 1: n=1 Prototype (If Phase 0 confirms gap)
- [ ] Define minimum feature set Chris would use weekly
- [ ] Technical spike: URL recipe import / parsing
- [ ] Build bare-bones planning + shopping list flow
- [ ] Use it personally for 4 weeks
- [ ] Decision: does this solve the problem for me?

### Phase 2: Consumer Signal (If Phase 1 confirms utility)
- [ ] Share with 5-10 friends/family who meal plan
- [ ] Landing page + waitlist to test positioning
- [ ] Decision: is there demand beyond n=1?
