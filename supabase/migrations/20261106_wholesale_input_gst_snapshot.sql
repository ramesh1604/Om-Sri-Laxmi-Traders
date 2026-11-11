-- Snapshot the inventory's unit GST basis as input tax on wholesale sale rows.
-- This lets invoice-level reports remain stable after inventory changes.
create or replace function public.capture_wholesale_input_gst()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_type text; v_sale_type text; v_product public.products;
begin
  select type,sale_type into v_type,v_sale_type from public.transactions where id=new.transaction_id and owner_id=new.owner_id;
  if v_type='sale' and v_sale_type='wholesale' then
    select * into v_product from public.products where id=coalesce(new.inventory_ref,new.product_id) and owner_id=new.owner_id;
    if found then new.input_gst_amount:=round(coalesce(v_product.gst_amount,0)*coalesce(new.quantity,0),2);
    else new.input_gst_amount:=round(coalesce(new.inventory_gst_amount,0)*coalesce(new.quantity,0),2); end if;
  end if;
  return new;
end $$;
drop trigger if exists transaction_items_wholesale_input_gst on public.transaction_items;
create trigger transaction_items_wholesale_input_gst before insert or update of transaction_id,product_id,inventory_ref,quantity on public.transaction_items
for each row execute function public.capture_wholesale_input_gst();
notify pgrst, 'reload schema';
