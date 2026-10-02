-- Run only after deploying send-order-push and creating the two Vault secrets.
-- Enable pg_cron and pg_net in Supabase Integrations first.
-- Calling cron.schedule with the same name updates this job.
select cron.schedule(
  'techcafe-order-push',
  '* * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'techcafe_project_url') || '/functions/v1/send-order-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'techcafe_push_worker_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
