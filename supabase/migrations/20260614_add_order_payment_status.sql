alter table public.orders
  add column if not exists payment_status text not null default 'pending'
    check (payment_status in ('pending', 'paid', 'failed', 'expired', 'cancelled')),
  add column if not exists midtrans_order_id text,
  add column if not exists paid_at timestamp with time zone;

create index if not exists idx_orders_payment_status
  on public.orders(payment_status);

create index if not exists idx_orders_midtrans_order_id
  on public.orders(midtrans_order_id);

drop policy if exists "User update payment sendiri" on public.orders;

create policy "User update payment sendiri"
  on public.orders for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
