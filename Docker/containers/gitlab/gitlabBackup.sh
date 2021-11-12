#!/bin/sh

# Script to backup gitlab to company drive

TODAY=$(date +"%Y-%m-%d")
TIME=$(date +"%T")

echo Creating gitlab backup
docker exec -t gitlab gitlab-backup create

echo Moving new backup
mv /var/lib/gitlab/data/backups/* /mnt/drive/Docker/containers/gitlab/backups

echo Copying and zipping config files
zip /mnt/drive/Docker/containers/gitlab/backups/configs_${TODAY}_${TIME}.zip /var/lib/gitlab/config/gitlab.rb /var/lib/gitlab/config/gitlab-secrets.json

echo Deleting old backups
find /mnt/drive/Docker/containers/gitlab/backups/* -mtime +7 -exec rm {} \;

echo Completed