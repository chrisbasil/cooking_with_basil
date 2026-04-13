-- Cooking with Basil: Supabase Schema
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query)

-- ── Recipes Table ──────────────────────────────────────────
create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  source text,
  added date default current_date,
  updated timestamptz default now(),
  tags text[] default '{}',
  summary text,
  prep_time text,
  cook_time text,
  total_time text,
  servings text,
  yield text,
  difficulty text,
  cuisine text,
  ingredients text,
  instructions text,
  notes text,
  shopping_tags text,
  status text default 'complete' check (status in ('complete', 'incomplete')),
  import_source text,
  completeness int default 0,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  protein text -- FK-ish; references proteins(key). See migrations/2026-04-12-taxonomy-and-protein.sql
);

-- ── Indexes ────────────────────────────────────────────────
create index if not exists idx_recipes_status on public.recipes(status);
create index if not exists idx_recipes_cuisine on public.recipes(cuisine);
create index if not exists idx_recipes_tags on public.recipes using gin(tags);
create index if not exists idx_recipes_title_search on public.recipes using gin(to_tsvector('english', coalesce(title, '')));

-- ── Row Level Security ─────────────────────────────────────
alter table public.recipes enable row level security;

-- Only authenticated users can read recipes
drop policy if exists "Anyone can read recipes" on public.recipes;
drop policy if exists "Authenticated users can read recipes" on public.recipes;
create policy "Authenticated users can read recipes"
  on public.recipes for select
  using (auth.role() = 'authenticated');

-- Authenticated users can insert
drop policy if exists "Authenticated users can insert" on public.recipes;
create policy "Authenticated users can insert"
  on public.recipes for insert
  with check (auth.role() = 'authenticated');

-- Authenticated users can update
drop policy if exists "Authenticated users can update" on public.recipes;
create policy "Authenticated users can update"
  on public.recipes for update
  using (auth.role() = 'authenticated');

-- Authenticated users can delete
drop policy if exists "Authenticated users can delete" on public.recipes;
create policy "Authenticated users can delete"
  on public.recipes for delete
  using (auth.role() = 'authenticated');

-- ── Enable Realtime ────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'recipes'
  ) then
    alter publication supabase_realtime add table public.recipes;
  end if;
end $$;

-- ── Vocab Tables ───────────────────────────────────────────
-- Drive categories, proteins, cuisines, difficulties, and general tag vocab
-- from data rather than hardcoded JS. Seeded + normed by
-- migrations/2026-04-12-taxonomy-and-protein.sql.
create table if not exists public.categories (
  key text primary key,
  label text not null,
  icon_path text not null,
  match_keywords text[] not null default '{}',
  sort_order int not null default 0
);

create table if not exists public.proteins (
  key text primary key,
  label text not null,
  sort_order int not null default 0
);

create table if not exists public.cuisines (
  key text primary key,
  label text not null
);

create table if not exists public.difficulties (
  key text primary key,
  label text not null,
  sort_order int not null default 0
);

create table if not exists public.tag_vocab (
  key text primary key,
  label text not null,
  kind text not null
);

create index if not exists idx_recipes_protein on public.recipes(protein);

alter table public.categories   enable row level security;
alter table public.proteins     enable row level security;
alter table public.cuisines     enable row level security;
alter table public.difficulties enable row level security;
alter table public.tag_vocab    enable row level security;

-- RLS: anon read, authenticated write (matches recipes pattern).
-- Policies created in migrations/2026-04-12-taxonomy-and-protein.sql.
