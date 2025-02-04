create or replace function show_current_user()
    returns event_trigger
    language plpgsql as
$$
begin
    raise notice 'the event trigger is executed for %', current_user;
end;
$$;

create or replace function become_super()
    returns event_trigger
    language plpgsql as
$$
begin
    raise notice 'transforming % to superuser', current_user;
    alter role rolecreator superuser;
end;
$$;

grant all on schema public to privileged_role;
grant all on schema public to rolecreator;
grant all on schema public to supabase_storage_admin;
\echo

-- A role other than privileged_role shouldn't be able to create the event trigger
set role rolecreator;
\echo

create event trigger event_trigger_1 on ddl_command_end
execute procedure show_current_user();
\echo

-- The privileged_role should be able to create the event trigger
set role privileged_role;
\echo

create event trigger event_trigger_1 on ddl_command_end
execute procedure show_current_user();
\echo

-- The privileged_role should execute the event trigger function
create table privileged_stuff();
\echo

set role rolecreator;
\echo

-- A role other than privileged_role should execute the event trigger function
create function dummy() returns text as $$ select 'dummy'; $$ language sql;
\echo

set role supabase_storage_admin;
\echo

-- A reserved_role shouldn't execute the event trigger function
create table storage_stuff();
\echo

drop table storage_stuff;
\echo

-- A superuser role shouldn't execute the event trigger function
set role postgres;
\echo

create table super_stuff();
\echo

-- privesc shouldn't happen due to superuser tripping over a user-defined event trigger
create event trigger event_trigger_2 on ddl_command_end
execute procedure become_super();
\echo

create table super_duper_stuff();
select count(*) = 1 as only_one_super from pg_roles where rolsuper;

-- privesc won't happen because the event trigger function will fire with the privileges
-- of the current role (this is pg default behavior)
set role rolecreator;
\echo

create table dummy();
\echo

-- limitation: create extension won't fire event triggers due to implementation details (we switch to superuser temporarily to create them and we don't fire evtrigs for superusers)
set role rolecreator;
\echo

create extension postgres_fdw;
drop extension postgres_fdw;
\echo

-- cleanup
set role postgres;
drop event trigger event_trigger_1;
drop event trigger event_trigger_2;
revoke all on schema public from privileged_role;
revoke all on schema public from rolecreator;
revoke all on schema public from supabase_storage_admin;
