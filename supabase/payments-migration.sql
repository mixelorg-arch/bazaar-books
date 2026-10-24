-- Bazaar Books — mode of payment
-- Adds how each sale was paid, and an editable list of payment methods.
-- Run in Supabase → SQL Editor → New query. Safe to re-run.

-- Existing sales predate this column and were all cash.
alter table public.bazaar_sales
  add column if not exists payment text not null default 'Cash';

create index if not exists bazaar_sales_payment_idx on public.bazaar_sales (payment);

-- The methods themselves, so every device offers the same list.
create table if not exists public.bazaar_methods (
  id         text primary key,
  name       text    not null,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);
create index if not exists bazaar_methods_updated_idx on public.bazaar_methods (updated_at);

drop trigger if exists touch_bazaar_methods on public.bazaar_methods;
create trigger touch_bazaar_methods before insert or update on public.bazaar_methods
  for each row execute function public.touch_updated_at();

alter table public.bazaar_methods enable row level security;
drop policy if exists members_all on public.bazaar_methods;
create policy members_all on public.bazaar_methods for all
  using (public.is_member()) with check (public.is_member());

-- Takings split by how they were paid — what you reconcile the e-wallets
-- and bank transfers against at the end of the day.
create or replace view public.bazaar_payment_totals
with (security_invoker = true) as
select
  (sold_at at time zone 'Asia/Manila')::date as day,
  payment,
  count(*)   as transactions,
  sum(total) as sales
from public.bazaar_sales
where not voided and not deleted
group by 1,2
order by 1 desc, 4 desc;
