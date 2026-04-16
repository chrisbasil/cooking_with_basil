-- Cooking with Basil: Recipes → Relational Migration
-- 2026-04-13
--
-- Converts recipes' loose text taxonomy into real FKs against the vocab tables
-- seeded by 2026-04-12-taxonomy-and-protein.sql:
--   cuisine    text  -> cuisine_key    -> cuisines(key)
--   difficulty text  -> difficulty_key -> difficulties(key)
--   protein    text  -> protein_key    -> proteins(key)
--   (new)            -> category_key   -> categories(key)
--   tags text[]      -> recipe_tags(recipe_id, tag_key -> tag_vocab(key))
--
-- Run order (do NOT run all at once):
--   STEP 0 — Pre-flight QA (read-only). Inspect unmatched values, extend the
--            normalization CASE in STEP 2 if needed.
--   STEP 1+2 — Add columns, junction table, RLS, and backfill.
--   STEP 3 — After eyeballing the backfill, drop the old text columns.
--
-- ─────────────────────────────────────────────────────────────
-- STEP 0 — Pre-flight QA (run these by hand first; comment-only)
-- ─────────────────────────────────────────────────────────────
-- select distinct cuisine    from public.recipes where cuisine    is not null and cuisine    not in (select key from public.cuisines);
-- select distinct difficulty from public.recipes where difficulty is not null and difficulty not in (select key from public.difficulties);
-- select distinct protein    from public.recipes where protein    is not null and protein    not in (select key from public.proteins);
-- select distinct t          from public.recipes, unnest(tags) t  where t not in (select key from public.tag_vocab);

-- ═════════════════════════════════════════════════════════════
-- STEP 1 + 2 — Schema additions + backfill
-- ═════════════════════════════════════════════════════════════
begin;

-- 1a. New FK columns on recipes
alter table public.recipes
  add column if not exists cuisine_key    text references public.cuisines(key)     on delete set null,
  add column if not exists difficulty_key text references public.difficulties(key) on delete set null,
  add column if not exists protein_key    text references public.proteins(key)     on delete set null,
  add column if not exists category_key   text references public.categories(key)   on delete set null;

-- 1b. Tags junction table
create table if not exists public.recipe_tags (
  recipe_id uuid not null references public.recipes(id)   on delete cascade,
  tag_key   text not null references public.tag_vocab(key) on delete cascade,
  primary key (recipe_id, tag_key)
);
create index if not exists idx_recipe_tags_tag_key on public.recipe_tags(tag_key);

-- 1c. RLS on recipe_tags (matches recipes pattern)
alter table public.recipe_tags enable row level security;

drop policy if exists "Authenticated can read recipe_tags"   on public.recipe_tags;
drop policy if exists "Authenticated can insert recipe_tags" on public.recipe_tags;
drop policy if exists "Authenticated can update recipe_tags" on public.recipe_tags;
drop policy if exists "Authenticated can delete recipe_tags" on public.recipe_tags;

create policy "Authenticated can read recipe_tags"
  on public.recipe_tags for select using (auth.role() = 'authenticated');
create policy "Authenticated can insert recipe_tags"
  on public.recipe_tags for insert with check (auth.role() = 'authenticated');
create policy "Authenticated can update recipe_tags"
  on public.recipe_tags for update using (auth.role() = 'authenticated');
create policy "Authenticated can delete recipe_tags"
  on public.recipe_tags for delete using (auth.role() = 'authenticated');

-- Realtime
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'recipe_tags'
  ) then
    alter publication supabase_realtime add table public.recipe_tags;
  end if;
end $$;

-- 2a. Backfill cuisine_key
--     Direct match where possible; high-confidence collapses for known stragglers.
--     Anything else → NULL (review with Step 0 query and extend this CASE if needed).
update public.recipes set cuisine_key = case
  when cuisine is null or trim(cuisine) = ''                  then null
  when lower(trim(cuisine)) in (select key from public.cuisines) then lower(trim(cuisine))
  when cuisine ilike 'tuscan'                                  then 'italian'
  when cuisine ilike 'sicilian'                                then 'italian'
  when cuisine ilike 'tex-mex' or cuisine ilike 'tex mex'      then 'mexican'
  when cuisine ilike 'cajun' or cuisine ilike 'creole'         then 'american'
  when cuisine ilike 'southern'                                then 'american'
  else null
end;

-- 2b. Backfill difficulty_key (already lowercased by the 2026-04-12 migration)
update public.recipes
set difficulty_key = lower(trim(difficulty))
where difficulty is not null
  and lower(trim(difficulty)) in (select key from public.difficulties);

-- 2c. Backfill protein_key
update public.recipes
set protein_key = protein
where protein in (select key from public.proteins);

-- 2d. Backfill category_key from categories.match_keywords ∩ (tags ∪ title)
--     First match by sort_order wins, so e.g. 'dinner' (sort 10) beats 'baking' (sort 60).
update public.recipes r
set category_key = (
  select c.key
  from public.categories c
  where exists (
    select 1
    from unnest(c.match_keywords) kw
    where kw = any(coalesce(r.tags, '{}'))
       or r.title ilike '%' || kw || '%'
  )
  order by c.sort_order asc
  limit 1
);

-- 2e. Build recipe_tags from the existing tags text[].
--     Only tags present in tag_vocab are kept (free-form values are dropped).
--     Run STEP 0's tag query first if you want to add unknowns to tag_vocab beforehand.
insert into public.recipe_tags (recipe_id, tag_key)
select r.id, t
from public.recipes r, unnest(coalesce(r.tags, '{}')) t
where t in (select key from public.tag_vocab)
on conflict do nothing;

commit;

-- ─────────────────────────────────────────────────────────────
-- Post-backfill QA — review BEFORE running STEP 3
-- ─────────────────────────────────────────────────────────────
-- select cuisine_key,    count(*) from public.recipes group by 1 order by 2 desc;
-- select category_key,   count(*) from public.recipes group by 1 order by 2 desc;
-- select difficulty_key, count(*) from public.recipes group by 1 order by 2 desc;
-- select protein_key,    count(*) from public.recipes group by 1 order by 2 desc;
-- select count(*) as kept_tags from public.recipe_tags;
-- select count(*) as total_tags from (select unnest(tags) from public.recipes) x;
-- select id, title, tags from public.recipes where category_key is null;
-- select id, title, cuisine from public.recipes where cuisine is not null and cuisine_key is null;

-- ═════════════════════════════════════════════════════════════
-- STEP 3 — Drop old columns + indexes (run only after QA passes)
-- ═════════════════════════════════════════════════════════════
-- begin;
--
-- drop index if exists public.idx_recipes_cuisine;
-- drop index if exists public.idx_recipes_protein;
-- drop index if exists public.idx_recipes_tags;
--
-- alter table public.recipes
--   drop column cuisine,
--   drop column difficulty,
--   drop column protein,
--   drop column tags;
--
-- create index if not exists idx_recipes_cuisine_key    on public.recipes(cuisine_key);
-- create index if not exists idx_recipes_difficulty_key on public.recipes(difficulty_key);
-- create index if not exists idx_recipes_protein_key    on public.recipes(protein_key);
-- create index if not exists idx_recipes_category_key   on public.recipes(category_key);
--
-- commit;
