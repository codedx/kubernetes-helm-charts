#!/bin/sh

echo "Creating backup directory..."

BACKUP_DIR='/bitnami/mariadb/backup/data'

[ -d $BACKUP_DIR ] || (mkdir -p $BACKUP_DIR)

BACKUP_DATA_DIR='/bitnami/mariadb/data'
BACKUP_TARGET_DIR="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S-Full)"
BACKUP_LOG_FILE="$BACKUP_DIR/backup.log"
BACKUP_DONE_FILE="$BACKUP_TARGET_DIR/done"

[ -f $BACKUP_DONE_FILE ] && exit

check_exit() {
	EC=$1
        if [ $EC -ne 0 ]; then
                echo "'$2' failed with exit code $EC!" | tee -a $3
                exit $4
        fi
}

echo "Starting backup to $BACKUP_TARGET_DIR..." | tee $BACKUP_LOG_FILE

DB_USER=root
DB_HOST=$(hostname)
DB_UPWD=$(cat /opt/codedx/cfg/.passwd)
check_exit $? 'read-password' $BACKUP_LOG_FILE 1

mariabackup --backup \
	--datadir=$BACKUP_DATA_DIR \
	--target-dir=$BACKUP_TARGET_DIR \
	--safe-slave-backup \
	--safe-slave-backup-timeout=600 \
	--user=$DB_USER \
	--password=$DB_UPWD \
	--host=$DB_HOST 2>&1 | tee -a $BACKUP_LOG_FILE
check_exit $? 'backup' $BACKUP_LOG_FILE $?

touch $BACKUP_DONE_FILE

cd $BACKUP_TARGET_DIR/..
echo "Removing old backups from $(pwd)..." | tee -a $BACKUP_LOG_FILE

find . -maxdepth 1 -type d -mtime +2 ! -path . -exec rm -Rf '{}' \;
check_exit $? 'cleanup' $BACKUP_LOG_FILE $?

echo 'Current backup files...' | tee -a $BACKUP_LOG_FILE
ls -la | tee -a $BACKUP_LOG_FILE

