#!/bin/sh
# Get back a file that was deleted from Peak Base. Deleted notes are in the
# app's Trash; deleted files (images, PDFs, scripts) keep a copy here for 30
# days. Run on the server, in the folder that holds docker-compose.yml.
#
#   sh restore-file.sh                 list deleted files, newest first
#   sh restore-file.sh <id>            save that file into ./restored/
#
# Put the saved file back into the vault folder on any computer and it syncs
# as a new file.
set -eu

DOCKER=${DOCKER:-docker}
PG=$($DOCKER compose ps -q postgres)
[ -n "$PG" ] || { echo "The database container is not running here." >&2; exit 1; }
U=$($DOCKER exec "$PG" printenv POSTGRES_USER)
D=$($DOCKER exec "$PG" printenv POSTGRES_DB)
psql() { $DOCKER exec -i "$PG" psql -U "$U" -d "$D" -v ON_ERROR_STOP=1 "$@"; }

if [ -z "${1:-}" ]; then
  psql -c "SELECT id, rel_path AS file, pg_size_pretty(size) AS size,
                  to_char(deleted_at, 'YYYY-MM-DD HH24:MI') AS deleted,
                  to_char(purge_after, 'YYYY-MM-DD') AS kept_until
             FROM peak_file_trash ORDER BY deleted_at DESC LIMIT 200"
  exit 0
fi

case "$1" in
  *[!0-9]*) echo "Use the number from the list: sh restore-file.sh 42" >&2; exit 1 ;;
esac
NAME=$(psql -Atc "SELECT rel_path FROM peak_file_trash WHERE id = $1 AND data IS NOT NULL")
[ -n "$NAME" ] || { echo "No saved copy with id $1." >&2; exit 1; }
mkdir -p restored
OUT="restored/$(basename "$NAME")"
psql -Atc "SELECT encode(data, 'base64') FROM peak_file_trash WHERE id = $1" | base64 -d > "$OUT"
echo "Saved $OUT (was $NAME)"
