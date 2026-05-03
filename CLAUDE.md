# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cooking with Basil is a **home meal planning app** built as a static frontend backed by Supabase (hosted PostgreSQL + auth + realtime). The app is designed to be hosted, shareable, and collaborative with friends and family. (Previously named "Modular Meals" — the core product vision is unchanged.)

## Architecture

```
Static Host (GitHub Pages / Netlify / Vercel)
    |
app/home.html  (single-page app — HTML/CSS/JS)
    |
Supabase JS Client (CDN)
    |
Supabase (hosted)
├── PostgreSQL (recipes table)
├── Auth (email-based, invite collaborators)
├── Row Level Security (read: public, write: authenticated)
└── Edge Functions (parse-recipe: URL scrape + Claude-based recipe extraction)
```

## Key Files

- **app/home.html** — The entire frontend app. Search, filter, view, import wizard, edit/delete, auth.
- **app/seed.html** — One-time migration script to seed Supabase from recipes_data.json + staging stubs.
- **app/recipes_data.json** — Legacy JSON export of all recipes (backup/reference only).
- **supabase/schema.sql** — Database schema (run in Supabase SQL Editor to set up).
- **supabase/functions/parse-recipe/index.ts** — Edge Function: the single source of truth for recipe parsing. Fetches URLs server-side, tries JSON-LD first, falls back to Claude Sonnet 4.6 (tool-use for structured output, prompt caching on the system prompt). Handles `kind: 'url' | 'html' | 'text' | 'images'`.
- **CONCEPT.md** — Core vision, problem statement, v1 feature set, brand principles.
- **VALIDATION-PLAN.md** — Kill/continue decision gates, assumption tracker, risk register.

## Database Schema

Recipes live in a Supabase PostgreSQL `recipes` table with columns:
`id` (uuid), `title`, `source`, `added`, `updated`, `tags` (text[]), `summary`, `prep_time`, `cook_time`, `total_time`, `servings`, `yield`, `difficulty`, `cuisine`, `ingredients`, `instructions`, `notes`, `shopping_tags`, `status` (complete/incomplete), `import_source`, `completeness` (0-100), `created_by`, `created_at`

## Configuration

In `app/home.html`, replace these placeholders with your Supabase project credentials:
```
var SUPABASE_URL = 'YOUR_SUPABASE_URL';
var SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

## Recipe Pipeline

Import wizard (in app) handles all recipe ingestion:
1. Source selection: paste text, URL, PDF upload (text mode or image mode), or manual entry
2. Auto-parsing via the `parse-recipe` edge function:
   - **URL / HTML**: JSON-LD fast path first (free, instant); falls back to Claude Sonnet 4.6 if the page has no usable JSON-LD.
   - **Text / pasted content**: Claude Sonnet 4.6 text extraction.
   - **PDF text mode**: pdf.js extracts embedded text → Claude text extraction. Cheap; works for modern PDFs.
   - **PDF image mode**: pdf.js renders each page to a PNG → Claude vision. Use for scanned cookbooks / handwritten recipes. Capped at 10 pages.
3. Edit & review: user corrects gaps, sees parse-method pill + any parser warnings + completeness score.
4. Save: writes to `recipes` (with FK keys) + syncs `recipe_tags`. Writes an audit row to `import_logs`.

**Edge-function secret**: `ANTHROPIC_API_KEY` must be set via
`supabase secrets set ANTHROPIC_API_KEY=sk-ant-…` before Claude paths will work.
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

Tables (see `supabase/schema.sql` + `supabase/migrations/2026-04-12-taxonomy-and-protein.sql`):
- **categories** — drives the category-nav. Columns: `key`, `label`, `icon_path`, `match_keywords[]`, `sort_order`.
- **proteins** — `vegetarian` | `fish` | `adaptable` | `meat`. Stored on `recipes.protein` (single-valued, filterable).
- **cuisines** — canonical lowercase keys (e.g. `italian`). Referenced by `recipes.cuisine` (unenforced).
- **difficulties** — `easy` | `medium` | `hard`. Referenced by `recipes.difficulty`.
- **tag_vocab** — open taxonomy keyed by `kind` (`occasion`, `season`, `meal_type`, `style`, `other`). Drives wizard autocomplete.

Recipe tags stay free-form in `recipes.tags text[]`. The wizard uses a `<datalist>`
against `tag_vocab` for autocomplete but does not reject unseen values — unknown
tags still surface in the filter dropdown alongside the canonical vocab.

## Legacy / Cleanup

The `_delete/` folder contains files from the pre-Supabase era (markdown recipes, staging stubs, INDEX.md, RECIPE-TEMPLATE.md, IMPORT-SOP.md). These can be permanently removed after verifying the Supabase migration is complete.

## Product Vision

The core insight from CONCEPT.md: the value is in the **planning layer**, not the recipe database. Competitors do recipe storage; the differentiation is a plan-first workflow (weekly meal planner -> shopping list) with modular recipe components (reusable sauces, bases, grains).

v1 scope: URL recipe import -> clean library -> weekly planner -> shopping list export. No pantry tracking or meal ratings in v1.

## Writing voice

When drafting prose on Chris's behalf in this repo - READMEs, docs, commit messages, user-facing app copy (empty states, error messages, onboarding), CONCEPT.md edits, marketing content, anything written - apply the **chris-voice** skill. The skill is the default for content creation. Skip it only for raw code itself, template-driven technical specs where voice is not the point, or content explicitly meant to mimic someone else's voice. The skill also enforces the no-em-dashes rule.
