-- Permanently remove a customer, their ledger activity, and customer-linked sales.
-- The existing transaction deletion routine restores sale quantities to inventory.
create or replace function public.delete_customer_account(p_customer_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid := auth.uid();
  v_transaction_id uuid;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  perform 1 from public.customers where id=p_customer_id and owner_id=v_owner for update;
  if not found then raise exception 'Customer not found'; end if;

  -- Reuse the store's transaction-aware reversal so sale stock is returned and all
  -- linked invoice payment records are cascaded with their invoice.
  for v_transaction_id in
    select id from public.transactions
    where customer_id=p_customer_id and owner_id=v_owner
    order by case type when 'sale' then 0 when 'payment' then 1 else 2 end,created_at,id
  loop
    if exists(select 1 from public.transactions where id=v_transaction_id and owner_id=v_owner) then
      perform public.delete_store_transaction(v_transaction_id,true);
    end if;
  end loop;

  -- Clear any orphaned customer references before removing the customer row.
  delete from public.transactions where customer_id=p_customer_id and owner_id=v_owner;
  delete from public.customers where id=p_customer_id and owner_id=v_owner;
end;
$$;
revoke all on function public.delete_customer_account(uuid) from public;
grant execute on function public.delete_customer_account(uuid) to authenticated;
notify pgrst, 'reload schema';
