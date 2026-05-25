-- 2026-05-15: Future-proof public schema for Supabase's Data API grants change.
--
-- Background: Supabase no longer auto-grants Data API access to new public
-- tables (enforced on new projects from 2026-05-30, all projects from
-- 2026-10-30). Existing tables keep their grants; this migration sets default
-- privileges so tables created after this runs are reachable from
-- supabase-js / PostgREST / GraphQL without a per-table grant.
--
-- RLS policies on each table remain the security boundary.

alter default privileges in schema public
  grant select on tables to anon;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public
  grant all on tables to service_role;
