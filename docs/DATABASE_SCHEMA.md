# Database Schema (Supabase / PostgreSQL)

> §5 of the OSS Club Website PRD
> Related docs: [PRD](./PRD.md) · [ARCHITECTURE](./architecture.md) · [GITHUB_INTEGRATION](./GITHUB_INTEGRATION.md)

---

## 5.1 Data ownership

| Data | Owner | Stored in Supabase? |
|---|---|---|
| Repos, issues, PRs, labels, assignees, reviews, stars/forks | **GitHub** | **Read-through cache only** (`gh_*`), rebuildable, disposable |
| Project editorial content (problem, objectives, status, maintainers, docs links) | Site | Yes (`projects`, keyed by `github_repo_id`) |
| Events, resources, announcements, team, achievements | Site | Yes |
| Interest requests, issue proposals | Site (workflow) | Yes |
| Assignment truth | GitHub | Mirrored from webhook; never written by us except via proposal-approved flows |
| Difficulty / area / type | **GitHub labels** (derived at sync) | Denormalised into `gh_issues` for filtering |

**Why cache at all:** GitHub search/rate limits can't power fast faceted filtering. Cache is the **only** duplication, explicitly justified.

---

## 5.2 Core DDL (abridged but runnable shape)

```sql
create type app_role as enum ('member','maintainer','admin','super_admin');
create type content_status as enum ('draft','published','archived');

-- ==================== PROFILES & ROLES ====================

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  github_id bigint unique not null,
  github_login text unique not null,
  display_name text, avatar_url text, bio text check (char_length(bio)<=280),
  is_org_member boolean not null default false,
  is_public boolean not null default false,        -- opt-in directory/recognition
  show_contributions boolean not null default false,
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create table user_roles (
  user_id uuid references profiles(id) on delete cascade,
  role app_role not null,
  granted_by uuid references profiles(id),
  granted_at timestamptz default now(),
  primary key (user_id, role)
);

-- ==================== PROJECTS ====================

create table projects (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug ~ '^[a-z0-9-]+$'),
  name text not null, tagline text, problem text, objectives text[],
  stack text[] default '{}',
  github_repo_id bigint unique,                     -- link to GitHub, source of repo facts
  status text not null check (status in ('idea','active','maintenance','archived')),
  docs_url text, status_content content_status not null default 'draft',
  featured boolean default false, sort_order int default 0,
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create table project_members (
  project_id uuid references projects on delete cascade,
  user_id uuid references profiles on delete cascade,
  role text not null check (role in ('lead','maintainer','contributor','mentor')),
  primary key (project_id, user_id)
);

-- ==================== EVENTS ====================

create table events (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null, title text not null, kind text not null
    check (kind in ('workshop','hackathon','session','drive','talk')),
  summary text, body_md text, starts_at timestamptz not null, ends_at timestamptz,
  venue text, online_url text, registration_url text, cover_path text,
  gallery_paths text[] default '{}', status content_status default 'draft',
  created_by uuid references profiles, created_at timestamptz default now(),
  check (ends_at is null or ends_at >= starts_at)
);
create index on events (status, starts_at desc);

-- ==================== LEARNING RESOURCES ====================

create table resource_tracks (
  id uuid primary key default gen_random_uuid(), slug text unique not null,
  title text not null, summary text, sort_order int default 0,
  status content_status default 'draft'
);

create table resources (
  id uuid primary key default gen_random_uuid(),
  track_id uuid references resource_tracks on delete set null,
  slug text unique not null, title text not null, body_md text, external_url text,
  level text check (level in ('beginner','intermediate','advanced')),
  est_minutes int check (est_minutes > 0), position int default 0,
  status content_status default 'draft', updated_at timestamptz default now()
);

-- ==================== ANNOUNCEMENTS & TEAM ====================

create table announcements (
  id uuid primary key default gen_random_uuid(), title text not null, body_md text,
  pinned boolean default false, publish_at timestamptz, expires_at timestamptz,
  status content_status default 'draft'
);

create table team_members (
  id uuid primary key default gen_random_uuid(), profile_id uuid references profiles,
  display_name text not null, title text, group_name text check (group_name in
  ('core','leadership','maintainer','mentor','alumni')), github_login text,
  public_links jsonb default '{}', sort_order int default 0, visible boolean default false
);

-- ==================== CONTRIBUTION WORKFLOW ====================

create table issue_proposals (
  id uuid primary key default gen_random_uuid(),
  proposer_id uuid not null references profiles,
  repo_full_name text not null, title text not null check (char_length(title) between 10 and 140),
  body_md text not null check (char_length(body_md) between 50 and 8000),
  proposed_labels text[] default '{}',
  status text not null default 'pending' check (status in
    ('pending','approved','rejected','duplicate','created','approval_failed')),
  reviewer_id uuid references profiles, review_note text,
  idempotency_key uuid default gen_random_uuid(),
  github_issue_number int, created_at timestamptz default now(), reviewed_at timestamptz
);
create index on issue_proposals (status, created_at);

create table contribution_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles,
  repo_id bigint not null, issue_number int not null,
  message text check (char_length(message)<=500),
  status text not null default 'requested' check (status in
    ('requested','approved','declined','withdrawn','assigned','pr_open','merged','abandoned')),
  decided_by uuid references profiles, created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create unique index one_active_request on contribution_requests (user_id, repo_id, issue_number)
  where status in ('requested','approved','assigned','pr_open');

-- ==================== RECOGNITION ====================

create table achievements (
  code text primary key, name text, description text, criteria jsonb
);

create table contributor_achievements (
  user_id uuid references profiles on delete cascade, code text references achievements,
  awarded_at timestamptz default now(), evidence jsonb,   -- e.g. {"pr":"org/repo#12"}
  primary key (user_id, code)
);

-- ==================== AUDIT ====================

create table audit_logs (
  id bigserial primary key, actor_id uuid references profiles, action text not null,
  entity text not null, entity_id text, diff jsonb, ip_hash text,
  created_at timestamptz default now()
);
create index on audit_logs (entity, entity_id, created_at desc);

-- ==================== GITHUB CACHE (rebuildable) ====================

create table gh_repos (
  repo_id bigint primary key, full_name text unique, name text, description text,
  html_url text, languages jsonb, topics text[], stars int, forks int, open_issues int,
  pushed_at timestamptz, archived boolean, synced_at timestamptz default now()
);

create table gh_issues (
  issue_id bigint primary key, repo_id bigint references gh_repos on delete cascade,
  number int, title text, body_preview text, state text, labels jsonb, assignees text[],
  difficulty text, areas text[], issue_type text, skills text[],      -- derived from labels
  author_login text, html_url text, created_at timestamptz, updated_at timestamptz,
  synced_at timestamptz default now(),
  unique (repo_id, number),
  search tsvector generated always as
    (to_tsvector('english', coalesce(title,'')||' '||coalesce(body_preview,''))) stored
);
create index on gh_issues using gin (search);
create index on gh_issues (state, difficulty);
create index on gh_issues using gin (areas);

create table gh_pulls (
  pr_id bigint primary key, repo_id bigint references gh_repos on delete cascade,
  number int, title text, state text, merged boolean, merged_at timestamptz, draft boolean,
  review_state text, author_login text, html_url text, closes_issues int[],
  updated_at timestamptz
);

create table sync_state (
  key text primary key, etag text, cursor text, last_ok_at timestamptz, last_error text
);

create table webhook_deliveries (
  delivery_id uuid primary key, event text, received_at timestamptz default now(),
  processed_at timestamptz
);

create table analytics_events (
  id bigserial primary key, name text not null, props jsonb,
  day date default current_date
);  -- no user ids, no IPs
```

**Additional requirements:**
- Add `updated_at` trigger on all mutable tables
- Create `has_role(role)` SQL function (`security definer`, `set search_path = ''`)

---

## 5.3 RLS (enable on **every** table; deny by default)

```sql
alter table profiles enable row level security;

create function public.has_role(r app_role) returns boolean
  language sql stable security definer set search_path = '' as
$$ select exists (
  select 1 from public.user_roles where user_id = auth.uid()
  and (role = r or role in ('admin','super_admin'))
) $$;

-- profiles: public only if opted in; owner full; admin all
create policy "public read opted-in" on profiles for select using (is_public);
create policy "owner read/write" on profiles for all
  using (id = auth.uid()) with check (id = auth.uid());
-- owner cannot change is_org_member/role-affecting columns: use column privileges or server action only.

-- content tables (projects/events/resources/announcements/team_members)
create policy "public read published" on events for select using (status = 'published');
create policy "admin write" on events for all
  using (public.has_role('admin')) with check (public.has_role('admin'));
-- repeat pattern per content table

-- maintainers may update projects they belong to:
create policy "maintainer edit own project" on projects for update using (
  exists (select 1 from project_members pm
    where pm.project_id = id and pm.user_id = auth.uid()
    and pm.role in ('lead','maintainer')));

-- proposals & requests: owner + staff
create policy "own proposals" on issue_proposals for select
  using (proposer_id = auth.uid() or public.has_role('maintainer'));
create policy "insert own proposal" on issue_proposals for insert
  with check (proposer_id = auth.uid() and status = 'pending');
create policy "staff review" on issue_proposals for update
  using (public.has_role('admin'));

create policy "own requests" on contribution_requests for select
  using (user_id = auth.uid() or public.has_role('maintainer'));
create policy "insert own request" on contribution_requests for insert
  with check (user_id = auth.uid() and status = 'requested');

-- audit_logs: admin select only; NO client insert (service role writes)
-- gh_* : public select; writes service-role only (no write policy = denied)
-- user_roles: select own; writes super_admin via server only
```

**Rule:** Every RLS policy needs a pgTAP/SQL test (`supabase/tests`) verifying anon, member, maintainer, admin outcomes. CI job `db-check` runs migrations + tests on a fresh DB.
