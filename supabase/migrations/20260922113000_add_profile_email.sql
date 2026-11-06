-- Employee creation and staff profile views use the auth email on profiles.
alter table if exists public.profiles
  add column if not exists email text;

update public.profiles as profile
set email = auth_user.email
from auth.users as auth_user
where profile.id = auth_user.id
  and (profile.email is null or btrim(profile.email) = '');

notify pgrst, 'reload schema';
