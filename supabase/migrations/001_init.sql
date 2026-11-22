-- Mâm (mam) — Initial Supabase PostgreSQL Schema
-- Personal single-player bill-sharing app with iOS <-> Android sync
-- Requires PostgreSQL 13+ (gen_random_uuid() built-in) and Supabase Auth (auth.uid())

-- ============================================================================
-- 1. Trigger helper: enforce server-side monotonic updated_at for delta sync
-- ============================================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================================
-- 2. bank_accounts — Saved VietQR receiving bank accounts
-- ============================================================================
create table if not exists public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  bank_bin varchar(6) not null check (bank_bin ~ '^[0-9]{6}$'),
  bank_short_name text not null check (length(trim(bank_short_name)) > 0),
  account_no text not null check (length(trim(account_no)) > 0),
  account_name text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_bank_accounts_user_updated
  on public.bank_accounts (user_id, updated_at desc);

-- Ensure at most one active default bank account per user
create unique index if not exists uq_bank_accounts_one_default_per_user
  on public.bank_accounts (user_id)
  where is_default = true and deleted_at is null;

drop trigger if exists trg_bank_accounts_updated_at on public.bank_accounts;
create trigger trg_bank_accounts_updated_at
  before insert or update on public.bank_accounts
  for each row execute function public.set_updated_at();

-- ============================================================================
-- 3. friend_groups — Reusable dining groups (e.g. "Team Công ty")
-- ============================================================================
create table if not exists public.friend_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  name text not null check (length(trim(name)) > 0),
  -- JSONB array of GroupMember: [{ "id": "m_1", "name": "Minh", "isHost": false }]
  members jsonb not null default '[]'::jsonb
    check (jsonb_typeof(members) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_friend_groups_user_updated
  on public.friend_groups (user_id, updated_at desc);

drop trigger if exists trg_friend_groups_updated_at on public.friend_groups;
create trigger trg_friend_groups_updated_at
  before insert or update on public.friend_groups
  for each row execute function public.set_updated_at();

-- ============================================================================
-- 4. user_settings — Synced personal defaults
-- ============================================================================
create table if not exists public.user_settings (
  user_id uuid primary key default auth.uid(),
  default_rounding text not null default 'nearest_1000'
    check (default_rounding in ('none', 'nearest_1000', 'ceil_1000')),
  default_transfer_template text not null default '{name} tra tien {title}',
  default_shipping_mode text not null default 'flat'
    check (default_shipping_mode in ('flat', 'pro_rata')),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_user_settings_updated_at on public.user_settings;
create trigger trg_user_settings_updated_at
  before insert or update on public.user_settings
  for each row execute function public.set_updated_at();

-- ============================================================================
-- 5. bills — Split bills stored atomically with JSONB payload for clean sync
-- ============================================================================
create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  title text not null check (length(trim(title)) > 0),
  bill_date date not null default current_date,
  mode text not null default 'itemized'
    check (mode in ('itemized', 'quick_equal')),
  total_amount bigint not null default 0 check (total_amount >= 0),
  payment_status text not null default 'pending'
    check (payment_status in ('pending', 'settled')),
  schema_version int not null default 1 check (schema_version >= 1),
  -- JSONB BillPayload: { participants, items, adjustments, roundingMode, bankAccountSnapshot, transferNoteTemplate, note }
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_bills_user_updated
  on public.bills (user_id, updated_at desc);

create index if not exists idx_bills_user_status_date
  on public.bills (user_id, payment_status, bill_date desc)
  where deleted_at is null;

drop trigger if exists trg_bills_updated_at on public.bills;
create trigger trg_bills_updated_at
  before insert or update on public.bills
  for each row execute function public.set_updated_at();

-- ============================================================================
-- 6. Row Level Security (RLS) — Strictly owner-only access
-- ============================================================================
alter table public.bank_accounts enable row level security;
alter table public.friend_groups enable row level security;
alter table public.user_settings enable row level security;
alter table public.bills enable row level security;

drop policy if exists "owner_bank_accounts" on public.bank_accounts;
create policy "owner_bank_accounts" on public.bank_accounts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "owner_friend_groups" on public.friend_groups;
create policy "owner_friend_groups" on public.friend_groups
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "owner_user_settings" on public.user_settings;
create policy "owner_user_settings" on public.user_settings
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "owner_bills" on public.bills;
create policy "owner_bills" on public.bills
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
