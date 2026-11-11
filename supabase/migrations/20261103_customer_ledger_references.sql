-- Date-stamped financial-year references for customer invoices and cash/online receipts.
alter table public.transactions add column if not exists payment_method text;
alter table public.transactions drop constraint if exists transactions_payment_method_check;
alter table public.transactions add constraint transactions_payment_method_check
  check (payment_method is null or payment_method in ('cash','online'));
alter table public.transactions add column if not exists related_transaction_id uuid references public.transactions(id) on delete cascade;
create index if not exists transactions_related_transaction_idx on public.transactions(related_transaction_id);

drop function if exists public.record_payment(uuid,numeric,text);
create or replace function public.record_payment(p_customer_id uuid, p_amount numeric, p_notes text default null, p_payment_method text default null)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_tx public.transactions; v_name text; v_fy_start date; v_seq bigint; v_business_date date:=timezone('Asia/Kolkata',now())::date;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_amount <= 0 then raise exception 'Payment must be greater than zero'; end if;
  if p_payment_method is null or p_payment_method not in ('cash','online') then raise exception 'Choose cash or online payment'; end if;
  select name into v_name from customers where id=p_customer_id and owner_id=v_owner for update;
  if not found then raise exception 'Customer not found'; end if;
  v_fy_start:=make_date(extract(year from v_business_date)::integer - case when extract(month from v_business_date)::integer<4 then 1 else 0 end,4,1);
  perform pg_advisory_xact_lock(hashtext(v_owner::text),extract(year from v_fy_start)::integer);
  select count(*)+1 into v_seq from transactions where owner_id=v_owner and type='payment' and (created_at at time zone 'Asia/Kolkata')>=v_fy_start and (created_at at time zone 'Asia/Kolkata')<v_fy_start+interval '1 year';
  update customers set balance=balance-p_amount,updated_at=now() where id=p_customer_id and owner_id=v_owner;
  insert into transactions(owner_id,reference,type,customer_id,customer_name,total,amount_paid,notes,payment_method)
  values(v_owner,upper(p_payment_method)||'-'||to_char(v_business_date,'YYMMDD')||'-'||v_seq,'payment',p_customer_id,v_name,p_amount,p_amount,p_notes,p_payment_method) returning * into v_tx;
  return v_tx;
end $$;
revoke all on function public.record_payment(uuid,numeric,text,text) from public;
grant execute on function public.record_payment(uuid,numeric,text,text) to authenticated;
drop function if exists public.complete_wholesale_sale(uuid,numeric,jsonb,numeric,text);
drop function if exists public.complete_wholesale_sale(uuid,numeric,numeric,integer,boolean,jsonb,numeric);
create or replace function public.complete_wholesale_sale(p_customer_id uuid,p_discount_rate numeric,p_extra_discount_rate numeric,p_payment_days integer,p_print_discount_rate boolean,p_items jsonb,p_amount_paid numeric,p_payment_method text)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_customer public.customers; v_item jsonb; v_product public.products;
  v_qty numeric(14,3); v_line_discount numeric(8,3); v_inclusive numeric(14,2); v_price numeric(14,2); v_gst numeric(14,2);
  v_subtotal numeric(14,2):=0; v_tax numeric(14,2):=0; v_total numeric(14,2):=0; v_discount numeric(14,2):=0;
  v_fy_start date; v_seq bigint; v_invoice_reference text; v_payment_reference text;
  v_business_date date:=timezone('Asia/Kolkata',now())::date;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_customer_id is null then raise exception 'Select a registered customer'; end if;
  if p_discount_rate is null or p_discount_rate<0 or p_discount_rate>=100 then raise exception 'Customer discount must be from 0%% to less than 100%%'; end if;
  if p_extra_discount_rate is null or p_extra_discount_rate<0 or p_extra_discount_rate>=100 then raise exception 'Plus discount must be from 0%% to less than 100%%'; end if;
  if p_payment_days<0 or (p_extra_discount_rate>0 and p_payment_days<=0) then raise exception 'Enter the number of days allowed for the plus discount'; end if;
  if p_payment_method is null or p_payment_method not in ('cash','online') then raise exception 'Choose cash or online payment'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Add at least one item'; end if;
  select * into v_customer from public.customers where id=p_customer_id and owner_id=v_owner for update;
  if not found then raise exception 'Registered customer not found'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'quantity')::numeric;
    if v_qty<=0 then raise exception 'Quantity must be greater than zero'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock_quantity<v_qty then raise exception 'Not enough stock for %',v_product.name; end if;
    if v_product.mrp<=0 then raise exception 'MRP is missing for %',v_product.name; end if;
    v_line_discount:=coalesce(nullif(v_item->>'discount_rate','')::numeric,p_discount_rate);
    if v_line_discount<0 or v_line_discount>=100 then raise exception 'Item discount must be from 0%% to less than 100%%'; end if;
    v_inclusive:=round(v_product.mrp*(1-v_line_discount/100),2);
    v_price:=round(v_inclusive/1.05,2); v_gst:=v_inclusive-v_price;
    v_subtotal:=v_subtotal+round(v_price*v_qty,2);
    v_tax:=v_tax+round(v_gst*v_qty,2);
    v_total:=v_total+round(v_inclusive*v_qty,2);
    v_discount:=v_discount+round((v_product.mrp-v_inclusive)*v_qty,2);
  end loop;
  if p_amount_paid is null or p_amount_paid<=0 or p_amount_paid>v_total then raise exception 'Enter payment received now, greater than zero and no more than the bill total'; end if;
  v_fy_start:=make_date(extract(year from v_business_date)::integer - case when extract(month from v_business_date)::integer<4 then 1 else 0 end,4,1);
  perform pg_advisory_xact_lock(hashtext(v_owner::text),extract(year from v_fy_start)::integer);
  select count(*)+1 into v_seq from public.transactions where owner_id=v_owner and type='sale' and (created_at at time zone 'Asia/Kolkata')>=v_fy_start and (created_at at time zone 'Asia/Kolkata')<v_fy_start+interval '1 year';
  v_invoice_reference:='INV-'||to_char(v_business_date,'YYMMDD')||'-'||v_seq;
  select count(*)+1 into v_seq from public.transactions where owner_id=v_owner and type='payment' and (created_at at time zone 'Asia/Kolkata')>=v_fy_start and (created_at at time zone 'Asia/Kolkata')<v_fy_start+interval '1 year';
  v_payment_reference:=upper(p_payment_method)||'-'||to_char(v_business_date,'YYMMDD')||'-'||v_seq;
  insert into public.transactions(owner_id,reference,type,sale_type,customer_id,customer_name,subtotal,tax,total,amount_paid,discount_rate,discount_amount,net_value,gst_label,gst_rate,round_off,extra_discount_rate,payment_days,discount_due_date,early_payment_discount,print_discount_rate,payment_method)
  values(v_owner,v_invoice_reference,'sale','wholesale',v_customer.id,v_customer.name,v_subtotal,v_tax,v_total,p_amount_paid,p_discount_rate,v_discount,v_subtotal,'GST included',5,0,p_extra_discount_rate,p_payment_days,case when p_payment_days>0 then v_business_date+p_payment_days else null end,round(v_total*p_extra_discount_rate/100,2),coalesce(p_print_discount_rate,true),p_payment_method)
  returning * into v_tx;
  insert into public.transactions(owner_id,reference,type,customer_id,customer_name,total,amount_paid,notes,payment_method,related_transaction_id)
  values(v_owner,v_payment_reference,'payment',v_customer.id,v_customer.name,p_amount_paid,p_amount_paid,'Received against invoice '||v_invoice_reference,p_payment_method,v_tx.id);
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'quantity')::numeric;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    v_line_discount:=coalesce(nullif(v_item->>'discount_rate','')::numeric,p_discount_rate);
    v_inclusive:=round(v_product.mrp*(1-v_line_discount/100),2); v_price:=round(v_inclusive/1.05,2); v_gst:=v_inclusive-v_price;
    insert into public.transaction_items(owner_id,transaction_id,product_id,product_name,quantity,unit_price,line_total,mrp,unit,discount_amount,net_value,gst_amount,item_total,calculated_amount,amount_verified,sale_discount_rate,inventory_ref,dealer_discount_percent)
    values(v_owner,v_tx.id,v_product.id,v_product.name,v_qty,v_price,round(v_price*v_qty,2),v_product.mrp,v_product.unit,
      round((v_product.mrp-v_inclusive)*v_qty,2),round(v_price*v_qty,2),round(v_gst*v_qty,2),round(v_inclusive*v_qty,2),round(v_price*v_qty,2),true,v_line_discount,v_product.id,v_product.dealer_discount_percent);
    update public.products set stock_quantity=stock_quantity-v_qty where id=v_product.id and owner_id=v_owner;
  end loop;
  update public.customers set balance=balance+(v_total-p_amount_paid),updated_at=now() where id=v_customer.id and owner_id=v_owner;
  delete from public.products p where p.owner_id=v_owner and p.stock_quantity=0 and exists(select 1 from public.transaction_items ti where ti.transaction_id=v_tx.id and ti.product_id=p.id);
  return v_tx;
end $$;
revoke all on function public.complete_wholesale_sale(uuid,numeric,numeric,integer,boolean,jsonb,numeric,text) from public;
grant execute on function public.complete_wholesale_sale(uuid,numeric,numeric,integer,boolean,jsonb,numeric,text) to authenticated;
create or replace function public.sync_invoice_payment_record()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.type='sale' and old.amount_paid is distinct from new.amount_paid then
    if coalesce(new.amount_paid,0)<=0 then
      delete from public.transactions where related_transaction_id=new.id and owner_id=new.owner_id and type='payment';
    else
      update public.transactions set total=new.amount_paid,amount_paid=new.amount_paid
        where related_transaction_id=new.id and owner_id=new.owner_id and type='payment';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists sync_invoice_payment_record on public.transactions;
create trigger sync_invoice_payment_record after update of amount_paid on public.transactions
for each row execute function public.sync_invoice_payment_record();
notify pgrst, 'reload schema';
