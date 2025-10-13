#!/usr/bin/env sh

# print notice when creating an extension
mkdir -p "$TMPDIR/extension-custom-scripts"
echo "do \$\$
      begin
        if not (@extname@ = ANY(ARRAY['dict_xsyn', 'insert_username'])) then
          return;
        end if;
        if exists (select from pg_available_extensions where name = @extname@) then
          raise notice 'extname: %, extschema: %, extversion: %, extcascade: %', @extname@, @extschema@, @extversion@, @extcascade@;
        end if;
      end \$\$;" > "$TMPDIR/extension-custom-scripts/before-create.sql"

mkdir -p "$TMPDIR/extension-custom-scripts/autoinc"
echo 'create extension citext;' > "$TMPDIR/extension-custom-scripts/autoinc/after-create.sql"

# assert both before-create and after-create scripts are run
mkdir -p "$TMPDIR/extension-custom-scripts/fuzzystrmatch"
echo 'create table t1();' > "$TMPDIR/extension-custom-scripts/fuzzystrmatch/before-create.sql"
echo 'drop table t1; create table t2 as values (1);' > "$TMPDIR/extension-custom-scripts/fuzzystrmatch/after-create.sql"

# assert both before-create and after-create scripts are run
mkdir -p "$TMPDIR/extension-custom-scripts/postgres_fdw"
cat > "$TMPDIR/extension-custom-scripts/postgres_fdw/after-create.sql" <<'EOF'
do $$
declare
  is_super boolean;
begin
  is_super = (
    select usesuper
    from pg_user
    where usename = 'privileged_role'
  );

  -- Need to be superuser to own FDWs, so we temporarily make privileged_role superuser.
  if not is_super then
    alter role privileged_role superuser;
  end if;

  alter foreign data wrapper postgres_fdw owner to privileged_role;

  if not is_super then
    alter role privileged_role nosuperuser;
  end if;
end $$;
EOF
