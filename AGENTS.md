# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

Cooking with Basil is a **home meal planning app** built as a static frontend backed by Supabase (hosted PostgreSQL + auth + realtime). The app is designed to be hosted, shareable, and collaborative with friends and family. (Previously named "Modular Meals" — the core product vision is unchanged.)

## Key Files

- **app/home.html** — The entire frontend app. Shopping-list selection persists in localStorage under `cwb.*` keys.
- **app/seed.html** — One-time migration script that seeded Supabase from `recipes_data.json` + staging stubs. Historical; the migration is complete.
- **private/** — Gitignored folder for local-only files: the photo-scraping script, recipe mapping CSVs, the source URL list, and `private/reference/` SQL dumps. Never pushed. The old `recipes_data.json` export is no longer kept in the repo.
- **supabase/functions/parse-recipe/index.ts** — Edge Function: the single source of truth for recipe parsing. Handles `kind: 'url' | 'html' | 'text' | 'images'`; don't add a second parsing path in the client.
- **CONCEPT.md** — Core vision, problem statement, v1 feature set, brand principles.
- **VALIDATION-PLAN.md** — Kill/continue decision gates, assumption tracker, risk register.

## Adding a new table

Supabase stopped auto-granting Data API access to new `public` tables (full enforcement 2026-10-30). `supabase/migrations/2026-05-15-data-api-default-grants.sql` sets default privileges so future tables inherit the right grants — but be explicit in migrations regardless:

```sql
create table public.<name> ( ... );

grant select on public.<name> to anon;
grant select, insert, update, delete on public.<name> to authenticated;
grant all on public.<name> to service_role;

alter table public.<name> enable row level security;
-- ...policies...
```

If supabase-js returns `42501`, a grant is missing.

## Configuration

In `app/home.html`, set your Supabase project credentials:
```
var SUPABASE_URL = 'https://<project-ref>.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_...';   // new-style publishable key
```
Use the new publishable key (`sb_publishable_...`), not the legacy anon JWT. The
legacy JWT API keys are disabled on this project, so the old `eyJ...` anon key no
longer works. The publishable key is safe to embed in client code; RLS is the
security boundary. The site deploys from `main` via GitHub Pages, so the key has
to be committed to `home.html` to reach the live site.

## Recipe Pipeline

**Edge-function secret**: `ANTHROPIC_API_KEY` must be set via
`supabase secrets set ANTHROPIC_API_KEY=sk-ant-…` before Codex paths will work.
The JSON-LD fast path works without the secret.

**Debugging bad imports**: every import attempt (success or failure) writes a
row to `public.import_logs` with the input preview, parse method, raw parser
output, warnings, token usage, and linked `recipe_id`. Start there when an
import looks wrong. See `supabase/migrations/2026-04-16-import-logs.sql`.

No more staging folder — recipes are either complete or flagged incomplete in the DB.

## Taxonomy

Vocabularies live in Supabase — **not** hardcoded in JS. The app loads them at
startup via `loadVocab()` in `app/home.html` and caches them on `window.VOCAB`.
To add or rename a category/cuisine/tag, edit the row in Supabase; no deploy needed.
The vocab tables are `categories`, `proteins`, `cuisines`, `difficulties`, and
`tag_vocab` (see `supabase/schema.sql` + `supabase/migrations/2026-04-12-taxonomy-and-protein.sql`).

Recipe tags stay free-form in `recipes.tags text[]`. The wizard uses a `<datalist>`
against `tag_vocab` for autocomplete but does not reject unseen values — unknown
tags still surface in the filter dropdown alongside the canonical vocab.

## Product Vision

The core insight from CONCEPT.md: the value is in the **planning layer**, not the recipe database. Competitors do recipe storage; the differentiation is a plan-first workflow (weekly meal planner -> shopping list) with modular recipe components (reusable sauces, bases, grains).

v1 scope: URL recipe import -> clean library -> weekly planner -> shopping list export. No pantry tracking or meal ratings in v1.

## Writing voice

When drafting prose on Chris's behalf in this repo - READMEs, docs, commit messages, user-facing app copy (empty states, error messages, onboarding), CONCEPT.md edits, marketing content, anything written - apply the **chris-voice** skill. The skill is the default for content creation. Skip it only for raw code itself, template-driven technical specs where voice is not the point, or content explicitly meant to mimic someone else's voice.

If the chris-voice skill is not installed, apply these rules directly instead:
- Never use em dashes. Use a comma, a colon, a period, or a parenthesis.
- Write plainly and concretely. No marketing throat-clearing, no hedging, no filler adjectives. Say the thing.
