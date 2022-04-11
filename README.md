# Business / Home Docker Setup
My findings and code for how to setup Docker in a small enterprise environment. A how to for Docker container backups and best practices for setting up. 

### Environment
Most setups typically have a NAS and an application server. In this guide I use a NAS from Synology and my preferred OS for my host server is [Alpine](https://alpinelinux.org/). 

## The problem with Docker and volumes
There is a lot of conflicting information on what the proper way to setup Docker is. A lot of the confusion comes from Docker's own documentation, with them saying things like "[Volumes are the best way to persist data in Docker](https://docs.docker.com/storage/)". This has proven to be very misleading in my quest of figuring out the right way to set it up. 

As far as I can tell it doesn't seem like Docker has a cookie cutter solution for backing up containers. If you try and copy your data out of a Volume Bind Mount you are going to run into permission issues with most containers. Similarly, if you try and create an SMB or NFS mount from your NAS and store the docker files in there you will run into permission issues (because the owner of the files needs to be the user that is used within each container, that user will likely not exist on the host environment or your NAS). Once you restore your backups your container won't be able to use the files as the user and permissions will have changed on all of the restored files. 
If you use volumes managed by Docker it is not easy to change the files within said volumes. Volumes are just meant for storing data that the container creates and uses. You are not meant to interact with this data directly. 

## The solution
The reality is that when it comes to managing and backing up data for each container the answer is going to change depending on the container. I will list some of the containers I use and how I set them up. 

### Portainer
If you don't know Portainer, you should probably use it, it is a super handy tool for checking up on your containers and performing basic tasks for when you can't be bothered remembering the command line options. [Installation instructions here.](https://docs.portainer.io/v/ce-2.9/start/install/server/docker/linux) No backups required. 

### Plex, Sonarr and Jackett (and Download Station)
I use Plex as my media centre, and Sonarr and Jacket for making sure I always have the latest episodes for each of my TV shows. This media data is relatively unimportant to me. I don't care about backing it up, however I do have a lot of it so it is impractical to store it anywhere but on my NAS. 

These 3 containers therefore need to access a Shared Folder on my Synology NAS. In the past I used the SMB protocol (apk add samba-client) but while the speed was adequate, I found it to be too unreliable. I would from time to time have the containers suddenly loose certain permissions over the mount and could no longer delete files, or sometimes write at all. I ended up settling on NFS and it is markedly better for use between Unix systems as it was clearly designed for Linux and solves many of the permission issues. 

To set it up I followed [the instructions from Synology](https://kb.synology.com/en-us/DSM/tutorial/How_to_access_files_on_Synology_NAS_within_the_local_network_NFS) for the server side. Then I followed [these instructions](https://www.hiroom2.com/2017/08/22/alpinelinux-3-6-nfs-utils-client-en/) to mount the drive in Alpine. 
```
1. Install nfs-utils package
$ sudo apk add nfs-utils
$ sudo rc-update add nfsmount
$ sudo rc-service nfsmount start

2.Mount NFS with mount.nfs
$ NFS_SERVER=drive.mydomain.nz
$ NFS_DIR=/volume1/Media
$ sudo mount -t nfs ${NFS_SERVER}:${NFS_DIR} /mnt/Media

3.Mount NFS on boot
$ echo "${NFS_SERVER}:${NFS_DIR} /mnt/drive nfs _netdev 0 0" | \
sudo tee -a /etc/fstab

4.If needed unmount
$ umount -f -l /mnt/Media.
```

Then you can find my Docker Run code here (I need to convert this to Docker Compose but haven't gotten around to it yet): [/Docker/containers/plex/](https://github.com/Loizzus/EnterpriseDockerSetup/blob/main/Docker/containers/plex/dockerRunScript.txt)

The only problem that I had after setting this up was that on boot the containers would start up before the NFS drive was mounted causing all the containers to error out until I restarted them. To fix this I told the docker service to start after the NFS service by adding this configuration to the end of the docker service config file: /etc/conf.d/docker
```
# Command added by admin to make Docker start after network drive has been mounted
rc_need="nfsmount"
```

### GitLab
GitLab is easy enough to setup, in fact its documentation is the best I've ever seen for a Docker container. To backup Gitlab you have to run a command inside the container itself which creates a backup file for you. However, they do skimp on a couple of important files (for security reasons which I have chosen to ignore). Anyway, I created a batch script in [/Docker/containers/gitlab](https://github.com/Loizzus/EnterpriseDockerSetup/tree/main/Docker/containers/gitlab) that you can automatically execute using "crontab -e" that automates the process and copies everything to your mounted drive. 

### MsSQL - Microsoft SQL
In [/Docker/containers/mssql](https://github.com/Loizzus/EnterpriseDockerSetup/tree/main/Docker/containers/mssql) you can find the script that must be run as a cronjob on the host OS. This script runs a command inside the MsSQL container to create the backup then the script copies the backup from your bind mount to your NAS. 

### MySQL
For this script (in [/Docker/containers/mysql](https://github.com/Loizzus/EnterpriseDockerSetup/tree/main/Docker/containers/mysql)) I opted to use the MySQL dump utility which I felt was more versatile. It allows me to run the script from my Synology NAS and remotely connect to the MySQL server to dump the databases. 

### Ouroboros - Container updater
This is just a good tool to have. It updates containers to the latest versions. 
```
docker run -d --name ouroboros \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e LATEST=false \
  -e SELF_UPDATE=true \
  -e MONITOR="gitlab portainer sqlserver mysql knowledge docker_web_1 nodejs-internal" \
  -e CLEANUP=true \
  --restart unless-stopped \
  pyouroboros/ouroboros
```

### Knowledge Base
```
docker pull koda/docker-knowledge
mkdir /var/lib/knowledge
chmod a+w /var/lib/knowledge

docker run -d \
-p 8085:8080 \
-v /var/lib/knowledge:/root/.knowledge \
--restart unless-stopped \
--name knowledge \
koda/docker-knowledge
```

### Node.js
In my case there isn't a lot to backup in node because my data is all stored in a database, I don't have any files that node creates that I want to keep. If I make changes to my node code, I just copy them it into the bind mount folder using WinSCP then use command line to:
```
$ cd /var/lib/nodejs
$ docker-compose down
$ docker-compose up -d
```

### NginX
This is one of the most important containers for using Docker, it is what allows you to have multiple websites hosted on one machine. As I prefer Node.js over PHP I don't use its PHP capabilities, I just have it host static websites and act as an application proxy. A.k.a. it looks at what hostname people were looking for when they got directed to the server and directs the traffic to the appropriate container. I often have over 6 or 7 websites on a single Alpine host with no issues thanks to this. 

## Backing up your Synology
After you have backed up all your Docker files to Synology find a good cloud storage provider, set them up in Hyper Backup and configure a backup task to upload everything to the cloud on a regular basis. 
