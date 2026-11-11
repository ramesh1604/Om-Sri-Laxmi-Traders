-- Atomic deletes and customer payment maintenance. Run after the retail return migration.
alter table public.transaction_items add column if not exists returned_quantity numeric(14,3) not null default 0;
alter table public.transaction_items add column if not exists inventory_article_number text;
alter table public.transaction_items add column if not exists inventory_colour text;
alter table public.transaction_items add column if not exists inventory_size text;
alter table public.transaction_items add column if not exists inventory_purchase_rate numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists inventory_rate_discount_percent numeric(8,3) not null default 0;
alter table public.transaction_items add column if not exists inventory_gst_amount numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists inventory_retail_price numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists input_gst_amount numeric(14,2) not null default 0;

create or replace function public.capture_inventory_item_snapshot()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_product public.products; v_type text;
begin
  if new.inventory_ref is null and new.product_id is null then return new; end if;
  select type into v_type from public.transactions where id=new.transaction_id and owner_id=new.owner_id;
  if v_type not in ('sale','stock_adjustment') then return new; end if;
  select * into v_product from public.products where id=coalesce(new.inventory_ref,new.product_id) and owner_id=new.owner_id;
  if not found then return new; end if;
  new.inventory_ref:=coalesce(new.inventory_ref,v_product.id);
  new.product_id:=coalesce(new.product_id,v_product.id);
  new.inventory_article_number:=coalesce(new.inventory_article_number,v_product.article_number);
  new.inventory_colour:=coalesce(new.inventory_colour,v_product.colour);
  new.inventory_size:=coalesce(new.inventory_size,v_product.size);
  new.inventory_purchase_rate:=coalesce(nullif(new.inventory_purchase_rate,0),v_product.purchase_rate);
  new.inventory_rate_discount_percent:=coalesce(nullif(new.inventory_rate_discount_percent,0),v_product.rate_discount_percent);
  new.inventory_gst_amount:=coalesce(nullif(new.inventory_gst_amount,0),v_product.gst_amount);
  new.inventory_retail_price:=coalesce(nullif(new.inventory_retail_price,0),v_product.retail_price);
  new.cost_price:=coalesce(nullif(new.cost_price,0),v_product.cost_price);
  new.dealer_discount_percent:=coalesce(nullif(new.dealer_discount_percent,0),v_product.dealer_discount_percent);
  return new;
end $$;
drop trigger if exists transaction_items_capture_inventory_snapshot on public.transaction_items;
create trigger transaction_items_capture_inventory_snapshot before insert or update of inventory_ref,product_id on public.transaction_items
for each row execute function public.capture_inventory_item_snapshot();

drop function if exists public.delete_purchase(uuid);
create function public.delete_purchase(p_transaction_id uuid,p_allow_stock_override boolean default false)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_tx public.transactions; v_line record; v_product public.products;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  select * into v_tx from public.transactions where id=p_transaction_id and owner_id=v_owner and type='purchase' for update;
  if not found then raise exception 'Purchase bill not found'; end if;
  for v_line in select coalesce(ti.inventory_ref,ti.product_id) as product_id,sum(ti.quantity) as quantity,min(ti.product_name) as product_name
    from public.transaction_items ti where ti.transaction_id=v_tx.id and ti.owner_id=v_owner
    and coalesce(ti.inventory_ref,ti.product_id) is not null group by coalesce(ti.inventory_ref,ti.product_id) order by 1 loop
    select * into v_product from public.products where id=v_line.product_id and owner_id=v_owner for update;
    if found and v_product.stock_quantity<v_line.quantity and not p_allow_stock_override then
      raise exception 'Stock for % is below the invoice quantity; confirm the override to delete anyway',v_line.product_name;
    end if;
  end loop;
  -- The owner-confirmed override removes each article row, including any remaining stock.
  delete from public.products p where p.owner_id=v_owner and p.id in (
    select coalesce(ti.inventory_ref,ti.product_id) from public.transaction_items ti
    where ti.transaction_id=v_tx.id and ti.owner_id=v_owner and coalesce(ti.inventory_ref,ti.product_id) is not null
  );
  delete from public.transactions where id=v_tx.id and owner_id=v_owner;
end $$;
revoke all on function public.delete_purchase(uuid,boolean) from public;
grant execute on function public.delete_purchase(uuid,boolean) to authenticated;

create or replace function public.adjust_stock(p_product_id uuid,p_delta numeric,p_notes text default null)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_product public.products; v_tx public.transactions;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_delta=0 then raise exception 'Stock change cannot be zero'; end if;
  select * into v_product from public.products where id=p_product_id and owner_id=v_owner for update;
  if not found then raise exception 'Product not found'; end if;
  if v_product.stock_quantity+p_delta<0 then raise exception 'Stock cannot go below zero'; end if;
  update public.products set stock_quantity=stock_quantity+p_delta where id=v_product.id and owner_id=v_owner;
  insert into public.transactions(owner_id,reference,type,customer_name,total,notes)
  values(v_owner,'STK-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),'stock_adjustment',v_product.name,p_delta,p_notes) returning * into v_tx;
  insert into public.transaction_items(owner_id,transaction_id,product_id,inventory_ref,product_name,quantity,unit_price,line_total,mrp,unit,cost_price,dealer_discount_percent,inventory_article_number,inventory_colour,inventory_size,inventory_purchase_rate,inventory_rate_discount_percent,inventory_gst_amount,inventory_retail_price)
  values(v_owner,v_tx.id,v_product.id,v_product.id,v_product.name,abs(p_delta),v_product.purchase_rate,round(v_product.purchase_rate*abs(p_delta),2),v_product.mrp,v_product.unit,v_product.cost_price,v_product.dealer_discount_percent,v_product.article_number,v_product.colour,v_product.size,v_product.purchase_rate,v_product.rate_discount_percent,v_product.gst_amount,v_product.retail_price);
  delete from public.products where id=v_product.id and owner_id=v_owner and stock_quantity=0;
  return v_tx;
end $$;
revoke all on function public.adjust_stock(uuid,numeric,text) from public;
grant execute on function public.adjust_stock(uuid,numeric,text) to authenticated;

create or replace function public.update_customer_payment(p_transaction_id uuid,p_amount numeric,p_payment_method text,p_notes text default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_payment public.transactions; v_sale public.transactions; v_old numeric(14,2); v_customer uuid; v_day date; v_seq text; v_reference text;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payment amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','online') then raise exception 'Choose cash or online payment'; end if;
  select * into v_payment from public.transactions where id=p_transaction_id and owner_id=v_owner and type='payment' for update;
  if not found then raise exception 'Customer payment not found'; end if;
  v_old:=coalesce(v_payment.total,v_payment.amount_paid,0); v_customer:=v_payment.customer_id;
  if v_customer is null then raise exception 'This payment is not linked to a customer'; end if;
  perform 1 from public.customers where id=v_customer and owner_id=v_owner for update;
  if not found then raise exception 'Payment customer not found'; end if;
  if v_payment.related_transaction_id is not null then
    select * into v_sale from public.transactions where id=v_payment.related_transaction_id and owner_id=v_owner and type='sale' for update;
    if not found then raise exception 'Linked invoice was not found'; end if;
    if p_amount>v_sale.total then raise exception 'Payment cannot exceed the invoice total'; end if;
    update public.transactions set amount_paid=p_amount where id=v_sale.id and owner_id=v_owner;
  end if;
  update public.customers set balance=balance+v_old-p_amount,updated_at=now() where id=v_customer and owner_id=v_owner;
  v_day:=(v_payment.created_at at time zone 'Asia/Kolkata')::date;
  v_seq:=substring(coalesce(v_payment.reference,'') from '-([0-9]+)$');
  if v_seq is null then v_seq:='1'; end if;
  v_reference:=upper(p_payment_method)||'-'||to_char(v_day,'YYMMDD')||'-'||v_seq;
  update public.transactions set total=p_amount,amount_paid=p_amount,payment_method=p_payment_method,notes=p_notes,reference=v_reference
    where id=p_transaction_id and owner_id=v_owner and type='payment';
end $$;
revoke all on function public.update_customer_payment(uuid,numeric,text,text) from public;
grant execute on function public.update_customer_payment(uuid,numeric,text,text) to authenticated;

create or replace function public.delete_store_transaction(p_transaction_id uuid,p_allow_stock_override boolean default false)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_line record; v_product public.products;
  v_product_id uuid; v_restore numeric(14,3); v_new_stock numeric(14,3); v_name text; v_unit text; v_mrp numeric(14,2);
  v_rate numeric(14,2); v_rate_discount numeric(8,3); v_gst numeric(14,2); v_cost numeric(14,2); v_dealer numeric(8,3); v_retail numeric(14,2);
  v_article text; v_colour text; v_size text;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  select * into v_tx from public.transactions where id=p_transaction_id and owner_id=v_owner for update;
  if not found then raise exception 'Transaction not found'; end if;
  if v_tx.type='purchase' then
    perform public.delete_purchase(v_tx.id,p_allow_stock_override);
    return;
  elsif v_tx.type='payment' then
    if v_tx.customer_id is not null then
      update public.customers set balance=balance+coalesce(v_tx.total,v_tx.amount_paid,0),updated_at=now() where id=v_tx.customer_id and owner_id=v_owner;
    end if;
    if v_tx.related_transaction_id is not null then
      update public.transactions set amount_paid=greatest(0,amount_paid-coalesce(v_tx.total,v_tx.amount_paid,0))
        where id=v_tx.related_transaction_id and owner_id=v_owner and type='sale';
    end if;
    delete from public.transactions where id=v_tx.id and owner_id=v_owner;
    return;
  elsif v_tx.type='opening_balance' then
    if v_tx.customer_id is not null then update public.customers set balance=balance-v_tx.total,updated_at=now() where id=v_tx.customer_id and owner_id=v_owner; end if;
    delete from public.transactions where id=v_tx.id and owner_id=v_owner;
    return;
  elsif v_tx.type='sale' then
    if v_tx.customer_id is not null and v_tx.sale_type='wholesale' then
      update public.customers set balance=balance-(v_tx.total-coalesce(v_tx.amount_paid,0)),updated_at=now() where id=v_tx.customer_id and owner_id=v_owner;
    end if;
    for v_line in select * from public.transaction_items where transaction_id=v_tx.id and owner_id=v_owner loop
      if v_tx.sale_type='retail' and v_tx.customer_name='General Retail' then continue; end if;
      v_restore:=greatest(0,coalesce(v_line.quantity,0)-case when v_tx.sale_type='retail' then coalesce(v_line.returned_quantity,0) else 0 end);
      if v_restore<=0 then continue; end if;
      v_product_id:=coalesce(v_line.inventory_ref,v_line.product_id);
      if v_product_id is null then continue; end if;
      select * into v_product from public.products where id=v_product_id and owner_id=v_owner for update;
      if found then
        update public.products set stock_quantity=stock_quantity+v_restore where id=v_product_id and owner_id=v_owner;
      else
        v_name:=coalesce(nullif(v_line.product_name,''),'Inventory item'); v_unit:=coalesce(nullif(v_line.unit,''),'unit'); v_mrp:=coalesce(v_line.mrp,0);
        v_rate:=coalesce(nullif(v_line.inventory_purchase_rate,0),round(v_mrp*0.60,2));
        v_rate_discount:=coalesce(nullif(v_line.inventory_rate_discount_percent,0),case when v_mrp>0 then round((1-v_rate/v_mrp)*100,3) else 0 end);
        v_gst:=coalesce(v_line.inventory_gst_amount,round(v_rate*0.05,2)); v_cost:=coalesce(nullif(v_line.cost_price,0),round(v_rate*0.95*1.05,2));
        v_dealer:=coalesce(v_line.dealer_discount_percent,case when v_mrp>0 then round((1-v_cost/v_mrp)*100,3) else 0 end);
        v_retail:=coalesce(nullif(v_line.inventory_retail_price,0),v_mrp); v_article:=v_line.inventory_article_number; v_colour:=v_line.inventory_colour; v_size:=v_line.inventory_size;
        insert into public.products(id,owner_id,name,unit,stock_quantity,mrp,purchase_rate,rate_discount_percent,gst_amount,cost_price,dealer_discount_percent,retail_price,article_number,colour,size)
        values(v_product_id,v_owner,v_name,v_unit,v_restore,v_mrp,v_rate,v_rate_discount,v_gst,v_cost,v_dealer,v_retail,v_article,v_colour,v_size);
      end if;
      update public.transaction_items ti set product_id=v_product_id from public.transactions parent
        where ti.transaction_id=parent.id and parent.type='purchase' and ti.owner_id=v_owner and parent.owner_id=v_owner
          and ti.transaction_id<>v_tx.id and ti.product_id is null and ti.product_name=v_line.product_name;
    end loop;
    delete from public.transactions where id=v_tx.id and owner_id=v_owner;
    return;
  elsif v_tx.type='stock_adjustment' then
    select * into v_line from public.transaction_items where transaction_id=v_tx.id and owner_id=v_owner limit 1;
    if found then
      v_product_id:=coalesce(v_line.inventory_ref,v_line.product_id); v_restore:=-v_tx.total;
      if v_product_id is null then raise exception 'Stock adjustment is missing its inventory article reference'; end if;
      select * into v_product from public.products where id=v_product_id and owner_id=v_owner for update;
      if found then
        v_new_stock:=v_product.stock_quantity+v_restore;
        if v_new_stock<0 then
          if not p_allow_stock_override then raise exception 'Reversing this adjustment would make stock negative; confirm override to remove the article'; end if;
          delete from public.products where id=v_product_id and owner_id=v_owner;
        elsif v_new_stock=0 then delete from public.products where id=v_product_id and owner_id=v_owner;
        else update public.products set stock_quantity=v_new_stock where id=v_product_id and owner_id=v_owner; end if;
      elsif v_restore>0 then
        v_mrp:=coalesce(v_line.mrp,0); v_rate:=coalesce(nullif(v_line.inventory_purchase_rate,0),round(v_mrp*0.60,2));
        insert into public.products(id,owner_id,name,unit,stock_quantity,mrp,purchase_rate,rate_discount_percent,gst_amount,cost_price,dealer_discount_percent,retail_price,article_number,colour,size)
        values(v_product_id,v_owner,v_line.product_name,coalesce(v_line.unit,'unit'),v_restore,v_mrp,v_rate,coalesce(v_line.inventory_rate_discount_percent,40),coalesce(v_line.inventory_gst_amount,round(v_rate*.05,2)),coalesce(v_line.cost_price,round(v_rate*.95*1.05,2)),coalesce(v_line.dealer_discount_percent,0),coalesce(v_line.inventory_retail_price,v_mrp),v_line.inventory_article_number,v_line.inventory_colour,v_line.inventory_size);
      end if;
    else
      select * into v_product from public.products where owner_id=v_owner and name=v_tx.customer_name for update;
      if not found then raise exception 'Cannot find the affected inventory article for this older stock adjustment'; end if;
      v_new_stock:=v_product.stock_quantity-v_tx.total;
      if v_new_stock<0 then
        if not p_allow_stock_override then raise exception 'Reversing this adjustment would make stock negative'; end if;
        delete from public.products where id=v_product.id and owner_id=v_owner;
      elsif v_new_stock=0 then delete from public.products where id=v_product.id and owner_id=v_owner;
      else update public.products set stock_quantity=v_new_stock where id=v_product.id and owner_id=v_owner; end if;
    end if;
    delete from public.transactions where id=v_tx.id and owner_id=v_owner;
    return;
  end if;
  raise exception 'This transaction type cannot be deleted';
end $$;
revoke all on function public.delete_store_transaction(uuid,boolean) from public;
grant execute on function public.delete_store_transaction(uuid,boolean) to authenticated;
notify pgrst,'reload schema';
