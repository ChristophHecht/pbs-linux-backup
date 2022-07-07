#!/bin/bash
# PBS Linux Backup Script V1.0 Config File

###########################
##Proxmox Backup Settings##
###########################

#Location of your proxmox-backup-client, you usually don't have to change this 
PBCLOCATION=proxmox-backup-client

#Path to your PBS Repository (Refer to PBS Docs) 
PBSREPOSITORY="myuser@pbs!myapitoken@mypbs:mystore"

##Set this, if you want to backup in a specific namespace
#NAMESPACE=""

##Set this, if your linux server does not trust your PBS Certificate
#PBSFINGERPRINT=""

##Set this, if you athenticate by password on your PBS
#PBSPASSWORD=""

##Set this, if your key file is encypted with a password
#PBSENCRYPTIONPASSWORD=""

##Should proxmox-backup-client be verbose
PBCVERBOSE=0

##Should pbc skip lost and found folders
PBCSKIPLOSTANDFOUND=0

##Should pbc backup all filesystems in path
PBCBACKUPALLFILESYSTEMS=0


#################
##BACKUP METHOD##
#################
##Possible values:
## simple: Just backup a path of a mounted filesystem recursively
## lvm: Create a lvm snapshot and backup the files on the filesystem
## lvm-image: Create a lvm snapshot and backup the whole device. Suitable for bare metal restores. Can use more storage that simple or lvm, because the whole device is backed up
BACKUPMETHOD="simple"


#######################
##SIMPLE METHOD SETUP##
#######################

##Path to backup recursively
#BACKUPPATH=""

############################
##LVM (IMAGE) METHOD SETUP##
############################

##Name of volume group containing the logical volume to backup
#VOLUMEGROUP=""

##Name of logical volume to backup
#LOGICALVOLUME=""

##Size of Snapshot, e. g. 2G for 2 gigabytes
#SNAPSHOTSIZE=""



###############
##MAIL Config##
###############

##Should PBS Linux Backup send mails? (0/1)
SENDMAILS=0

##Sender mail address
#MAILFROM=""

##Recipient mail address
#MAILTO=""

##SMTP Server
#MAILHOST=""

##SMTP Username
#MAILUSER=""

##SMTP Password
#MAILPASSWORD=""

##USE TLS (no/yes)
#MAILTLS=""

###########
##Logging##
###########

## Should savelog be used for log rotation?
USE_SAVELOG=0

## How many log generations should be kept for this job?
LOG_GENERATIONS=7

