-- Run this once in Supabase SQL Editor to enable private portal messaging.
create table if not exists public.job_messages (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint job_messages_distinct_participants check (sender_id <> recipient_id)
);
create index if not exists job_messages_application_created_idx
  on public.job_messages(application_id, created_at);
create index if not exists job_messages_recipient_created_idx
  on public.job_messages(recipient_id, created_at desc);
alter table public.job_messages enable row level security;
grant select, insert on public.job_messages to authenticated;
grant update (read_at) on public.job_messages to authenticated;

drop policy if exists "Application participants read messages" on public.job_messages;
create policy "Application participants read messages"
on public.job_messages for select to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "Application participants send messages" on public.job_messages;
create policy "Application participants send messages"
on public.job_messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    where a.id = application_id
      and (
        (a.applicant_id = auth.uid() and recipient_id = j.employer_id)
        or (j.employer_id = auth.uid() and recipient_id = a.applicant_id)
      )
  )
);

drop policy if exists "Recipients mark messages read" on public.job_messages;
create policy "Recipients mark messages read"
on public.job_messages for update to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

-- Applicants can still access the job details attached to their own application,
-- even if the employer later closes the listing.
drop policy if exists "Applicants read jobs they applied to" on public.jobs;
create policy "Applicants read jobs they applied to"
on public.jobs for select to authenticated
using (
  exists (
    select 1 from public.applications a
    where a.job_id = jobs.id and a.applicant_id = auth.uid()
  )
);
