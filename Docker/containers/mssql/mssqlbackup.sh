#!/bin/sh

# Script to backup mssql database to company drive

TODAY=$(date +"%Y-%m-%d")
TIME=$(date +"%T")

echo Make backup folder in the container if it doesnt exist
sudo docker exec sqlserver mkdir /var/opt/mssql/backup

echo Creating backup of mRemoteNG database
sudo docker exec sqlserver /opt/mssql-tools/bin/sqlcmd \
   -S localhost -U SA -P 'password' \
   -Q "BACKUP DATABASE mRemoteNG TO DISK = N'/var/opt/mssql/backup/database_${TODAY}_${TIME}.bak' WITH NOFORMAT, NOINIT, NAME = 'database-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
   
echo Moving backup files
mv /var/lib/mssql/backup/* /mnt/drive/Docker/containers/mssql/backups/

echo Deleting old backups
find /mnt/drive/Docker/containers/mssql/backups/* -mtime +7 -exec rm {} \;

echo Completed