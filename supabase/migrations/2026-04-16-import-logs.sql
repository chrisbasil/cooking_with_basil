-- Cooking with Basil: Import Logs
-- 2026-04-16
--
-- Audit trail for recipe imports. Every parse-recipe call (success or
-- failure) should write one row so that when an import looks wrong we can
-- look up the raw input and the parser output.

begin;

create table if not exists public.import_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  kind text not null,                         -- 'url' | 'text' | 'pdf-text' | 'pdf-image' | 'manual'
  source text,                                -- URL, filename, or null
  parse_method text,                          -- 'json-ld' | 'claude-text' | 'claude-vision' | 'failed'
  input_preview text,                         -- first ~2KB of input for debugging
  output jsonb,                               -- recipe object returned by parser
  warnings jsonb,                             -- warnings[] from parser
  usage jsonb,                                -- token counts when Claude was used
  recipe_id uuid references public.recipes(id) on delete set null,
  error text
);

create index if not exists idx_import_logs_created_by on public.import_logs(created_by);
create index if not exists idx_import_logs_created_at on public.import_logs(created_at desc);
create index if not exists idx_import_logs_recipe_id  on public.import_logs(recipe_id);

alter table public.import_logs enable row level security;

drop policy if exists "users see their own import logs" on public.import_logs;
drop policy if exists "users insert their own import logs" on public.import_logs;
drop policy if exists "users update their own import logs" on public.import_logs;

create policy "users see their own import logs"
  on public.import_logs for select
  using (created_by = auth.uid());

create policy "users insert their own import logs"
  on public.import_logs for insert
  with check (created_by = auth.uid());

-- Allow users to patch their own log rows (e.g. to attach recipe_id after save).
create policy "users update their own import logs"
  on public.import_logs for update
  using (created_by = auth.uid());

commit;
