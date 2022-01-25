#!/bin/sh

# Script to backup gitlab to company drive

TODAY=$(date +"%Y-%m-%d")
TIME=$(date +"%T")

# Check if directory is mounted first, otherwise a new directory gets created and the mount to the Synology drive will subsequently fail. 
if [ -d "/mnt/drive/Docker" ] 
then
  echo "Directory /mnt/drive/Docker exists."

  echo Creating gitlab backup
  docker exec -t gitlab gitlab-backup create

  echo Moving new backup
  mv /var/lib/gitlab/data/backups/* /mnt/drive/Docker/containers/gitlab/backups

  echo Copying and zipping config files
  zip /mnt/drive/Docker/containers/gitlab/backups/configs_${TODAY}_${TIME}.zip /var/lib/gitlab/config/gitlab.rb /var/lib/gitlab/config/gitlab-secrets.json

  echo Deleting old backups
  find /mnt/drive/Docker/containers/gitlab/backups/* -mtime +7 -exec rm {} \;

  echo Completed

else
    echo "Error: Directory /mnt/drive/Docker does not exists."
fi
