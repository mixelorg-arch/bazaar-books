-- Bazaar Books — database schema
-- Lives in the existing "ledger" Supabase project, but every table is prefixed
-- bazaar_ and shares nothing with the print shop till (printshop_*) or the
-- sales ledger (entries / expenses / employees). The bazaar's takings, days,
-- expenses and people are entirely its own.
--
-- Run in Supabase → SQL Editor → New query. Safe to re-run.

-- ---------------------------------------------------------------- data

-- One row per completed sale. Line items ride along as jsonb: a sale is never
-- edited after the fact, only voided, so splitting them out buys nothing.
create table if not exists public.bazaar_sales (
  id         text primary key,
  sold_at    timestamptz not null,
  items      jsonb   not null default '[]'::jsonb,  -- [{name,cat,price,qty}]
  total      numeric not null default 0,
  cash       numeric not null default 0,
  change_due numeric not null default 0,
  voided     boolean not null default false,
  device     text    not null default '',
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

-- The price list: 3D prints, stickers, booth prints, bundles.
create table if not exists public.bazaar_services (
  id         text primary key,
  name       text    not null,
  cat        text    not null default 'Others',
  price      numeric not null default 0,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

-- One row per trading day. sales_source says whether the figure came from the
-- till or was typed over by hand.
create table if not exists public.bazaar_days (
  id           text primary key,
  date         date not null,
  team_sales   numeric not null default 0,
  pay          jsonb   not null default '{}'::jsonb,   -- {personId: amount}
  incentive    numeric not null default 0,
  paid         boolean not null default false,
  remarks      text    not null default '',
  sales_source text    not null default 'manual',
  deleted      boolean not null default false,
  updated_at   timestamptz not null default now()
);

create table if not exists public.bazaar_expenses (
  id         text primary key,
  month      text    not null,                        -- 'YYYY-MM'
  name       text    not null,
  amount     numeric not null default 0,
  paid       boolean not null default false,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.bazaar_people (
  id         text primary key,
  name       text    not null,
  archived   boolean not null default false,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists bazaar_sales_sold_idx       on public.bazaar_sales (sold_at);
create index if not exists bazaar_sales_updated_idx    on public.bazaar_sales (updated_at);
create index if not exists bazaar_services_updated_idx on public.bazaar_services (updated_at);
create index if not exists bazaar_days_date_idx        on public.bazaar_days (date);
create index if not exists bazaar_days_updated_idx     on public.bazaar_days (updated_at);
create index if not exists bazaar_expenses_month_idx   on public.bazaar_expenses (month);
create index if not exists bazaar_expenses_updated_idx on public.bazaar_expenses (updated_at);
create index if not exists bazaar_people_updated_idx   on public.bazaar_people (updated_at);

-- updated_at is stamped by the database, never trusted from the client — that
-- is what makes last-write-wins reliable across devices with wrong clocks.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['bazaar_sales','bazaar_services','bazaar_days',
                           'bazaar_expenses','bazaar_people'] loop
    execute format('drop trigger if exists touch_%1$s on public.%1$I', t);
    execute format(
      'create trigger touch_%1$s before insert or update on public.%1$I
         for each row execute function public.touch_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- security
--
-- Same gate as everything else in this project: an approved member only.
-- public.is_member() is defined by the ledger schema and reused here.

do $$
declare t text;
begin
  foreach t in array array['bazaar_sales','bazaar_services','bazaar_days',
                           'bazaar_expenses','bazaar_people'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists members_all on public.%I', t);
    execute format(
      'create policy members_all on public.%I for all
         using (public.is_member()) with check (public.is_member())', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- reporting
--
-- The daily takings, straight from SQL. Voided and deleted sales are excluded.
-- security_invoker makes the view obey the caller's RLS rather than the view
-- owner's, so it cannot leak past the members check above.
create or replace view public.bazaar_daily_totals
with (security_invoker = true) as
select
  (sold_at at time zone 'Asia/Manila')::date as day,
  count(*)                                   as transactions,
  sum(total)                                 as sales,
  sum((select coalesce(sum((i->>'qty')::numeric),0)
       from jsonb_array_elements(items) i))  as items_sold
from public.bazaar_sales
where not voided and not deleted
group by 1
order by 1 desc;
