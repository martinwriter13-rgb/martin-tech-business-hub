-- Martin Tech & Business Hub — Online Jobs portal
-- Run this in Supabase SQL Editor after creating your project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  account_type text not null default 'job_seeker'
    check (account_type in ('job_seeker','employer')),
  full_name text,
  phone text,
  country text,
  headline text,
  bio text,
  company_name text,
  website text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  company_name text not null,
  category text not null,
  employment_type text not null default 'Remote',
  location text not null default 'Worldwide',
  description text not null,
  requirements text,
  application_url text,
  salary_range text,
  status text not null default 'pending'
    check (status in ('pending','active','closed','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  applicant_id uuid not null references public.profiles(id) on delete cascade,
  cover_message text,
  cv_path text,
  status text not null default 'submitted'
    check (status in ('submitted','reviewing','shortlisted','rejected')),
  created_at timestamptz not null default now(),
  unique(job_id, applicant_id)
);

create index if not exists jobs_status_created_idx
  on public.jobs(status, created_at desc);
create index if not exists jobs_employer_idx on public.jobs(employer_id);
create index if not exists applications_applicant_idx
  on public.applications(applicant_id);
create index if not exists applications_job_idx on public.applications(job_id);

alter table public.profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;

-- Profiles: users can read and edit only their own profile.
drop policy if exists "Users read own profile" on public.profiles;
create policy "Users read own profile" on public.profiles
  for select to authenticated using (id = auth.uid());
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles
  for insert to authenticated with check (id = auth.uid());
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Public visitors can see active jobs; employers manage their own listings.
drop policy if exists "Anyone reads active jobs" on public.jobs;
create policy "Anyone reads active jobs" on public.jobs
  for select to anon, authenticated using (
    status = 'active' or employer_id = auth.uid()
  );
drop policy if exists "Employers create jobs" on public.jobs;
create policy "Employers create jobs" on public.jobs
  for insert to authenticated with check (
    employer_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.account_type = 'employer'
    )
  );
drop policy if exists "Employers update own jobs" on public.jobs;
create policy "Employers update own jobs" on public.jobs
  for update to authenticated using (employer_id = auth.uid())
  with check (employer_id = auth.uid());
drop policy if exists "Employers delete own jobs" on public.jobs;
create policy "Employers delete own jobs" on public.jobs
  for delete to authenticated using (employer_id = auth.uid());

-- Applicants can submit and view their own applications.
-- Employers can view/update applications for jobs they own.
drop policy if exists "Applicants and employers read applications" on public.applications;
create policy "Applicants and employers read applications" on public.applications
  for select to authenticated using (
    applicant_id = auth.uid()
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.employer_id = auth.uid()
    )
  );
drop policy if exists "Applicants apply to active jobs" on public.applications;
create policy "Applicants apply to active jobs" on public.applications
  for insert to authenticated with check (
    applicant_id = auth.uid()
    and exists (select 1 from public.jobs j where j.id = job_id and j.status = 'active')
  );
drop policy if exists "Employers update applications" on public.applications;
create policy "Employers update applications" on public.applications
  for update to authenticated using (
    exists (select 1 from public.jobs j where j.id = job_id and j.employer_id = auth.uid())
  ) with check (
    exists (select 1 from public.jobs j where j.id = job_id and j.employer_id = auth.uid())
  );

-- Private CV storage. Store each CV under a folder named with the user's auth UID.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('job-cvs', 'job-cvs', false, 10485760,
  array['application/pdf','application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do nothing;

drop policy if exists "Users upload own CVs" on storage.objects;
create policy "Users upload own CVs" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'job-cvs' and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Users read own CVs and hiring employers read applicants CVs" on storage.objects;
create policy "Users read own CVs and hiring employers read applicants CVs" on storage.objects
  for select to authenticated using (
    bucket_id = 'job-cvs' and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.applications a
        join public.jobs j on j.id = a.job_id
        where a.cv_path = name and j.employer_id = auth.uid()
      )
    )
  );
drop policy if exists "Users update own CVs" on storage.objects;
create policy "Users update own CVs" on storage.objects
  for update to authenticated using (
    bucket_id = 'job-cvs' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'job-cvs' and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Users delete own CVs" on storage.objects;
create policy "Users delete own CVs" on storage.objects
  for delete to authenticated using (
    bucket_id = 'job-cvs' and (storage.foldername(name))[1] = auth.uid()::text
  );
