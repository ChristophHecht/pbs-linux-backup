#!/bin/bash
# PBS Linux Backup Script V1.0

function f_log {
	echo "$(date +"%Y-%m-%d-%H-%M-%S"):$1" | tee -a $LOGFILE
	if [ "$2" = "error" ]
	then
		echo "$(date +"%Y-%m-%d-%H-%M-%S"):UNSUCCESSFULLY FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP"
	fi
}

function f_print {
	echo "$(date +"%Y-%m-%d-%H-%M-%S"):$1"
}

function f_mail {
	if [ $SENDMAILS = 1 ]
	then
		if [ "$1" = "error" ]
		then
			sendemail -f $MAILFROM -t $MAILTO -u "ERROR: PBS-LINUX-BACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":(" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=$MAILTLS -a $LOGFILE
		fi
		if [ "$1" = "success" ] && [ $SENDMAILSONSUCCESS = 1 ]
		then
			sendemail -f $MAILFROM -t $MAILTO -u "SUCCESS: PBS-LINUX-BACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":)" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=$MAILTLS -a $LOGFILE
		fi
		if [ "$1" = "warning" ]
		then
			sendemail -f $MAILFROM -t $MAILTO -u "WARNING: PBS-LINUX-BACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":/" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=$MAILTLS -a $LOGFILE
		fi
	fi
}

function f_error {
	f_log "$1" "error"
	f_mail "error"
	f_cleanup
	exit $2
}

function f_cleanup {
	f_log "Cleaning up"
	if [ $MOUNTED = 1 ]
	then
		f_log "Unmounting LVM Snapshot"
		umount -f $MOUNTPATH | tee -a $LOGFILE
		if [ $PIPESTATUS -ne 0 ]
		then
			f_log "Warning: Could not unmount LVM Snapshot."
			WARNING=1
		fi
		MOUNTED=0
		f_log "Finished unmounting LVM Snapshot"
	fi

	if [ $SNAPSHOTTED = 1 ]
	then
		f_log "Deleting LVM Snapshot"
		lvremove -f $SNAPSHOTPATH | tee -a $LOGFILE
		if [ $PIPESTATUS -ne 0 ]
		then
			f_log "Warning: Could not delete LVM Snapshot."
			WARNING=1
		fi
		SNAPSHOTTED=0
		f_log "Finished deleting LVM Snapshot"
	fi
	
	if [ $LOCKED = 1 ]
	then
		f_log "Removing lock"
		rm $LOCKFILE | tee -a $LOGFILE
		if [ $PIPESTATUS -ne 0 ]
		then
			f_log "Warning: Could not remove lock."
			WARNING=1
		fi
		LOCKED=0
		f_log "Finished removing lock"
	fi
	f_log "Finished cleaning up"
}

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <configfile> (located in folder ./config)" >&2
  exit 1
fi

##INPUT
JOBNAME=$1
##INPUT
WORKINGDIRECTORY=$(dirname "$BASH_SOURCE")
CONFIGFILE="$WORKINGDIRECTORY/config/$JOBNAME"
TIMESTAMP="$(date +"%Y-%m-%d-%H-%M-%S")"

#QUIT IF CONFIGFILE DOES NOT EXIST
if [ ! -f $CONFIGFILE ]
then
        f_print "Error: Configfile not found, aborting."
		exit 2
fi

chmod +x $CONFIGFILE
. $CONFIGFILE

#SET ENVIRONMENT VARIABLES
export PBS_REPOSITORY=$PBSREPOSITORY
export PBS_FINGERPRINT=$PBSFINGERPRINT
export PBS_PASSWORD=$PBSPASSWORD
export PBS_ENCRYPTION_PASSWORD=$PBSENCRYPTIONPASSWORD

#SET HOST
HOST=$(hostname)

#SET STATUS VARIABLES FOR CLEANUP
LOCKED=0
SNAPSHOTTED=0
MOUNTED=0
WARNING=0

#SET VARIABLES FOR LVM, IF USED
if [ $BACKUPMETHOD = "lvm" ] || [ $BACKUPMETHOD = "lvm-image" ]
then
	SNAPSHOTNAME="pbs-linux-backup-$JOBNAME"
	LVPATH="/dev/$VOLUMEGROUP/$LOGICALVOLUME"
	SNAPSHOTPATH="/dev/$VOLUMEGROUP/$SNAPSHOTNAME"
	MOUNTPATH="$WORKINGDIRECTORY/mounts/$JOBNAME"
fi

#Set Backup Path
if [ $BACKUPMETHOD = "lvm-image" ]
then
	BKUPPATH=$SNAPSHOTPATH
	FILETYPE=img
fi

if [ $BACKUPMETHOD = "lvm" ]
then
	BKUPPATH=$MOUNTPATH
	FILETYPE=pxar
fi

if [ $BACKUPMETHOD = "simple" ]
then
	BKUPPATH=$BACKUPPATH
	FILETYPE=pxar
fi

NS=""
if [ -v NAMESPACE ]
then
	NS="--ns $NAMESPACE"
fi

#FILE PATHS
TIMESTAMPFILE="$WORKINGDIRECTORY/timestamps/$JOBNAME"
LOCKFILE="$WORKINGDIRECTORY/locks/$JOBNAME"
KEYFILE="$WORKINGDIRECTORY/keyfiles/$JOBNAME"


#CREATE FOLDER STRUCTURE
DIRTIMESTAMPFILE="$WORKINGDIRECTORY/timestamps/"
DIRLOCKFILE="$WORKINGDIRECTORY/locks/"
DIRLOGFILE="$WORKINGDIRECTORY/logs/"
DIRKEYFILE="$WORKINGDIRECTORY/keyfiles/"
mkdir -p $DIRTIMESTAMPFILE $DIRLOCKFILE $DIRLOGFILE $MOUNTPATH $DIRKEYFILE

#LOGFILE HANDLING
if [ $USE_SAVELOG = 0 ]
then
    LOGFILE="$WORKINGDIRECTORY/logs/$JOBNAME-$TIMESTAMP"
fi
if [ $USE_SAVELOG = 1 ]
then
    LOGFILE="$WORKINGDIRECTORY/logs/$JOBNAME"
    savelog -n -c $LOG_GENERATIONS $LOGFILE
fi


#Logfile erstellen
touch $LOGFILE

f_log "----------STARTING BACKUP OF $HOST $JOBNAME ON $TIMESTAMP----------"

##QUIT IF LOCKFILE EXISTS
if [ -f $LOCKFILE ]
then
        f_error "Error: Lockfile found." 3
fi

##SET VARIABLE FOR VERBOSE
$VERBOSE = ""
if [ $PBCVERBOSE = 1]
then
	$VERBOSE = "--verbose"
fi

##CREATE LOCKFILE
touch $LOCKFILE
LOCKED=1

##LVM (IMAGE) HANDLING:CREATE LVM SNAPSHOT
if [ $BACKUPMETHOD = "lvm" ] || [ $BACKUPMETHOD = "lvm-image" ]
then
	f_log "Creating LVM Snapshot."
	lvcreate -L${SNAPSHOTSIZE} -s -n $SNAPSHOTNAME $LVPATH | tee -a $LOGFILE
	if [ $PIPESTATUS -ne 0 ]
	then
		f_error "Error: Snapshot could not be created." 4
	fi
	SNAPSHOTTED=1
	f_log "Finished creating LVM Snapshot"
fi

##LVM HANDLING: MOUNT SNAPSHOT
if [ $BACKUPMETHOD = "lvm" ]
then
	f_log "Mounting LVM Snapshot."
	mount $SNAPSHOTPATH $MOUNTPATH | tee -a $LOGFILE
	if [ $PIPESTATUS -ne 0 ]
	then
			f_error "Error: Snapshot could not be mounted." 5
	fi
	MOUNTED=1
	f_log "Finished mounting LVM Snapshot"
fi

##DO BACKUP
f_log "Running Backup Job."
$PBCLOCATION backup $JOBNAME.$FILETYPE:$BKUPPATH $VERBOSE --skip-lost-and-found $PBCSKIPLOSTANDFOUND --all-file-systems $PBCBACKUPALLFILESYSTEMS --keyfile $KEYFILE --backup-type host --backup-id $HOST $NS   2>&1 >/dev/null | tee -a $LOGFILE
PBCERRORLEVEL=$PIPESTATUS
if [ $PBCERRORLEVEL -ne 0 ]
then
        f_error "Error: proxmox-backup-client returned $PBCERRORLEVEL." 6
fi
f_log "Finished backup job."

##CLEANUP
f_cleanup

##FINISH
if [ $WARNING = 1 ]
then
	f_log "Finished pbs-linux-backup with warnings" | tee -a $LOGFILE
	f_mail "warning"
fi
if [ $WARNING = 0 ]
then
	f_log "Successfully finished pbs-linux-backup" | tee -a $LOGFILE
	f_mail "success"
fi
rm $TIMESTAMPFILE
touch $TIMESTAMPFILE
exit 0
