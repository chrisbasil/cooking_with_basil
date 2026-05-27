-- ─────────────────────────────────────────────────────────────
-- Add an "Appetizers" category
-- ─────────────────────────────────────────────────────────────
-- Appetizers used to fold into "Sides" (the 'appetizer'/'starter' keywords
-- lived on the side row). This splits them into their own category, leading the
-- nav (sort_order 5, ahead of Mains) to match meal-course order.
--
-- Categories are data-driven: app/home.html loads this table at startup via
-- loadVocab(). No deploy is needed for the DB change, but the matching icon
-- asset (app/assets/categories/appetizer.svg) does ship with the frontend.

-- 1. New category row.
insert into public.categories (key, label, icon_path, match_keywords, sort_order) values
  ('appetizer', 'Appetizers', 'assets/categories/appetizer.svg',
   array['appetizer','appetizers','starter','starters','dip','dips','hors d''oeuvre','canape','canapé'], 5)
on conflict (key) do update set
  label         = excluded.label,
  icon_path     = excluded.icon_path,
  match_keywords = excluded.match_keywords,
  sort_order    = excluded.sort_order;

-- 2. Stop "Sides" from claiming appetizer/starter keywords.
update public.categories
set match_keywords = array['side','sides']
where key = 'side';

-- 3. Backfill the existing real appetizers out of Sides. 'Sourdough Starter'
--    is intentionally excluded: it only matched on the word "starter".
update public.recipes
set category_key = 'appetizer'
where category_key = 'side'
  and title in (
    'Hot Spinach-Artichoke Dip',
    'Smokey Sweetcorn and Tofu Fritters',
    'Vegetarian Steamed Dumplings',
    'Spanakopita'
  );
