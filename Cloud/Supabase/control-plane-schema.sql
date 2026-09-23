-- KRALİ Control Plane foundation schema
-- Run in KRALI-Control first; KRALI-Lab may reuse the same base schema.
-- No credentials belong in this repository.

create extension if not exists pgcrypto;
create extension if not exists vector;

create table if not exists public.learning_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  capability_id text not null,
  failure_fingerprint text not null,
  state text not null check (state in ('queued','running','waiting_approval','ready_for_review','completed','failed','cancelled')),
  priority integer not null default 0,
  payload jsonb not null default '{}'::jsonb,
  source_app_version text,
  attempts integer not null default 0,
  lease_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists learning_jobs_active_fingerprint_idx
  on public.learning_jobs(owner_id, failure_fingerprint)
  where state in ('queued','running','waiting_approval','ready_for_review');

create index if not exists learning_jobs_queue_idx
  on public.learning_jobs(owner_id, state, priority desc, created_at asc);

create table if not exists public.developer_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  learning_job_id uuid references public.learning_jobs(id) on delete set null,
  run_id text not null,
  provider text not null,
  model text,
  state text not null,
  branch text,
  candidate_commit text,
  source_targets jsonb not null default '[]'::jsonb,
  summary jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  unique(owner_id, run_id)
);

create index if not exists developer_runs_job_idx
  on public.developer_runs(owner_id, learning_job_id, started_at desc);

create table if not exists public.training_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  suite text not null check (suite in ('training','arena','live_eval')),
  app_version text not null,
  run_id text,
  passed integer not null default 0,
  total integer not null default 0,
  core_passed integer,
  core_total integer,
  north_star_passed integer,
  north_star_total integer,
  status text not null default 'completed',
  raw_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists training_runs_version_idx
  on public.training_runs(owner_id, suite, app_version, created_at desc);

create table if not exists public.scenario_results (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  training_run_id uuid not null references public.training_runs(id) on delete cascade,
  scenario_id text not null,
  tier text not null,
  passed boolean not null,
  diagnostics jsonb not null default '[]'::jsonb,
  selected_capabilities jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(training_run_id, scenario_id)
);

create index if not exists scenario_results_failure_idx
  on public.scenario_results(owner_id, passed, scenario_id);

create table if not exists public.capability_failures (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  capability_id text not null,
  fingerprint text not null,
  app_version text,
  verification_state text,
  evidence jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  occurrence_count integer not null default 1,
  resolved_at timestamptz,
  unique(owner_id, fingerprint)
);

create table if not exists public.skills (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  skill_key text not null,
  title text not null,
  description text not null default '',
  status text not null check (status in ('experimental','promoted','deprecated','rolled_back')),
  current_version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, skill_key)
);

create table if not exists public.skill_versions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  version integer not null,
  strategy jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  test_result jsonb not null default '{}'::jsonb,
  rollback_info jsonb not null default '{}'::jsonb,
  embedding vector,
  created_at timestamptz not null default now(),
  unique(skill_id, version)
);

create table if not exists public.agent_events (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source text not null,
  event_type text not null,
  entity_id text,
  app_version text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists agent_events_recent_idx
  on public.agent_events(owner_id, created_at desc);

-- RLS: a desktop client sees only the authenticated owner's rows.
alter table public.learning_jobs enable row level security;
alter table public.developer_runs enable row level security;
alter table public.training_runs enable row level security;
alter table public.scenario_results enable row level security;
alter table public.capability_failures enable row level security;
alter table public.skills enable row level security;
alter table public.skill_versions enable row level security;
alter table public.agent_events enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'learning_jobs',
    'developer_runs',
    'training_runs',
    'scenario_results',
    'capability_failures',
    'skills',
    'skill_versions',
    'agent_events'
  ]
  loop
    execute format('drop policy if exists owner_all on public.%I', t);
    execute format(
      'create policy owner_all on public.%I for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id)',
      t
    );
  end loop;
end $$;

-- updated_at helper for mutable records.
create or replace function public.krali_touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists learning_jobs_touch_updated_at on public.learning_jobs;
create trigger learning_jobs_touch_updated_at
before update on public.learning_jobs
for each row execute function public.krali_touch_updated_at();

drop trigger if exists skills_touch_updated_at on public.skills;
create trigger skills_touch_updated_at
before update on public.skills
for each row execute function public.krali_touch_updated_at();
