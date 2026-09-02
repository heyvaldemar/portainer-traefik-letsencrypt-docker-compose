#!/bin/bash

# # portainer-restore-data.sh Description
# Restores portainer's data directory from a backup set taken by the backups service.
# 1. **List Backups**: shows the archives in the backups volume.
# 2. **Select Backup**: you paste the timestamp of the set to restore (the part after the name).
# 3. **Stop Service**: portainer is stopped so nothing writes to the data directory.
# 4. **Restore**: the data archive is unpacked over the data directory, then each SQLite
#    database is restored from its consistent copy.
# 5. **Start Service**: portainer is started again.
# Make it executable once: `chmod +x portainer-restore-data.sh`

APP_CONTAINER="$(docker compose -p portainer ps -q portainer)"
BACKUPS_CONTAINER="$(docker compose -p portainer ps -q backups)"
BACKUP_PATH="/srv/portainer/backups"
DATA_NAME="portainer-data-backup"

echo "--> All available backup sets (timestamp = the part after the name):"
docker exec "$BACKUPS_CONTAINER" sh -c "ls -1 $BACKUP_PATH"

echo "--> Paste the timestamp of the set to restore and press [ENTER]
--> Example: YYYY-MM-DD_hh-mm"
echo -n "--> "
read -r STAMP
case "$STAMP" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "--> That is not a timestamp" >&2; exit 1 ;;
esac

echo "--> Stopping portainer..."
docker stop "$APP_CONTAINER" > /dev/null

echo "--> Restoring the data directory from $DATA_NAME-$STAMP.tar.gz..."
docker exec "$BACKUPS_CONTAINER" sh -c "tar -C /data -xzpf $BACKUP_PATH/$DATA_NAME-$STAMP.tar.gz" || { echo "--> data archive restore FAILED" >&2; docker start "$APP_CONTAINER" > /dev/null; exit 1; }
echo "--> Recovery completed..."

echo "--> Starting portainer..."
docker start "$APP_CONTAINER" > /dev/null
