-- House construction project records and reviewed report imports.
create table if not exists public.house_construction_settings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique default auth.uid() references auth.users(id) on delete cascade,
  budget numeric(14,2) not null default 0 check (budget >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.house_construction_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  entry_date date not null,
  category text not null check (category in ('Civil','Carpentry','Electrical','Plumbing & Sanitary','Legal & Service','Doors & Windows','Professional & Consultancy','Bank charges','Painting','Rituals & Formalities','Transport','Miscellaneous')),
  description text not null check (length(trim(description)) > 0),
  entry_type text not null check (entry_type in ('Material','Service')),
  amount numeric(14,2) not null check (amount > 0),
  created_at timestamptz not null default now()
);
create index if not exists house_construction_entries_owner_date_idx on public.house_construction_entries(owner_id,entry_date desc);

alter table public.house_construction_settings enable row level security;
alter table public.house_construction_entries enable row level security;
drop policy if exists house_construction_settings_owner on public.house_construction_settings;
create policy house_construction_settings_owner on public.house_construction_settings for all to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
drop policy if exists house_construction_entries_owner on public.house_construction_entries;
create policy house_construction_entries_owner on public.house_construction_entries for all to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
grant select,insert,update,delete on public.house_construction_settings,public.house_construction_entries to authenticated;

create or replace function public.import_house_construction_report(p_budget numeric, p_entries jsonb)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare row_data jsonb; inserted_count integer := 0; owner uuid := auth.uid();
begin
  if owner is null then raise exception 'Sign in before importing construction records.'; end if;
  if p_budget is null or p_budget < 0 then raise exception 'Enter a valid construction budget.'; end if;
  if jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries)=0 then raise exception 'The report has no construction entries to import.'; end if;
  insert into public.house_construction_settings(owner_id,budget,updated_at)
  values(owner,p_budget,now()) on conflict(owner_id) do update set budget=excluded.budget,updated_at=now();
  for row_data in select value from jsonb_array_elements(p_entries) loop
    insert into public.house_construction_entries(owner_id,entry_date,category,description,entry_type,amount)
    values(owner,(row_data->>'entry_date')::date,row_data->>'category',trim(row_data->>'description'),row_data->>'entry_type',(row_data->>'amount')::numeric);
    inserted_count := inserted_count + 1;
  end loop;
  return inserted_count;
end;
$$;
revoke all on function public.import_house_construction_report(numeric,jsonb) from public;
grant execute on function public.import_house_construction_report(numeric,jsonb) to authenticated;
notify pgrst, 'reload schema';
