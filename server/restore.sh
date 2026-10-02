#!/bin/sh
# Put a Peak Base backup back. Run on the server, in a terminal (Hostinger:
# VPS > Browser terminal).
#
#   sh restore.sh                       list the backups on this server
#   sh restore.sh peak-base-<date>.tar  restore one of them
#   sh restore.sh --drive               list the backups in Google Drive
#   sh restore.sh --drive peak-base-<date>.tar
#                                       fetch one from Google Drive, then restore it
#
# Restoring replaces everything on this server with the backup: notes, files,
# accounts and access keys, as they were that night. The app reconnects on its
# own; anything written after the backup is gone.
set -eu

P=${PROJECT:-peak-base}
BACKUP="$P-backup-1"
OFFSITE="$P-offsite-1"
FOLDER=${GDRIVE_FOLDER:-Peak Base backups}

if [ "${1:-}" = "--drive" ]; then
  shift
  if [ -z "${1:-}" ]; then
    docker exec "$OFFSITE" rclone lsf "gdrive:$FOLDER" --include "peak-base-*.tar"
    exit 0
  fi
  echo "Fetching $1 from Google Drive..."
  docker exec "$OFFSITE" rclone copy "gdrive:$FOLDER/$1" /backups/
fi

if [ -z "${1:-}" ]; then
  docker exec "$BACKUP" ls -1 /backups | grep '^peak-base-.*\.tar$' || echo "No backups yet."
  exit 0
fi

FILE=$1
case "$FILE" in
  peak-base-*.tar) ;;
  *) echo "Not a Peak Base backup name: $FILE" >&2; exit 1 ;;
esac
docker exec "$BACKUP" test -f "/backups/$FILE" || { echo "No such backup: $FILE" >&2; exit 1; }

printf 'This replaces everything on this server with %s. Type RESTORE to go on: ' "$FILE"
read -r answer
[ "$answer" = "RESTORE" ] || { echo "Stopped. Nothing changed."; exit 1; }

echo "Stopping the app server..."
docker stop "$P-caddy-1" >/dev/null 2>&1 || true
docker stop "$P-server-1" >/dev/null

echo "Restoring the database..."
docker exec "$BACKUP" sh -c "
  set -e
  rm -rf /tmp/restore && mkdir -p /tmp/restore
  tar -xf '/backups/$FILE' -C /tmp/restore
  export PGPASSWORD=\"\$(cat /secrets/pg)\"
  pg_restore --clean --if-exists --no-owner -d context /tmp/restore/db.dump
"

echo "Restoring the server key..."
docker exec "$BACKUP" cat /tmp/restore/jwt | docker run --rm -i -v "${P}_secrets:/secrets" alpine:3.20 \
  sh -c 'cat > /secrets/jwt.new && chmod 444 /secrets/jwt.new && mv /secrets/jwt.new /secrets/jwt'
docker exec "$BACKUP" rm -rf /tmp/restore

echo "Starting the app server..."
docker start "$P-server-1" >/dev/null
docker start "$P-caddy-1" >/dev/null 2>&1 || true
echo "Restored $FILE."
