#!/usr/bin/env bash
# Installs one copy of sp_WhoIsActive into a scratch database, installs it a
# second time to prove the script can be re-run, then runs the smoke tests and
# the blocking scenario. Exits non-zero on the first thing that fails.
#
# Usage:   tests/run-tests.sh <path to sp_WhoIsActive.sql>
# Environment:
#   SA_PASSWORD  required, the sa password
#   SERVER       default localhost
#   DB           scratch database name, default wia_ci (it is dropped and re-created)
#   SQLCMD       path to sqlcmd, found automatically if not set
#   KEEP_DB      set to 1 to leave the scratch database in place

set -u

PROC_FILE="${1:?usage: run-tests.sh <path to sp_WhoIsActive.sql>}"
: "${SA_PASSWORD:?SA_PASSWORD must be set}"
SERVER="${SERVER:-localhost}"
DB="${DB:-wia_ci}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -z "${SQLCMD:-}" ]; then
    # Newer images ship sqlcmd in mssql-tools18, older ones in mssql-tools
    for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
        if [ -x "$candidate" ]; then SQLCMD="$candidate"; break; fi
    done
fi
SQLCMD="${SQLCMD:-$(command -v sqlcmd || true)}"
if [ -z "$SQLCMD" ]; then echo "sqlcmd not found"; exit 1; fi

LOGS="$(mktemp -d)"
HOLDER_PID=""
WAITER_PID=""

# -b: exit non-zero on any error. -C: trust the container's self-signed
# certificate (mssql-tools18 encrypts by default).
run() { "$SQLCMD" -S "$SERVER" -U sa -P "$SA_PASSWORD" -C -b -l 30 -W "$@"; }

cleanup() {
    # Let the holder session finish, then remove the scratch database
    run -d "$DB" -i "$HERE/release_blockers.sql" >/dev/null 2>&1
    [ -n "$HOLDER_PID" ] && kill "$HOLDER_PID" 2>/dev/null
    [ -n "$WAITER_PID" ] && kill "$WAITER_PID" 2>/dev/null
    if [ "${KEEP_DB:-0}" != "1" ]; then
        run -d master -Q "IF DB_ID('$DB') IS NOT NULL BEGIN ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB]; END" >/dev/null 2>&1
    fi
    rm -rf "$LOGS"
}
trap cleanup EXIT

fail() { echo "FAILED: $1"; exit 1; }

# Runs a script and hides the result sets it produces. Shows the PASS and FAIL
# lines and any error text; on failure it also shows the end of the full output.
run_quiet() {
    local script="$1" log="$LOGS/$(basename "$1").log"
    run -d "$DB" -i "$script" >"$log" 2>&1
    local rc=$?
    grep -a -E '^(PASS|FAIL|Columns with|[0-9]+ of [0-9]+ scenarios)|^Msg [0-9]+|^Sqlcmd:|^Error' "$log" | cut -c1-300
    if [ "$rc" != "0" ]; then echo "--- end of full output"; tail -n 30 "$log" | cut -c1-300; fi
    return "$rc"
}

echo "== Server"
run -d master -h -1 -Q "SET NOCOUNT ON; SELECT @@VERSION" | head -n 1
[ "${PIPESTATUS[0]}" = "0" ] || fail "cannot connect to $SERVER"
echo "sqlcmd: $SQLCMD"
echo "proc file: $PROC_FILE"

echo "== Create scratch database $DB"
run -d master -Q "IF DB_ID('$DB') IS NOT NULL BEGIN ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB]; END; CREATE DATABASE [$DB];" \
    || fail "cannot create $DB"

echo "== Install, first run"
run -d "$DB" -i "$PROC_FILE" || fail "first install"
echo "== Install, second run (must be re-runnable)"
run -d "$DB" -i "$PROC_FILE" || fail "second install"
run -d "$DB" -Q "IF OBJECT_ID('dbo.sp_WhoIsActive', 'P') IS NULL RAISERROR('sp_WhoIsActive was not created', 16, 1); IF OBJECT_DEFINITION(OBJECT_ID('dbo.sp_WhoIsActive')) LIKE '%stub version, to be replaced%' RAISERROR('sp_WhoIsActive is still the stub', 16, 1);" \
    || fail "installed proc check"

echo "== Option sets"
run_quiet "$HERE/test_sp_whoisactive.sql" || fail "option sets"

echo "== Blocking scenario"
run -d "$DB" -i "$HERE/blocking_setup.sql" || fail "blocking setup"

run -d "$DB" -i "$HERE/blocking_holder.sql" >"$LOGS/holder.log" 2>&1 &
HOLDER_PID=$!

# Wait for the holder to take its lock before the waiter starts
locked=0
for _ in $(seq 1 60); do
    n="$(run -d "$DB" -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.dm_tran_locks WHERE resource_database_id = DB_ID() AND request_session_id <> @@SPID AND request_mode = 'X' AND request_status = 'GRANT' AND resource_type IN ('KEY', 'RID')" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt 0 ]; then locked=1; break; fi
    sleep 1
done
[ "$locked" = "1" ] || { cat "$LOGS/holder.log"; fail "holder session never took its lock"; }

run -d "$DB" -i "$HERE/blocking_waiter.sql" >"$LOGS/waiter.log" 2>&1 &
WAITER_PID=$!

run_quiet "$HERE/blocking_checks.sql"
checks=$?

run -d "$DB" -i "$HERE/release_blockers.sql" || fail "release flag"
wait "$HOLDER_PID"; holder=$?
wait "$WAITER_PID"; waiter=$?
HOLDER_PID=""; WAITER_PID=""

[ "$checks" = "0" ] || fail "blocking scenario checks"
if [ "$holder" != "0" ] || [ "$waiter" != "0" ]; then
    cat "$LOGS/holder.log" "$LOGS/waiter.log"
    fail "blocking sessions did not finish cleanly (holder $holder, waiter $waiter)"
fi

echo "== All tests passed"
