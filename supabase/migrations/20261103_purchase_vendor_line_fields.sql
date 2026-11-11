-- Persist the two per-rate calculations shown on each purchase invoice line.
alter table public.transaction_items
  add column if not exists purchase_discount_amount numeric(14,2) not null default 0,
  add column if not exists purchase_igst_amount numeric(14,2) not null default 0;

create or replace function public.set_purchase_line_rate_taxes()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_type text;
begin
  select type into v_type from public.transactions where id=new.transaction_id and owner_id=new.owner_id;
  if v_type='purchase' then
    new.purchase_discount_amount:=round(coalesce(new.unit_price,0)*0.05,2);
    new.purchase_igst_amount:=round((coalesce(new.unit_price,0)-new.purchase_discount_amount)*0.05,2);
  end if;
  return new;
end $$;
drop trigger if exists transaction_items_purchase_rate_taxes on public.transaction_items;
create trigger transaction_items_purchase_rate_taxes
before insert or update of transaction_id,unit_price on public.transaction_items
for each row execute function public.set_purchase_line_rate_taxes();

create or replace function public.validate_purchase_vendor()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if new.type='purchase' and coalesce(new.vendor_name,'') not in ('WALKMATE EXPORTS PVT LTD','FOOTTECH POLYMERS PVT LTD') then
    raise exception 'Select WALKMATE EXPORTS PVT LTD or FOOTTECH POLYMERS PVT LTD as the vendor';
  end if;
  return new;
end $$;
drop trigger if exists transactions_validate_purchase_vendor on public.transactions;
create trigger transactions_validate_purchase_vendor
before insert or update of vendor_name,type on public.transactions
for each row execute function public.validate_purchase_vendor();

update public.transaction_items ti set
  purchase_discount_amount=round(ti.unit_price*0.05,2),
  purchase_igst_amount=round((ti.unit_price-round(ti.unit_price*0.05,2))*0.05,2)
from public.transactions tx
where tx.id=ti.transaction_id and tx.type='purchase';

notify pgrst, 'reload schema';
