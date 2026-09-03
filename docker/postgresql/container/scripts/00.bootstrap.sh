#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bootstrap_sql="$script_dir/database/00.bootstrap.sql"

psql -v ON_ERROR_STOP=1 \
	--username "$POSTGRES_USER" \
	--dbname "$POSTGRES_DB" \
	-v test_db="$POSTGRES_TEST" <<-'SQL'
	SELECT format('CREATE DATABASE %I', :'test_db')
	WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'test_db')\gexec
SQL

# =======================================================

psql -v ON_ERROR_STOP=1 \
	--username "$POSTGRES_USER" \
	--dbname "$POSTGRES_DB" \
	-v sampler_password="$SAMPLER_PASSWORD" \
	-v runner_password="$RUNNER_PASSWORD" \
	--file "$bootstrap_sql"

psql -v ON_ERROR_STOP=1 \
	--username "$POSTGRES_USER" \
	--dbname "$POSTGRES_TEST" \
	-v sampler_password="$SAMPLER_PASSWORD" \
	-v runner_password="$RUNNER_PASSWORD" \
	--file "$bootstrap_sql"
