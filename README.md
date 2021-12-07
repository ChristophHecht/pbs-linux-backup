# pbs-linux-backup

pbs-linux-backup is a script, backing up the files of a linux filesystem with proxmox-backup-client and supporting various ways to ensure data consistency in the backup. The script is able to send an email notification after running. It also creates a timestamp file to monitor the last successful backup by the timestamp of that file. The script needs to be run as root.

The only argument given to borg-linux-backup.sh is the name of the config file of the specific job located in ./config/ folder. The name of the config file is also the jobname, located in the archive name in proxmox backup server. You also have to create a file in ./keyfiles/ with the name of the jobname containing the backup encryption key (refer to proxmox backup server docs).

For mail sending the programm sendemail and the libarys perl libaries Net::SSLeay and IO::Socket::SSL need to be installed. Under debian and ubuntu, these can be installed with "apt install sendemail libnet-ssleay-perl libio-socket-ssl-perl".


##Supported modes for consistency:

* simple: Just backup a path of a mounted filesystem recursively.
* lvm: Create a lvm snapshot and backup the files on the filesystem.
* lvm-image: Create a lvm snapshot and backup the whole device. Suitable for bare metal restores. Can use more storage that simple or lvm, because the whole device is backed up, which can include data which is deleted in the file system. Incremental backups are also slower than than simple or lvm.


##Folder Structure

The scripts creates the following folders in it's installation folder:

* ./config/: Used to store job config files.
* ./keyfile/: Used to store keyfiles for backup encryption.
* ./locks/: Used to store lock files.
* ./mounts/: Used for temporary mounts.
* ./timestamps/: Used for timestamp files of the last successful backup. Can be used for monitoring.
