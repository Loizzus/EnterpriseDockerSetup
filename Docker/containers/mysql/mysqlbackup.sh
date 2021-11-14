#!/bin/bash
## Designed to run in Synology DSM > Control Panel > Task Scheduler > User-defined script
TODAY=$(date +"%Y-%m-%d")
TIME=$(date +"%T")
################################################################
################## Update below values ########################
DB_BACKUP_PATH='/volume1/Backups/databasename'
MYSQL_HOST='alpine1.domain.nz'
MYSQL_PORT='3306'
MYSQL_USER='root'
MYSQL_PASSWORD='password'
DATABASE_NAME='databasename'
BACKUP_RETAIN_DAYS=90 ## Number of days to keep local backup copy
MYSQLDUMP=/volume1/@appstore/MariaDB10/usr/local/mariadb10/bin/mysqldump ## Get this file by installing the MariaDB package in Synology package manager (it doesn't need to actually run)
#################################################################
mkdir -p ${DB_BACKUP_PATH}/${TODAY} | echo ${DB_BACKUP_PATH}/${TODAY} "directory created"
echo "Backup started for database: ${DATABASE_NAME}"
$MYSQLDUMP -h ${MYSQL_HOST} \
-P ${MYSQL_PORT} \
-u ${MYSQL_USER} \
-p${MYSQL_PASSWORD} \
${DATABASE_NAME} | zip > ${DB_BACKUP_PATH}/${TODAY}/${DATABASE_NAME}_${TODAY}_${TIME}.sql.zip
if [ $? -eq 0 ]; then
echo "Database backup successfully completed"
else
echo "Error found during backup"
exit 1
fi
##### Remove backups older than {BACKUP_RETAIN_DAYS} days #####
echo "Removing backups older than" ${BACKUP_RETAIN_DAYS} "days "
DBDELDATE=`date +"%d%b%Y" --date="${BACKUP_RETAIN_DAYS} days ago"`
if [ ! -z ${DB_BACKUP_PATH} ]; then
cd ${DB_BACKUP_PATH}
if [ ! -z ${DBDELDATE} ] && [ -d ${DBDELDATE} ]; then
rm -rf ${DBDELDATE}
fi
fi
### End of script ####