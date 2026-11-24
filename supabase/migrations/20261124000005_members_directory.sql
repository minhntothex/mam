-- ============================================================================
-- Mâm — Persistent Members Directory (Danh bạ thành viên cố định)
-- Syncs across iOS / Android / Web with owner-only RLS and soft-delete LWW.
-- ============================================================================

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_members_user_updated
  on public.members (user_id, updated_at desc);

drop trigger if exists trg_members_updated_at on public.members;
create trigger trg_members_updated_at
  before insert or update on public.members
  for each row execute function public.set_updated_at();

alter table public.members enable row level security;

drop policy if exists "owner_members" on public.members;
create policy "owner_members" on public.members
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on table public.members to authenticated;
revoke all on table public.members from anon;
