-- import_containers: the one deliberate exception to "avoid RPCs" in
-- CLAUDE.md. Full-dataset import must atomically replace every row (clear
-- the registry, then repopulate it) - there's no single plain PostgREST
-- request that can express "delete everything, then insert this instead"
-- as one transaction, and a delete-request-then-insert-request pair would
-- leave a real window where the registry is empty if the second request
-- failed or the client died in between. Shape validation still happens
-- client-side before this is ever called (see ContainerService.importAll) -
-- this function only performs the atomic replace once that's done.
--
-- NEEDS A MANUAL `supabase db push` to staging/prod once a hosted project
-- exists - nothing applies this migration there automatically (see
-- CLAUDE.md).
create or replace function import_containers(payload jsonb) returns void
language plpgsql as $$
begin
  delete from containers;
  insert into containers (id, date, status, ingredients)
  select
    row->>'id',
    nullif(row->>'date', '')::date,
    row->>'status',
    coalesce(row->'ingredients', '[]'::jsonb)
  from jsonb_array_elements(payload) as row;
end;
$$;

grant execute on function import_containers(jsonb) to anon, authenticated, service_role;
