-- Database Webhooks that call the `notify` Edge Function. TEMPLATE: replace <PROJECT_REF> and <WEBHOOK_SECRET>
-- (the same value as the WEBHOOK_SECRET function secret), then run once in the Supabase SQL editor.
-- Equivalent to creating these five webhooks in Dashboard -> Database -> Webhooks. See docs/PUSH.md.
-- Never commit a filled-in copy.

create trigger notify_urge_events
  after insert or update on public.urge_events
  for each row execute function supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/notify', 'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

create trigger notify_check_ins
  after insert or update on public.check_ins
  for each row execute function supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/notify', 'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

create trigger notify_encouragements
  after insert on public.encouragements
  for each row execute function supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/notify', 'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

create trigger notify_pod_members
  after insert on public.pod_members
  for each row execute function supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/notify', 'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');

create trigger notify_pods
  after update on public.pods
  for each row execute function supabase_functions.http_request(
    'https://<PROJECT_REF>.supabase.co/functions/v1/notify', 'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"<WEBHOOK_SECRET>"}', '{}', '5000');
