-- 2026-05-25: Tighten anon table grants (defense-in-depth).
--
-- Background: existing public tables carry Supabase's legacy default grants,
-- which give the `anon` role full DML (INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/
-- TRIGGER/SELECT) on every table. RLS policies block anon writes through the
-- Data API today, and PostgREST never exposes TRUNCATE, so this isn't
-- exploitable -- but anon should hold the minimum it needs. The app only ever
-- reads vocab tables anonymously; recipes/import_logs/recipe_tags are
-- authenticated-only and RLS already returns nothing to anon.
--
-- This revokes all anon write privileges everywhere, and revokes anon SELECT on
-- the non-vocab tables. `authenticated` and `service_role` grants are untouched.
-- RLS policies remain the real security boundary.

begin;

-- Remove every write privilege from anon across the public schema.
revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public from anon;

-- Anon never needs to read these (RLS already blocks the rows). Drop the grant
-- so the table isn't even reachable for SELECT by the anon role.
revoke select on public.recipes      from anon;
revoke select on public.import_logs  from anon;
revoke select on public.recipe_tags  from anon;

-- Anon keeps SELECT on the vocab tables only:
--   categories, cuisines, difficulties, proteins, tag_vocab
-- (granted by their original creation / taxonomy migration; left intact).

commit;
