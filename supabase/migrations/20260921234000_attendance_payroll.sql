-- Calculate the current payroll period from RFID attendance.

create index if not exists attendance_user_check_in_idx
  on public.attendance (user_id, check_in desc);

drop view if exists public.view_pending_payroll;

create view public.view_pending_payroll
with (security_invoker = true)
as
with attendance_summary as (
  select
    a.user_id,
    count(*) filter (
      where upper(coalesce(a.status, 'PRESENT')) in ('PRESENT', 'LATE')
    )::integer as days_present,
    coalesce(
      sum(
        extract(
          epoch from (coalesce(a.check_out, a.check_in) - a.check_in)
        ) / 3600
      ),
      0
    )::numeric(12, 2) as total_hours
  from public.attendance a
  where a.check_in >= date_trunc('day', now()) - interval '15 days'
    and a.check_in < date_trunc('day', now()) + interval '1 day'
  group by a.user_id
)
select
  p.id as user_id,
  p.full_name,
  p.position,
  coalesce(p.daily_rate, 0)::numeric(12, 2) as daily_rate,
  coalesce(s.total_hours, 0)::numeric(12, 2) as total_hours,
  coalesce(s.days_present, 0)::integer as days_present,
  (
    coalesce(s.days_present, 0) * coalesce(p.daily_rate, 0)
  )::numeric(12, 2) as estimated_earnings
from public.profiles p
left join attendance_summary s on s.user_id = p.id
where upper(coalesce(p.role, '')) not in ('OWNER', 'GUEST')
  and upper(coalesce(p.account_status, 'ACTIVE')) <> 'ARCHIVED'
  and not exists (
    select 1
    from public.payrolls py
    where py.user_id = p.id
      and upper(coalesce(py.status, '')) = 'PAID'
      and py.period_end >= date_trunc('day', now()) - interval '15 days'
  )
order by p.full_name;

notify pgrst, 'reload schema';
