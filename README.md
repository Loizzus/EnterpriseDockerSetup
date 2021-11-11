# Business / Home Docker Setup
My findings and code for how to setup Docker in a small enterprise environment (not big enough for Kubernetes)

## My setup
I have found that most setups typically have a NAS and an application server (often a Virtual Machine host but that is irrelevant). I typically use a NAS from Synology and the my prefered OS for Docker is Alpine.  

## What is the best practice way of setting up Docker? 
There is a lot of conflicting information on what the proper way to setup Docker is. A lot of the confusion comes from Docker's own documentation, with them saying things like "[Volumes are the best way to persist data in Docker](https://docs.docker.com/storage/)". This has proven to be misleading at best. 

As far as I can tell it doesn't seem liek Docker has a cookie cutter solution for backing up your containers. If you try and create a Volume Bind Mount you are going to run into permission issues with certain containers when you try and copy files from the bind 
