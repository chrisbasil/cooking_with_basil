-- Cooking with Basil: Taxonomy + Protein migration
-- 2026-04-12
--
-- What this script does (run as one transaction in Supabase SQL Editor):
--   1. Creates vocab tables: categories, proteins, cuisines, difficulties, tag_vocab
--   2. Adds recipes.protein column (FK -> proteins.key)
--   3. Seeds the vocab tables
--   4. Applies RLS policies matching the existing recipes pattern
--   5. Norms + enriches every existing recipe row:
--        - canonicalizes cuisine (e.g. "Italian-American" -> "italian" + adds tag)
--        - lowercases difficulty
--        - lowercases + dedupes + trims tags
--        - infers protein from tags -> title -> ingredients -> category fallback
--
-- Safe to re-run.

begin;

-- ─────────────────────────────────────────────────────────────
-- 1. Vocab tables
-- ─────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────
-- 2. recipes.protein column
-- ─────────────────────────────────────────────────────────────
alter table public.recipes
  add column if not exists protein text;

create index if not exists idx_recipes_protein on public.recipes(protein);

-- ─────────────────────────────────────────────────────────────
-- 3. Seed vocab
-- ─────────────────────────────────────────────────────────────
insert into public.categories (key, label, icon_path, match_keywords, sort_order) values
  ('dinner',  'Mains',   'assets/categories/mains.svg',   array['dinner','main','mains','entree','entrée','lunch'], 10),
  ('side',    'Sides',   'assets/categories/side.svg',    array['side','sides','appetizer','starter'], 20),
  ('soup',    'Soups',   'assets/categories/soup.svg',    array['soup','soups','stew','chili'], 30),
  ('dessert', 'Sweets',  'assets/categories/dessert.svg', array['dessert','desserts','sweet','sweets'], 40),
  ('drink',   'Drinks',  'assets/categories/drink.svg',   array['drink','drinks','beverage','cocktail'], 50),
  ('baking',  'Baking',  'assets/categories/baking.svg',  array['baking','bread','breads','pastry','pastries','cake','cakes','cookie','cookies','muffin','muffins','scone','scones','pie','pies','dough'], 60),
  ('sauce',   'Pantry',  'assets/categories/pantry.svg',  array['sauce','sauces','basic','basics','pantry','condiment','dressing','marinade','breakfast','snack','spice','rub','stock','broth'], 70)
on conflict (key) do update set
  label = excluded.label,
  icon_path = excluded.icon_path,
  match_keywords = excluded.match_keywords,
  sort_order = excluded.sort_order;

insert into public.proteins (key, label, sort_order) values
  ('vegetarian', 'Vegetarian', 10),
  ('fish',       'Fish',       20),
  ('adaptable',  'Adaptable',  30),
  ('meat',       'Meat',       40)
on conflict (key) do update set
  label = excluded.label,
  sort_order = excluded.sort_order;

insert into public.difficulties (key, label, sort_order) values
  ('easy',   'Easy',   10),
  ('medium', 'Medium', 20),
  ('hard',   'Hard',   30)
on conflict (key) do update set
  label = excluded.label,
  sort_order = excluded.sort_order;

insert into public.cuisines (key, label) values
  ('american',  'American'),
  ('italian',   'Italian'),
  ('indian',    'Indian'),
  ('french',    'French'),
  ('thai',      'Thai'),
  ('mexican',   'Mexican'),
  ('greek',     'Greek'),
  ('moroccan',  'Moroccan'),
  ('japanese',  'Japanese'),
  ('chinese',   'Chinese'),
  ('spanish',   'Spanish'),
  ('korean',    'Korean'),
  ('vietnamese','Vietnamese'),
  ('middle-eastern','Middle Eastern'),
  ('mediterranean','Mediterranean'),
  ('asian',     'Asian')
on conflict (key) do update set label = excluded.label;

insert into public.tag_vocab (key, label, kind) values
  ('weeknight',        'Weeknight',         'occasion'),
  ('weekend',          'Weekend',           'occasion'),
  ('entertaining',     'Entertaining',      'occasion'),
  ('holiday',          'Holiday',           'occasion'),
  ('dinner-party',     'Dinner Party',      'occasion'),
  ('special-occasion', 'Special Occasion',  'occasion'),
  ('thanksgiving',     'Thanksgiving',      'occasion'),
  ('any',    'Any Season', 'season'),
  ('spring', 'Spring',     'season'),
  ('summer', 'Summer',     'season'),
  ('fall',   'Fall',       'season'),
  ('winter', 'Winter',     'season'),
  ('breakfast', 'Breakfast', 'meal_type'),
  ('lunch',     'Lunch',     'meal_type'),
  ('brunch',    'Brunch',    'meal_type'),
  ('snack',     'Snack',     'meal_type'),
  ('make-ahead',   'Make Ahead',    'style'),
  ('comfort-food', 'Comfort Food',  'style'),
  ('family-recipe','Family Recipe', 'style'),
  ('quick',        'Quick',         'style'),
  ('no-cook',      'No Cook',       'style'),
  ('no-knead',     'No Knead',      'style'),
  ('slow-cooker',  'Slow Cooker',   'style'),
  ('one-pot',      'One Pot',       'style'),
  ('grilling',     'Grilling',      'style'),
  ('large-batch',  'Large Batch',   'style'),
  ('pantry-staple','Pantry Staple', 'style'),
  ('gluten-free',  'Gluten Free',   'style'),
  ('gluten-free-adaptable','Gluten-Free Adaptable','style'),
  ('spicy',        'Spicy',         'style'),
  ('hearty',       'Hearty',        'style'),
  ('bbq',          'BBQ',           'style'),
  ('southern',     'Southern',      'style'),
  ('asian-fusion', 'Asian Fusion',  'style'),
  ('mexican-fusion','Mexican Fusion','style'),
  ('pasta',        'Pasta',         'other'),
  ('bread',        'Bread',         'other'),
  ('sauce',        'Sauce',         'other'),
  ('condiment',    'Condiment',     'other'),
  ('dip',          'Dip',           'other'),
  ('salad',        'Salad',         'other'),
  ('soup',         'Soup',          'other'),
  ('stew',         'Stew',          'other'),
  ('curry',        'Curry',         'other'),
  ('dumplings',    'Dumplings',     'other'),
  ('pie',          'Pie',           'other'),
  ('cookies',      'Cookies',       'other'),
  ('flatbread',    'Flatbread',     'other'),
  ('polenta',      'Polenta',       'other'),
  ('lentil',       'Lentil',        'other'),
  ('chickpea',     'Chickpea',      'other'),
  ('paneer',       'Paneer',        'other'),
  ('dal',          'Dal',           'other'),
  ('couscous',     'Couscous',      'other'),
  ('sweet-potato', 'Sweet Potato',  'other'),
  ('potato',       'Potato',        'other'),
  ('kale',         'Kale',          'other'),
  ('collard-greens','Collard Greens','other'),
  ('harissa',      'Harissa',       'other'),
  ('noodles',      'Noodles',       'other'),
  ('sourdough',    'Sourdough',     'other'),
  ('biscuits',     'Biscuits',      'other'),
  ('brownies',     'Brownies',      'other'),
  ('torte',        'Torte',         'other'),
  ('ice-cream',    'Ice Cream',     'other'),
  ('scallops',     'Scallops',      'other'),
  ('tuna',         'Tuna',          'other'),
  ('casserole',    'Casserole',     'other'),
  ('preserving',   'Preserving',    'other'),
  ('baked',        'Baked',         'other'),
  ('steamed',      'Steamed',       'other'),
  ('grilled',      'Grilled',       'other'),
  ('technique',    'Technique',     'other'),
  ('concept',      'Concept',       'other'),
  ('crust',        'Crust',         'other'),
  ('ottolenghi',   'Ottolenghi',    'other'),
  ('party',        'Party',         'other'),
  ('beverage',     'Beverage',      'other'),
  ('appetizer',    'Appetizer',     'other'),
  ('dinner',       'Dinner',        'other'),
  ('main',         'Main',          'other'),
  ('side',         'Side',          'other'),
  ('dessert',      'Dessert',       'other'),
  ('baking',       'Baking',        'other')
on conflict (key) do update set
  label = excluded.label,
  kind = excluded.kind;

-- ─────────────────────────────────────────────────────────────
-- 4. RLS on new tables (anon read, authenticated write)
-- ─────────────────────────────────────────────────────────────
alter table public.categories   enable row level security;
alter table public.proteins     enable row level security;
alter table public.cuisines     enable row level security;
alter table public.difficulties enable row level security;
alter table public.tag_vocab    enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['categories','proteins','cuisines','difficulties','tag_vocab'] loop
    execute format('drop policy if exists "Anyone can read %1$s" on public.%1$s', t);
    execute format('create policy "Anyone can read %1$s" on public.%1$s for select using (true)', t);

    execute format('drop policy if exists "Authenticated can insert %1$s" on public.%1$s', t);
    execute format('create policy "Authenticated can insert %1$s" on public.%1$s for insert with check (auth.role() = ''authenticated'')', t);

    execute format('drop policy if exists "Authenticated can update %1$s" on public.%1$s', t);
    execute format('create policy "Authenticated can update %1$s" on public.%1$s for update using (auth.role() = ''authenticated'')', t);

    execute format('drop policy if exists "Authenticated can delete %1$s" on public.%1$s', t);
    execute format('create policy "Authenticated can delete %1$s" on public.%1$s for delete using (auth.role() = ''authenticated'')', t);
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────────
-- 5. Norm + enrich existing recipes
-- ─────────────────────────────────────────────────────────────

-- 5a. Lowercase/trim/dedupe tags (preserves all original values)
update public.recipes
set tags = (
  select coalesce(array_agg(distinct lower(trim(t))) filter (where trim(t) <> ''), '{}')
  from unnest(coalesce(tags, '{}')) t
);

-- 5b. Preserve compound cuisine modifiers as tags before canonicalizing
update public.recipes set tags = array(select distinct x from unnest(tags || array['italian-american']) x) where cuisine ilike 'italian-american';
update public.recipes set tags = array(select distinct x from unnest(tags || array['tuscan']) x)           where cuisine ilike 'italian / tuscan';
update public.recipes set tags = array(select distinct x from unnest(tags || array['indian-inspired']) x) where cuisine ilike 'indian-inspired';
update public.recipes set tags = array(select distinct x from unnest(tags || array['french-american']) x) where cuisine ilike 'french-american' or cuisine ilike 'american/french';
update public.recipes set tags = array(select distinct x from unnest(tags || array['french-inspired']) x) where cuisine ilike 'french-inspired';
update public.recipes set tags = array(select distinct x from unnest(tags || array['bbq','grilling']) x)  where cuisine ilike 'american / bbq';
update public.recipes set tags = array(select distinct x from unnest(tags || array['southern']) x)        where cuisine ilike 'american / southern';
update public.recipes set tags = array(select distinct x from unnest(tags || array['artisan']) x)         where cuisine ilike 'american / artisan';
update public.recipes set tags = array(select distinct x from unnest(tags || array['beverage']) x)        where cuisine ilike 'beverage%';
update public.recipes set tags = array(select distinct x from unnest(tags || array['holiday']) x)         where cuisine ilike '%holiday%';

-- 5c. Canonicalize cuisine
update public.recipes
set cuisine = case
  when cuisine is null or trim(cuisine) = '' then null
  when cuisine ilike 'italian%' then 'italian'
  when cuisine ilike 'indian%'  then 'indian'
  when cuisine ilike 'american/french' then 'american'
  when cuisine ilike 'french%' then 'french'
  when cuisine ilike 'american%' then 'american'
  when cuisine ilike 'greek%'    then 'greek'
  when cuisine ilike 'thai%'     then 'thai'
  when cuisine ilike 'mexican%'  then 'mexican'
  when cuisine ilike 'moroccan%' then 'moroccan'
  when cuisine ilike 'japanese%' then 'japanese'
  when cuisine ilike 'beverage%' then null
  else lower(trim(cuisine))
end;

-- 5c-ii. Fill empty cuisines from obvious title signals
update public.recipes
set cuisine = case
  when title ilike '%khao soi%'   then 'thai'
  when title ilike '%bolognese%'  then 'italian'
  when title ilike '%focaccia%'   then 'italian'
  when title ilike '%spanakopita%' then 'greek'
  when title ilike '%stir fry%' or title ilike '%miso%' then 'asian'
  when title ilike '%pumpkin bread%' or title ilike '%angel biscuit%'
       or title ilike '%chocolate chip cookie%' or title ilike '%brownies%'
       or title ilike '%mashed potato%' or title ilike '%mac and cheese%'
       or title ilike '%key lime%'     or title ilike '%barbeque%'
       or title ilike '%wassail%'      or title ilike '%fruit punch%'
       then 'american'
  else cuisine
end
where cuisine is null;

-- 5d. Canonicalize difficulty
update public.recipes
set difficulty = case
  when difficulty is null or trim(difficulty) = '' then null
  else lower(trim(difficulty))
end;

-- 5e. Infer protein (priority: tags -> title -> ingredients -> category fallback)
update public.recipes set protein = 'adaptable'
where protein is null
  and (tags && array['vegan-adaptable','vegetarian-adaptable','gluten-free-adaptable']);

update public.recipes set protein = 'vegetarian'
where protein is null
  and (tags && array['vegetarian','vegan']);

update public.recipes set protein = 'fish'
where protein is null
  and (tags && array['seafood','fish','tuna','salmon','scallops','shrimp']);

update public.recipes set protein = 'meat'
where protein is null
  and (tags && array['beef','chicken','pork','duck','lamb','bacon','meat','turkey','veal']);

update public.recipes set protein = 'fish'
where protein is null
  and title ~* '(fish|salmon|tuna|cod|halibut|shrimp|scallop|anchov|crab|lobster|sardine|mackerel|seafood|oyster|clam|mussel)';

update public.recipes set protein = 'meat'
where protein is null
  and title ~* '(chicken|beef|pork|lamb|duck|bacon|prosciutto|sausage|ham|turkey|veal|\mrib\M|brisket|steak|burger|hamburger|bolognese|meatball)';

update public.recipes set protein = 'fish'
where protein is null
  and coalesce(ingredients, '') ~* '(salmon|tuna|cod|halibut|shrimp|scallop|anchov|crab|lobster|sardine|mackerel|oyster|clam|mussel)';

update public.recipes set protein = 'meat'
where protein is null
  and coalesce(ingredients, '') ~* '(chicken|ground beef|ground pork|pork shoulder|pork belly|bacon|prosciutto|pancetta|sausage|ham hock|brisket|steak|lamb|duck breast|hamburger meat)';

-- Category fallback: dessert/baking/sauce/drink default to vegetarian
update public.recipes set protein = 'vegetarian'
where protein is null
  and (
    tags && array['dessert','baking','bread','sauce','condiment','beverage',
                  'cookies','brownies','pie','torte','ice-cream','flatbread',
                  'preserving','sourdough']
    or title ~* '(bread|biscuit|cookie|brownie|torte|pie|cake|wassail|punch|aioli|sauce|starter|hummus)'
  );

commit;

-- ─────────────────────────────────────────────────────────────
-- Post-migration QA (run as separate queries to review results)
-- ─────────────────────────────────────────────────────────────
-- select protein, count(*) from public.recipes group by protein order by 2 desc;
-- select cuisine, count(*) from public.recipes group by cuisine order by 2 desc;
-- select difficulty, count(*) from public.recipes group by difficulty order by 2 desc;
-- select id, title, tags from public.recipes where protein is null;  -- rows needing manual review
