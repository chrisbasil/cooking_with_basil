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
└── Edge Functions (fetch-recipe: URL scraping for import)
```

## Key Files

- **app/home.html** — The entire frontend app. Search, filter, view, import wizard, edit/delete, auth.
- **app/seed.html** — One-time migration script to seed Supabase from recipes_data.json + staging stubs.
- **app/recipes_data.json** — Legacy JSON export of all recipes (backup/reference only).
- **supabase/schema.sql** — Database schema (run in Supabase SQL Editor to set up).
- **supabase/functions/fetch-recipe/index.ts** — Edge Function for CORS-free URL fetching during import.
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
1. Source selection: paste text, URL, PDF upload, or manual entry
2. Auto-parsing: extracts fields from text/HTML (JSON-LD support for recipe sites)
3. Edit & review: user corrects gaps, sees completeness score
4. Save: writes to Supabase with complete/incomplete status

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
