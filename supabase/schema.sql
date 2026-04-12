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
  created_at timestamptz default now()
);

-- ── Indexes ────────────────────────────────────────────────
create index if not exists idx_recipes_status on public.recipes(status);
create index if not exists idx_recipes_cuisine on public.recipes(cuisine);
create index if not exists idx_recipes_tags on public.recipes using gin(tags);
create index if not exists idx_recipes_title_search on public.recipes using gin(to_tsvector('english', coalesce(title, '')));

-- ── Row Level Security ─────────────────────────────────────
alter table public.recipes enable row level security;

-- Anyone (including anonymous) can read
create policy "Anyone can read recipes"
  on public.recipes for select
  using (true);

-- Authenticated users can insert
create policy "Authenticated users can insert"
  on public.recipes for insert
  with check (auth.role() = 'authenticated');

-- Authenticated users can update
create policy "Authenticated users can update"
  on public.recipes for update
  using (auth.role() = 'authenticated');

-- Authenticated users can delete
create policy "Authenticated users can delete"
  on public.recipes for delete
  using (auth.role() = 'authenticated');

-- ── Enable Realtime ────────────────────────────────────────
alter publication supabase_realtime add table public.recipes;
