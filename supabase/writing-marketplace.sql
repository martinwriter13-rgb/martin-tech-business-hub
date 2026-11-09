-- Martin Tech Writing Marketplace schema. Applied to Supabase project Martin Tech Jobs.
-- Public browser clients use the publishable key only; all exposed tables have RLS.
-- Admin membership is provisioned separately by a trusted administrator.
create extension if not exists pgcrypto;
create table if not exists public.writing_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null check (role in ('client','writer')),
 display_name text not null, headline text, bio text, country text,
 skills text[] not null default '{}', hourly_rate numeric(12,2),
 currency text not null default 'KES', portfolio_url text,
 is_public boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.writing_projects (
 id uuid primary key default gen_random_uuid(),
 client_id uuid not null references public.writing_profiles(id) on delete restrict,
 title text not null, category text not null, brief text not null,
 budget_min numeric(12,2), budget_max numeric(12,2),
 currency text not null default 'KES', deadline date,
 status text not null default 'open' check(status in ('open','in_progress','submitted','completed','cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (budget_min is null or budget_min >= 0),
 check (budget_max is null or budget_max >= 0),
 check (budget_min is null or budget_max is null or budget_max >= budget_min)
);
create table if not exists public.writing_proposals (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.writing_projects(id) on delete cascade,
 writer_id uuid not null references public.writing_profiles(id) on delete cascade,
 cover_letter text not null, bid_amount numeric(12,2) not null check(bid_amount >= 0),
 currency text not null default 'KES', delivery_days integer not null check(delivery_days > 0),
 status text not null default 'submitted' check(status in ('submitted','shortlisted','accepted','rejected','withdrawn')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(project_id,writer_id)
);
create table if not exists public.writing_messages (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.writing_projects(id) on delete cascade,
 sender_id uuid not null references public.writing_profiles(id) on delete cascade,
 recipient_id uuid not null references public.writing_profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 5000),
 read_at timestamptz, created_at timestamptz not null default now(), check(sender_id <> recipient_id)
);
create table if not exists public.writing_milestones (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.writing_projects(id) on delete cascade,
 title text not null, description text, amount numeric(12,2) not null default 0 check(amount >= 0),
 due_date date, status text not null default 'pending' check(status in ('pending','in_progress','submitted','approved')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.writing_attachments (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.writing_projects(id) on delete cascade,
 uploader_id uuid not null references public.writing_profiles(id) on delete cascade,
 storage_path text not null unique, original_name text not null, content_type text, size_bytes bigint,
 created_at timestamptz not null default now()
);
create table if not exists public.writing_reviews (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.writing_projects(id) on delete cascade,
 reviewer_id uuid not null references public.writing_profiles(id) on delete cascade,
 reviewee_id uuid not null references public.writing_profiles(id) on delete cascade,
 rating integer not null check(rating between 1 and 5), comment text, created_at timestamptz not null default now(),
 check(reviewer_id <> reviewee_id), unique(project_id,reviewer_id)
);
create table if not exists public.writing_admins (
 user_id uuid primary key references auth.users(id) on delete cascade, created_at timestamptz not null default now()
);
create index if not exists writing_projects_status_created_idx on public.writing_projects(status,created_at desc);
create index if not exists writing_proposals_project_idx on public.writing_proposals(project_id,created_at desc);
create index if not exists writing_proposals_writer_idx on public.writing_proposals(writer_id,created_at desc);
create index if not exists writing_messages_project_idx on public.writing_messages(project_id,created_at);
create index if not exists writing_milestones_project_idx on public.writing_milestones(project_id);
create index if not exists writing_reviews_reviewee_idx on public.writing_reviews(reviewee_id,created_at desc);
alter table public.writing_profiles enable row level security;
alter table public.writing_projects enable row level security;
alter table public.writing_proposals enable row level security;
alter table public.writing_messages enable row level security;
alter table public.writing_milestones enable row level security;
alter table public.writing_attachments enable row level security;
alter table public.writing_reviews enable row level security;
alter table public.writing_admins enable row level security;
grant select,insert,update on public.writing_profiles to authenticated;
grant select,insert,update on public.writing_projects to authenticated;
grant select,insert,update on public.writing_proposals to authenticated;
grant select,insert,update on public.writing_messages to authenticated;
grant select,insert,update on public.writing_milestones to authenticated;
grant select,insert on public.writing_attachments to authenticated;
grant select,insert on public.writing_reviews to authenticated;
grant select on public.writing_admins to authenticated;
drop policy if exists "Writing profiles visible to owner and public writers" on public.writing_profiles;
create policy "Writing profiles visible to owner and public writers" on public.writing_profiles for select to authenticated using(id=(select auth.uid()) or (role='writer' and is_public=true));
drop policy if exists "Users create own writing profile" on public.writing_profiles;
create policy "Users create own writing profile" on public.writing_profiles for insert to authenticated with check(id=(select auth.uid()));
drop policy if exists "Users update own writing profile" on public.writing_profiles;
create policy "Users update own writing profile" on public.writing_profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
drop policy if exists "Authenticated users read open projects and clients read own" on public.writing_projects;
create policy "Authenticated users read open projects and clients read own" on public.writing_projects for select to authenticated using(status='open' or client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals p where p.project_id=id and p.writer_id=(select auth.uid())));
drop policy if exists "Clients create own writing projects" on public.writing_projects;
create policy "Clients create own writing projects" on public.writing_projects for insert to authenticated with check(client_id=(select auth.uid()) and exists(select 1 from public.writing_profiles p where p.id=(select auth.uid()) and p.role='client'));
drop policy if exists "Clients update own writing projects" on public.writing_projects;
create policy "Clients update own writing projects" on public.writing_projects for update to authenticated using(client_id=(select auth.uid())) with check(client_id=(select auth.uid()));
drop policy if exists "Writers and project owners read proposals" on public.writing_proposals;
create policy "Writers and project owners read proposals" on public.writing_proposals for select to authenticated using(writer_id=(select auth.uid()) or exists(select 1 from public.writing_projects p where p.id=project_id and p.client_id=(select auth.uid())));
drop policy if exists "Writers submit proposals to open projects" on public.writing_proposals;
create policy "Writers submit proposals to open projects" on public.writing_proposals for insert to authenticated with check(writer_id=(select auth.uid()) and exists(select 1 from public.writing_profiles p where p.id=(select auth.uid()) and p.role='writer') and exists(select 1 from public.writing_projects p where p.id=project_id and p.status='open'));
drop policy if exists "Project owners decide proposal status" on public.writing_proposals;
create policy "Project owners decide proposal status" on public.writing_proposals for update to authenticated using(exists(select 1 from public.writing_projects p where p.id=project_id and p.client_id=(select auth.uid()))) with check(exists(select 1 from public.writing_projects p where p.id=project_id and p.client_id=(select auth.uid())));
drop policy if exists "Project participants read writing messages" on public.writing_messages;
create policy "Project participants read writing messages" on public.writing_messages for select to authenticated using(sender_id=(select auth.uid()) or recipient_id=(select auth.uid()));
drop policy if exists "Project participants send writing messages" on public.writing_messages;
create policy "Project participants send writing messages" on public.writing_messages for insert to authenticated with check(sender_id=(select auth.uid()) and exists(select 1 from public.writing_projects p where p.id=project_id and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status in ('submitted','shortlisted','accepted'))) and (recipient_id=p.client_id or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=recipient_id and pr.status in ('submitted','shortlisted','accepted')))));
drop policy if exists "Recipients mark writing messages read" on public.writing_messages;
create policy "Recipients mark writing messages read" on public.writing_messages for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
drop policy if exists "Project participants read milestones" on public.writing_milestones;
create policy "Project participants read milestones" on public.writing_milestones for select to authenticated using(exists(select 1 from public.writing_projects p where p.id=project_id and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status='accepted'))));
drop policy if exists "Clients create milestones" on public.writing_milestones;
create policy "Clients create milestones" on public.writing_milestones for insert to authenticated with check(exists(select 1 from public.writing_projects p where p.id=project_id and p.client_id=(select auth.uid())));
drop policy if exists "Project participants update milestones" on public.writing_milestones;
create policy "Project participants update milestones" on public.writing_milestones for update to authenticated using(exists(select 1 from public.writing_projects p where p.id=project_id and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status='accepted')))) with check(exists(select 1 from public.writing_projects p where p.id=project_id and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status='accepted'))));
drop policy if exists "Project participants read writing attachments" on public.writing_attachments;
create policy "Project participants read writing attachments" on public.writing_attachments for select to authenticated using(uploader_id=(select auth.uid()) or exists(select 1 from public.writing_projects p where p.id=project_id and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status in ('shortlisted','accepted')))));
drop policy if exists "Project participants add writing attachments" on public.writing_attachments;
create policy "Project participants add writing attachments" on public.writing_attachments for insert to authenticated with check(uploader_id=(select auth.uid()) and exists(select 1 from public.writing_projects p where p.id=project_id and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status in ('shortlisted','accepted')))));
drop policy if exists "Project participants read writing reviews" on public.writing_reviews;
create policy "Project participants read writing reviews" on public.writing_reviews for select to authenticated using(true);
drop policy if exists "Completed project participants leave one review" on public.writing_reviews;
create policy "Completed project participants leave one review" on public.writing_reviews for insert to authenticated with check(reviewer_id=(select auth.uid()) and exists(select 1 from public.writing_projects p where p.id=project_id and p.status='completed' and ((p.client_id=reviewer_id and exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=reviewee_id and pr.status='accepted')) or (p.client_id=reviewee_id and exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=reviewer_id and pr.status='accepted')))));
drop policy if exists "Users read own writing admin membership" on public.writing_admins;
create policy "Users read own writing admin membership" on public.writing_admins for select to authenticated using(user_id=(select auth.uid()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('writing-project-files','writing-project-files',false,20971520,array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/plain','image/png','image/jpeg']) on conflict(id) do nothing;
drop policy if exists "Users upload own writing project files" on storage.objects;
create policy "Users upload own writing project files" on storage.objects for insert to authenticated with check(bucket_id='writing-project-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Participants read writing project files" on storage.objects;
create policy "Participants read writing project files" on storage.objects for select to authenticated using(bucket_id='writing-project-files' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.writing_attachments a join public.writing_projects p on p.id=a.project_id where a.storage_path=name and (p.client_id=(select auth.uid()) or exists(select 1 from public.writing_proposals pr where pr.project_id=p.id and pr.writer_id=(select auth.uid()) and pr.status in ('shortlisted','accepted'))))));
drop policy if exists "Users delete own writing project files" on storage.objects;
create policy "Users delete own writing project files" on storage.objects for delete to authenticated using(bucket_id='writing-project-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
