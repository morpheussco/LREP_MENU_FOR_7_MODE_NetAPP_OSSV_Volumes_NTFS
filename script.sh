#!/bin/sh
#########################################################################
# Script for automatic start of the right command for use of LREP	#
# Creator: Torsten Bauer at 24.10.2011					#
# Version: 0.9.0 - pre production status (Beta)				#
#									#
#									#
#########################################################################
# - Definition of variables
# =======================================================================
# ACTION - user interaction variable to define the action which is todo
# ANSWER - user answer on differend places of the script
# E_NETAPP - to define the exclusive network port of the NetApp server which host the OSSV backup
# EX - to define excluded volumes
# FILECOUNT - to define if files to delete exist
# ICO - to fill 4 variables from ~server.txt file to create the backup command
# LASTSTOP - to define last request before start of backup
# SERVER - to define server which is OSSV backuped by selection from ~server.txt file to create the backup command
# SERVERCOUNT - to define which OSSV volumes exist
# SERVERNAME - to define server which is OSSV backuped by user input
# VOLUME - to define the drive of a OSSV backuped server
# NETAPP - to define NetApp server which hosts the OSSV backup
# RESTOREPATH - to define NetApp restore path of the OSSV backuped server
# VOLUME_NAME - to define the drive of a OSSV backuped server without ":\"
# X - to define a counting variable to display all lines of ~server.txt
DATA_PATH=""	# data_path defines the path to the data folder
LREP_PATH=""	# lrep_path defines the path to the lrep folder
NAS_TYPE=""	# nas_type defines the hardware type of NAS (Thecus or QNAP)

echo -en '\033[1m'	# Set terminal letters to bold
trap '' 2	# Disables Ctrl+C (Signal 2)

# - Separation of type of NAS box done by superuser name
if [ $USER = sys ]; then
 NAS_TYPE=Thecus
 LREP_PATH=/raid/data/lrep
 DATA_PATH=/raid/data/data
fi

if [ $USER = admin ]; then
 NAS_TYPE=QNAP
 LREP_PATH=/share/lrep
 DATA_PATH=/share/data
fi

while :;do	# Loop for the menu

 clear	# Clear Terminal Screen

 # Display NAS-Box type and ask for user input
 echo
 echo " It's a $NAS_TYPE-NAS."
 echo

 # Menu for choice of operations
 echo " What do you want to do?"
 echo " Please select correct option and hit ENTER"
 echo
 echo " 1 - for \"Start backup\""
 echo " 2 - for \"Shutdown NAS\""
 echo " 3 - for \"Start restore\""
 echo " 4 - for \"Delete existing backup\""
 echo " 5 - for \"Change password\""
 echo
 echo " 0 - for \"Exit this menu\""
 echo
 echo " 7 - for \"Delete restore information\""
 echo
 echo
 echo -n " Your choice is "	# option -n supresses cursor next line

 read ACTION	# read typed choice from keyboard

 case $ACTION in	# Begin of the menu
  0)	# Exit this menu
   break
   ;;
  1)	# Display LREP Version by using option -v
   echo
   echo
   echo " Version check of LREP reader and writer"
   echo
   echo -n " LREP Reader has "	# option -n supresses cursor next line
   $LREP_PATH/lrep_reader -v
   echo -n " LREP Writer has "	# option -n supresses cursor next line
   $LREP_PATH/lrep_writer -v
   echo
   echo " You are working on NAS $HOSTNAME"
   echo
   LASTSTOP=N	# defines variable LASTSTOP and fill's it with "N" character
   while :; do	# Loop for the sub menu
    FILECOUNT=$(find $LREP_PATH/~backup_*.txt -type f 2>/dev/null | wc -l)	# filling variable FILECOUNT with the number of found files
    if [ $FILECOUNT -gt 0 ]; then	# if variable FILECOUNT is bigger as 0 then
     find $LREP_PATH/~backup_*.txt -type f -print | xargs rm -f	# find ~backup_*.txt in folder from variable LREP_PATH and delete it/them
    fi	# end of if
    unset FILECOUNT	# delete variable FILECOUNT
    # Ask for user input for selection of affected server
    echo
    echo " Please type the server name of the failed server."
    echo " Without UNC extention. e.g. sm04100"
    echo -n " Servername: "	# echo option -n supresses cursor next line
    read SERVERNAME	# read typed servername from keyboard
    echo
    echo -n " Is the servername okay (y/n) or (a) for abort ? "	# echo option -n supresses cursor next line
    read ANSWER	# read ANSWER characters from keyboard
    if [ "$ANSWER" = "y" -o "$ANSWER" = "Y" ]; then
     SERVERNAME="$(echo $SERVERNAME | tr "A-Z" "a-z")" # Trim upper case letters to lower case letters and export the result
     echo
     echo " Servername is $SERVERNAME"
     echo
     cut -f1,2,3,4 -d, $LREP_PATH/lrepConfig.txt | grep $SERVERNAME > $LREP_PATH/~server.txt	# extracts the filtered lines by variable SERVERNAME, colums 1-4 from file lrepConfig.txt and exports it to file ~server.txt
     SERVERCOUNT=$(cat $LREP_PATH/~server.txt| wc -w)	# counter of words in the file ~server.txt to fill the variable SERVERCOUNT
     if [ $SERVERCOUNT -gt 0 ]; then	# Switch SERVERCOUNT by grater (-gt) then 0
      SERVERLINES=$(cat $LREP_PATH/~server.txt| wc -l)	# counter of lines in the file ~server.txt to fill the variable SERVERLINES
      if [ $SERVERLINES -gt 1 ]; then	# Switch SERVERLINES by more then 1
       echo
       echo " Please select all NOT necessary volumes."
       echo
       echo " For this press the number of the line."
       echo
       echo " To continue without deselection press ENTER"
       echo
       echo
        REPLY=a
        while [ $REPLY != 0 ]; do
        Y=1
        while read X; do echo $Y: $X; let Y=Y+1; done <$LREP_PATH/~server.txt
        read REPLY
	if [ -z $REPLY ]; then
	 break 1
	else
         sed -i ''$REPLY'd' $LREP_PATH/~server.txt
         echo
         echo -n " Have you completed your choice? Type Y/y "	# echo option -n supresses cursor next line
         read EX
         if [ $EX = y -o $EX = Y ]; then REPLY=0 ;fi
	fi
        done
       SERVERLINES=$(cat $LREP_PATH/~server.txt| wc -l)	# counter of lines in the file ~server.txt to fill the variable SERVERLINES
      fi
      for ICO in $(cat $LREP_PATH/~server.txt); do
	SERVER=$(echo $ICO | cut -d, -f1)
   	VOLUME=$(echo $ICO | cut -d, -f2)
   	NETAPP=$(echo $ICO | cut -d, -f3)
   	RESTOREPATH=$(echo $ICO | cut -d, -f4)
	E_NETAPP=""
	if ([ $HOSTNAME = "xd99902" ] && [ $NETAPP = "xd01208" ]); then E_NETAPP=10.244.8.3; fi	# replace xd01028 frontend IP with exlusiv backend port
	if ([ $HOSTNAME = "xd99901" ] && [ $NETAPP = "xd00238" ]); then E_NETAPP=10.252.8.3; fi	# replace xd00238 frontend IP with exlusiv backend port
#	if ([ $HOSTNAME = "xd?????" ] && [ $NETAPP = "xd01231" ]); then E_NETAPP=10.55.128.3; fi	# replace xd01231 frontend IP with exlusiv backend port - not implemented by OGE
   	if [ -z $E_NETAPP ]; then
	 echo
	 echo " WARNING!!!"
	 echo " ==================================================="
	 echo
	 echo " NAS and NetApp on differend locations!"
	 echo " Backup will use WAN - and may take longer to complete!"
	 echo " Only use as last resort!"
	 echo " ==================================================="
	 echo
	 E_NETAPP=$NETAPP
	fi
   	VOLUME_NAME=$(echo "${VOLUME:0:1}")
   	VOLUME_NAME=$(echo $VOLUME_NAME | tr "A-Z" "a-z")	# Trim upper case letters to lower case letters and export the result
   	# Example for backup command for differend NAS types
   	# QNAP e.g. /share/lrep/lrep_reader -m inet -p snapvault_restore -o /share/data/restore@0 -f sm02678 -q d:/ 10.252.8.3:/vol/vol999/mirror_sm02678_de_d
   	# Thecus e.g.  /raid/data/lrep/lrep_reader -m inet -p snapvault_restore -o /raid/data/data/restore@0 -f sm02903 -q d:/ 10.244.8.3:/vol/vol55/mirror_sm02903_uk_d
   	echo "$LREP_PATH/lrep_reader -m inet -p snapvault_restore -o "$DATA_PATH"/"$SERVER"_"$VOLUME_NAME"@0 -f $SERVER -q $VOLUME_NAME:/ $E_NETAPP:$RESTOREPATH"|tr -d '\015'> $LREP_PATH/~backup_"$SERVER"_"$VOLUME_NAME".txt
	unset E_NETAPP
	echo " From $NETAPP to $HOSTNAME a backup for server $SERVER volume $VOLUME_NAME will be made."
      done
      echo
      echo " Last check befor start backup"
      echo -n " Everything all right? Y/y "	# echo option -n supresses cursor next line
      read LASTSTOP
      if [ "$LASTSTOP" = "y" -o "$LASTSTOP" = "Y" ]; then
	BACKUP_COUNT=$(find $LREP_PATH/~backup_*.txt -type f | wc -l)	# counter of file(s) ~backup_*.txt to fill the variable BACKUP_COUNT
	if [ $BACKUP_COUNT -gt 0 ]; then	# Switch RESTORECOUNT
	 cat $LREP_PATH/~backup_*.txt	# read temporary backup file for continue backup process
	 chmod 777 $LREP_PATH/*.txt
	 echo
	 echo
	 for BACKUP_RUN in $(find $LREP_PATH/~backup_*.txt -type f -print); do	# work until the find request is emtpy
	  $BACKUP_RUN &	# start backup in the background
	 done
	 unset BACKUP_RUN	# delete variable BACKUP_RUN
	 echo
	 echo " Please wait - screen refresh in 15 seconds."
	 echo
	 START=$(date +%s)
	 while (( 1 <= $(jobs -r|wc -l|sed -e "s/ //g") )); do	# run until there jobs in the background (counting jobs and compare if the result is bigger or equal 1)
	  sleep 15
	  clear	# Clear Terminal Screen
	  VOL=$(du -b $DATA_PATH/|cut -f1)	# counts files in the $DATA_PATH directory for calculation of the transfer rate
	  VOLK=$(($VOL /1024))
	  VOLM=$(($VOL /(1024*1024)))
	  VOLG=$(($VOL /(1024*1024*1024)))
	  END=$(date +%s)
	  DIFF=$(( $END - $START ))
	  echo
	  echo " Actual statistics and heartbeat"
	  echo " ==============================="
	  echo
	  echo " Transfered volume of data"
	  echo " -------------------------"
	  echo " $VOL Byte(s) are already transfered"
	  echo " $VOLK KByte(s) are already transfered"
	  echo " $VOLM MByte(s) are already transfered"
	  echo " $VOLG GByte(s) are already transfered"
	  echo
	  echo " Job running time"
	  echo " ----------------"
	  echo " $DIFF s have left since the backup has started"
	  echo " $((($DIFF )/60)) m have(has) left since the backup has started"
	  echo " $((($DIFF )/3600)) h have(has) left since the backup has started"
	  echo
	  echo " Transfer rate"
	  echo " -------------"
	  echo " $(((($VOL *3600) / $DIFF )/(1024*1024))) MByte/h"
	  echo " $(((($VOL *3600) / $DIFF )/(1024*1024*1024))) GByte/h"
	  echo
	  echo " Refresh all 15 seconds until the backup has finished."
	 done
	 echo $LREP_PATH/lrep_writer -p snapvault_restore "$DATA_PATH"/"$SERVER"_"$VOLUME_NAME"|tr -d '\012' '\015'> $LREP_PATH/~restore_"$SERVER"_"$VOLUME_NAME".txt # Build temporary restore file for this script
	 echo
	 echo " Backup completed"
	 rm $LREP_PATH/~backup_*.txt
	 chmod 777 $LREP_PATH/*.txt
	 break 1
	else
	 clear	# Clear Terminal Screen
	 echo
	 echo " No restore information available"
	 echo
	 read -p " Press any key to continue. "
	fi
       unset BACKUP_COUNT	# delete variable BACKUP_COUNT
      fi
     else
      echo
      echo " No matches found!"
      echo
      read -p " Press any key to continue. "
     fi
    else
     if [ $ANSWER = a -o $ANSWER = A ]; then
      break 2
     else
      clear	# Clear Terminal Screen
      echo
      echo " Please try again."
      echo
     fi
    fi
   unset ANSWER
   done	# End of sub loop
   # Request to change admin/sys password for a strong one
   echo
   echo " Remember to change the admin\sys password before shipping."
   echo " Don't forget!!! "
   echo
   passwd
   ;;
  2)	# Shutdown   
   clear
   echo
   echo
   echo -n " Do you want to shutdown the NAS (y/n)? "	# echo option -n supresses cursor next line
    read ANSWER	# read ANSWER characters from keyboard
    if [ $ANSWER = y -o $ANSWER = Y ]; then
     echo
#     echo " The shutdown starts in 10 seconds"
     echo " The reboot starts in 10 seconds"
     echo
     echo " It may take upto 1 minute for this session to close."
     echo
     echo " Please be patient."
     echo
      /sbin/reboot -d10	# Thecus reboot command
#      /sbin/poweroff -d10	# Thecus shutdown command?
    fi
    unset ANSWER
    exit
   ;;
  3)	# Restore by using local backup information stored in ~restore_*.txt files and in the data directory
   # QNAP e.g. /share/lrep/lrep_writer -p snapvault_restore /share/data/restore-file(s)
   # Thecus e.g. /raid/data/lrep/lrep_writer -p snapvault_restore /share/data/restore-file(s)
   RESTORECOUNT=$(find $LREP_PATH/~restore_*.txt -type f | wc -l)	# counter of file(s) ~restore_*.txt to fill the variable RESTORECOUNT
     if [ $RESTORECOUNT -gt 0 ]; then	# Switch RESTORECOUNT
      clear
      echo " This command will be executed."
      echo
      cat $LREP_PATH/~restore_*.txt	# read temporary restore file for continue restore process
      RPATH=$(cat $LREP_PATH/~restore_*.txt | cut -d" " -f4)
      RDRIVE=$(echo $RPATH| cut -d_ -f2)
      if [ $NAS_TYPE = "Thecus" ]; then IP=10.244.8.2; fi	# Set IP for the backend port of NAS
      if [ $NAS_TYPE = "QNAP" ]; then IP=10.252.8.2; fi	# Set IP for the backend port of NAS
      echo
      echo
      echo " Before you start the backup, check this. It must be done befor!"
      echo " ==============================================================="
      echo " 1.) Have you made the pysical network connection between server and NAS?"
      echo " 2.) Do you have IP connection between server and NAS via this connection?"
      echo " 3.) Have you installed OSSV software on the server?"
      echo " 4.) Have you configured OSSV?"
      echo " 5.) Are you ready to start the right snapvault command on the server?"
      echo " e.g. D:\Programs\netapp\snapvault\bin\snapvault restore -S $IP:$RPATH $RDRIVE:\ "
      echo
      echo -n " Do you want to start now (y/n)?"	# echo option -n supresses cursor next line
      unset RPATH
      unset RDRIVE
      unset IP
      read ANSWER	# read ANSWER characters from keyboard
       if [ $ANSWER = y -o $ANSWER = Y ]; then
        echo
        echo
        for RESTORE_RUN in $(find $LREP_PATH/~restore_*.txt -type f -print); do	# work until the find request is emtpy
	 if [ $NAS_TYPE = "Thecus" ]; then
	  echo
	  echo " Please don't press ENTER!"
	  echo " It will interrupt the restore process!!!"
	  echo
	  echo
          $RESTORE_RUN
	 fi
	 if [ $NAS_TYPE = "QNAP" ]; then
         $RESTORE_RUN &	# start restore in the background
	 fi
        done
	unset RESTORE_RUN	# delete variable RESTORE_RUN
	echo
	echo
	 if [ $NAS_TYPE = "QNAP" ]; then
	  START=$(date +%s)
	  while (( 1 <= $(jobs -r|wc -l|sed -e "s/ //g") )); do
	   sleep 15
	   clear	# Clear Terminal Screen
	   END=$(date +%s)
	   DIFF=$(( $END - $START ))
	   echo
	   echo " $DIFF s have left since the backup has started"
	   echo " $((($DIFF )/60)) m have left since the backup has started"
	   echo " $((($DIFF )/3600)) h have left since the backup has started"
	   echo
	   echo " Restore in progress..."
	   echo " Listing of actual jobs running in the background."
	   jobs
#	   JOB=
#	   echo " There is/are $JOB job/s running in the background."
	   echo
	  done
	  unset START	# delete variable START
	 fi
	echo
	echo " Restore completed"
	echo
	read -p " Press any key to continue. "
       fi
      unset ANSWER
     else
      clear	# Clear Terminal Screen
      echo
      echo " No restore information available"
      echo
      read -p " Press any key to continue. "
     fi
    unset RESTORECOUNT	# delete variable RESTORECOUNT
   ;;
  4)	# remove all files from the data directory
   clear	# Clear Terminal Screen
   FILECOUNT=$(find $DATA_PATH/ -type f | wc -l)
   if [ $FILECOUNT -gt 0 ]; then
    echo -n " Are you sure (y/n)? "	# echo option -n supresses cursor next line
    read ANSWER	# read ANSWER characters from keyboard
     if [ $ANSWER = y -o $ANSWER = Y ]; then
      echo
      echo " $FILECOUNT files to delete..."
      echo
      echo " Deleting in progress..."
      echo " Depending on number of files, the process may take awhile."
      echo " Please be patient."
      echo
      find $DATA_PATH/ -type f -print | xargs rm -f
      echo
      echo " All files deleted."
      echo
     fi
   else
     echo
     echo " Nothing to delete."
     echo
   fi
   unset ANSWER
   unset FILECOUNT
   read -p " Press any key to continue. "
   ;;
  5)	# Change password
   clear	# Clear Terminal Screen
   echo
   echo " Set password to the default one!!!"
   echo
   passwd
   echo
   echo
   read -p " Press any key to continue. "
   ;;
  7)	# Delete temporary information for restore
   clear	# Clear Terminal Screen
   FILECOUNT=$(find $LREP_PATH/~*.txt -type f | wc -l)
   if [ $FILECOUNT -gt 0 ]; then
    echo
    echo -n " Are you sure (y/n)? "	# echo option -n supresses cursor next line
    read ANSWER	# read ANSWER characters from keyboard
     if [ $ANSWER = y -o $ANSWER = Y ]; then
      echo
      echo " $FILECOUNT files to delete..."
      echo
      echo " Depending on the amount of files, the process may take awhile."
      echo " So please be patient."
      echo
      echo
      echo " Deleting in progress..."
      echo
      find $LREP_PATH/~*.txt -type f -print | xargs rm -f
      echo
      echo " All files deleted."
      echo
     fi
    unset ANSWER
   else
     clear	# Clear Terminal Screen
     echo
     echo " Nothing to delete"
     echo
   fi
   unset FILECOUNT
   read -p " Press any key to continue. "
   ;;
  *) # Any other button
   clear	# Clear Terminal Screen
   echo
   echo " Invalid command \"$ACTION\""
   echo
   sleep 1
   ;;
 esac	# End of the menu
done	# End of loop
unset ACTION	# delete of variable ACTION
trap 2	# Enable Ctrl+C
clear	# Clear Terminal Screen
exit
