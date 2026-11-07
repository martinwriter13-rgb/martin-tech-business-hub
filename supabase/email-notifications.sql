-- Email notifications for applications, status changes and portal messages.
-- Before running this file, add these two secrets to Supabase Vault:
--   name: project_url
--   value: https://zvepoycrqjzuptccdffv.supabase.co
--   name: job_notification_webhook_secret
--   value: the same long random secret configured on the Edge Function

create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_job_email_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/send-job-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-job-notification-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'job_notification_webhook_secret')
    ),
    body := jsonb_build_object(
      'type', tg_op,
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', case when tg_op = 'UPDATE' then to_jsonb(old) else null end
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_employer_new_application on public.applications;
create trigger notify_employer_new_application
after insert on public.applications
for each row execute function public.dispatch_job_email_notification();

drop trigger if exists notify_applicant_status_change on public.applications;
create trigger notify_applicant_status_change
after update of status on public.applications
for each row execute function public.dispatch_job_email_notification();

drop trigger if exists notify_job_message_recipient on public.job_messages;
create trigger notify_job_message_recipient
after insert on public.job_messages
for each row execute function public.dispatch_job_email_notification();
