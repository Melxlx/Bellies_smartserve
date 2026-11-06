-- Allow owners to assign delivery orders and riders to see/update their own assignments.
alter table public.orders enable row level security;

drop policy if exists "Owners can manage delivery orders" on public.orders;
create policy "Owners can manage delivery orders"
on public.orders
for all
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and upper(role) = 'OWNER'
  )
)
with check (
  exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and upper(role) = 'OWNER'
  )
);

drop policy if exists "Riders can view assigned delivery orders" on public.orders;
create policy "Riders can view assigned delivery orders"
on public.orders
for select
to authenticated
using (
  rider_id = (select auth.uid())
  and upper(coalesce(service_type, '')) = 'DELIVERY'
);

drop policy if exists "Riders can update assigned delivery orders" on public.orders;
create policy "Riders can update assigned delivery orders"
on public.orders
for update
to authenticated
using (rider_id = (select auth.uid()))
with check (rider_id = (select auth.uid()));

create index if not exists orders_rider_id_idx
on public.orders (rider_id)
where rider_id is not null;

notify pgrst, 'reload schema';