-- Anchor 0002: push device registration.

-- A push token belongs to whoever registered it last: a shared phone, a reinstall, or a sign-out/in on the
-- same device must hand it over instead of colliding with the old owner's row. Definer, because the old
-- row belongs to someone else and RLS (rightly) hides it from the caller.
create function register_device(p_platform device_platform, p_token text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  insert into devices (user_id, platform, push_token) values (auth.uid(), p_platform, p_token)
  on conflict (push_token) do update
    set user_id = auth.uid(), platform = excluded.platform, updated_at = now();
end $$;

revoke execute on function register_device(device_platform, text) from public, anon;
grant execute on function register_device(device_platform, text) to authenticated;
