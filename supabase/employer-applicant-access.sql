-- Allow employers to view only the basic profile details of people
-- who have applied to one of their own jobs. Phone numbers remain hidden.
begin;

revoke select on table public.profiles from authenticated;
grant select (
  id,
  account_type,
  full_name,
  country,
  headline,
  bio,
  company_name,
  website,
  created_at,
  updated_at
) on table public.profiles to authenticated;

drop policy if exists "Employers read applicant profiles for their jobs" on public.profiles;
create policy "Employers read applicant profiles for their jobs"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    where a.applicant_id = profiles.id
      and j.employer_id = auth.uid()
  )
);

commit;
