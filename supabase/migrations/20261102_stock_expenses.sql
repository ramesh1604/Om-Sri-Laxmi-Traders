-- Existing stock metadata, customer billing details and monthly store expenses.
alter table public.customers add column if not exists gstin text;
alter table public.customers add column if not exists address text;
alter table public.products add column if not exists article_number text;
alter table public.products add column if not exists colour text;
alter table public.products add column if not exists size text;
alter table public.products add column if not exists gst_amount numeric(14,2) not null default 0;

create or replace function public.set_product_gst_amount()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  -- Per-unit input GST: Rate less the 5% discount, then 5% GST.
  new.gst_amount := round(coalesce(new.purchase_rate,0) * 0.95 * 0.05, 2);
  return new;
end;
$$;
drop trigger if exists products_set_gst_amount on public.products;
create trigger products_set_gst_amount
before insert or update of purchase_rate on public.products
for each row execute function public.set_product_gst_amount();
update public.products set gst_amount=round(purchase_rate * 0.95 * 0.05, 2)
where gst_amount=0 and purchase_rate>0;


create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  expense_date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  created_at timestamptz not null default now()
);

alter table public.expenses enable row level security;
drop policy if exists expenses_owner on public.expenses;
create policy expenses_owner on public.expenses for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
grant select, insert, update, delete on table public.expenses to authenticated;

notify pgrst, 'reload schema';
