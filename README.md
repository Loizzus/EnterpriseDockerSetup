# Business / Home Docker Setup
My findings and code for how to setup Docker in a small enterprise environment (not big enough for Kubernetes)

### Environment
I have found that most setups typically have a NAS and an application server (often a Virtual Machine host but that is irrelevant). I typically use a NAS from Synology and my prefered OS for Docker is Alpine. 

## The problem with Docker
There is a lot of conflicting information on what the proper way to setup Docker is. A lot of the confusion comes from Docker's own documentation, with them saying things like "[Volumes are the best way to persist data in Docker](https://docs.docker.com/storage/)". This has proven to be misleading at best. 

As far as I can tell it doesn't seem like Docker has a cookie cutter solution for backing up your containers. If you try and create a Volume Bind Mount you are going to run into permission issues with certain containers when you try and copy files from the bound folder to another place. Same issue if you try and create a SMB or NFS mount on your Host environment. Because the owner of the files will be the user that is used within the container, that user will not exist on the Host environment and then the NAS. So you won't be able to restore your backup as the user will have changed on all those files. 
If you use a Volume managed by Docker it is not easy to change the files within said Volume. This Volume is just meant for storing data that the container creates and uses. You are not meant to inteact with this data directly. 

## My solution
The reality is that when it comes to managing and backing up data for each container it really depends on the container. I will list the containers I use and how I set them up. 

### Portainer
If you don't know portainer you should use it, it is a super handy tool for checking up on your containers. [Instructions here.](https://docs.portainer.io/v/ce-2.9/start/install/server/docker/linux)

### Plex, Sonarr and Jackett
I use Plex as my media center, and Sonarr and Jacket for making sure I always have the latest episode for each of my TV shows. This media data is relatively unimportant to me. I don't care about backing it up, however I do have a lot of it so it is only practical to store it on my NAS. Also my NAS has drive redundancy which is enough peace of mind for me. If my house burns downs I'll have bigger problems and can probably shell out for a Netflix subscription while I'm living in a hotel. 

These 3 containers therefore need to access the Shared Folder on my Synology NAS. For this I used to use SMB protocol (apk add samba-client) but while the speed was adequate I found this to be too unreliable. I would from time to time have the containers suddenly loose certain permissions over the mount and couldn't delete files anymore, or sometimes write at all. I ended up settling on NFS and it is markedly better for use between Unix systems. As it was clearly designed for Linux it solves all these permission issues. 

To set it up I followed [the instructions from Synology](https://kb.synology.com/en-us/DSM/tutorial/How_to_access_files_on_Synology_NAS_within_the_local_network_NFS) to get the Server side up. Then I followed [these instructions](https://www.hiroom2.com/2017/08/22/alpinelinux-3-6-nfs-utils-client-en/) to mount the drive in Alpine. 
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

The only problem that I had after setting this up was that on boot the containers would start up before the NFS drive was mounted causing all the containers to error out. To fix this I told the docker service to only start after the NFS service had started by adding this configuration to the end of the docker service config file here: /etc/conf.d/docker
```
# Command added by user to make docker only start after network drive has been mounted
rc_need="nfsmount"
```

### GitLab
GitLab is easy enough to setup, infact its' documentation is the best I've ever seen on a Docker container. To backup Gitlab you have to run a command inside the container itself which creates a backup file for you. However they do skimp on a couple of important files (for security reasons which I have chosen to ignore). Anyway I created a batch script in /Docker/containers/gitlab that you can automatically execute using "crontab -e". 

### MsSQL - Microsoft SQL
In /Docker/containers/mssql you can find the script that must be run as a cronjob on the host OS. It also runs the command within the MsSQL container to create the backup then the script copies it to the backup destination (hopefully your NAS). 

### MySQL
For this script I opted to use the MySQL dump utility which I felt was more versatile. It allows me to run the script from the NAS and remotely connect to the MySQL server to dump the databases. 

### Ouroboros - Updates other containers to latest version
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
