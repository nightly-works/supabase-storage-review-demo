#!/usr/bin/env bash
# Replays the app on a throwaway PostgreSQL cluster: the four attacks on the storage setup as delivered
# (each must work), then the fixes, the same attacks (each must be refused) and normal use.
# Exits non-zero at the first unexpected result.
set -euo pipefail
cd "$(dirname "$0")"
BIN=$(ls -d /usr/lib/postgresql/*/bin | tail -1)
DATA=$(mktemp -d)
SOCK=$(mktemp -d)
trap '"$BIN/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$DATA" "$SOCK"' EXIT
"$BIN/initdb" -D "$DATA" -A trust -U postgres >/dev/null
"$BIN/pg_ctl" -D "$DATA" -o "-k $SOCK -c listen_addresses=''" -l "$DATA/log" -w start >/dev/null
PSQL=(psql -X -q -o /dev/null -v ON_ERROR_STOP=1 -h "$SOCK" -U postgres postgres)
"${PSQL[@]}" -f sql/00_supabase_shim.sql -f sql/01_app.sql -f tests/seed.sql
echo "As delivered:"
"${PSQL[@]}" -v expect=works -f tests/attacks.sql
"${PSQL[@]}" -c "truncate storage.objects" -f tests/seed.sql
"${PSQL[@]}" -f sql/02_fixes.sql
echo "After the fixes:"
"${PSQL[@]}" -v expect=refused -f tests/attacks.sql
"${PSQL[@]}" -f tests/normal_use.sql
echo "all checks passed"
