#!/bin/sh
#archiveScript.sh
#
#Author:  Jeffery Shipman
#date:  11/3/09
#
#evaluates the directories within the proscribe selection
#if they are more recent then the newer file
#list the contents of the work directory
#tar zips the directory
#sends both to masstore
#
#masstore user name
# if [ "$MSSUSER" = "" ] ; then
#   echo "Please \"MSSUSER='your-DMSS-login-name'\" export MSSUSER"
#   exit 1
# fi

MSSUSER=jshipman
export MSSUSER

#start of script
time_start=`date +%s`

################email################
WHOM="jeffery.l.shipman@nasa.gov"
Subject="Graphics Rename Projects - Directories List"
Subject2="Graphics Rename Projects - Errors"

################directories################
baseConfig='/Graphics/scripts/ArchiveBash/'
baseList=$baseConfig'List/'
baseError=$baseConfig'Error/'
baseTemp=$baseConfig'Temp/'
baseLog=$baseConfig'Log/'
baseDirChange=$baseConfig'DirChange/'
base='/Graphics/GraphicsRepository/'
unprocessed='/Graphics/GraphicsUnprocessed/'
archivePath='/mss/ms/msb/graphics/archives'
################files################
#check if directories exist in the unprocessed area
checkDirRun=$baseTemp'noDir.txt'
#list of dir to be place incoming work
#list of dir to be searched
archiveDirFile=$baseTemp'archiveFolders.txt'
badProjects=$baseTemp'badProjectNames.txt'
gzList=$baseTemp'gzList.txt'
lsList=$baseTemp'lsList.txt'
#only always one instance to run
check=$baseConfig'checkArchive'
#list of files to be archived
archiveList=$baseList"`date +'%y-%m-%d-%T'| tr : _`.txt"
#list of find errors
changeDirName=$baseDirChange"`date +'%y-%m-%d-%T'| tr : _`.txt"
#log of script execution
logFile=$baseLog"`date +'%y-%m-%d-%T'| tr : _`.txt"
logListKeep=$baseTemp"logListKeep.txt"
logListDelete=$baseTemp"logListDelete.txt"
logList=$baseTemp"logList.txt"
logNum=5
################subroutines################
Log () 
  { echo "`date '+%y_%m_%d %T'` $*" | tee -a $logFile;  }

Warn () 
  { Log "WARN: $*" 1>&2 ; }

Abort () 
  { 
  	Log "ABORT: $*" 1>&2 ; 
  	/bin/mail -s "$Subject2" $WHOM < $logFile
  	exit 1; 
  }
  
##############Log ################
#keep only proscribe number (logNum) of logs
checkLogNum=`ls -1 $baseLog | grep -v '^\.'| wc -l`
Log "Log Check"
if [ $checkLogNum -gt $logNum ] ; then
	Log "    There are more than $logNum logs"
	ls -1 $baseLog | grep -v '^\.' > $logList
	numToDelete=$((checkLogNum-logNum)) 
	Log "    numToDelete:  $numToDelete"
	numTail=$((checkLogNum-numToDelete)) 
	Log "    numTail:  $numTail"
	head -$numToDelete $logList > $logListDelete
	tail -$logNum $logList > $logListKeep
	cat $logListDelete | while read d;
	do
		fullPathLog="$baseLog$d"
		Log "    fullPathLog:  $fullPathLog"
		rm $baseLog$d
		if [ $? -ne 0 ]; then
		  Warn "    could delete $d"
		  cat ${baseTemp}stderr >>$logFile
		  cat ${baseTemp}stderr 1>&2
		fi
	done
fi
#create log file
touch $logFile

#who am i running as
whoRunning=`whoami`
Log "Running script as $whoRunning"

########rename projects in CSS  - begin ########
Log "    rename projects in CSS "
cat $badProjects | while read f;
	do
		Log "f:   $f"
		newName="${f//:}"
		Log "newName:   $newName"
		Log "        masmv $f $newName"
 		masmv $f $newName
 		if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
			Abort "        masmv error for $f to $newName"
			cat ${baseTemp}stderr >>$logFile
			cat ${baseTemp}stderr 1>&2
		fi
	done
########rename projects in CSS  - end ########
#end of script
time_end=`date +%s`
time_elapsed=$((time_end - time_start))
Log "script executed in $time_elapsed seconds"
sec=$time_elapsed
min=$[ time_elapsed / 60 ]
hours=$[ min / 60 ]
minDisplay=$[ hours % 60 ]
secDisplay=$[ time_elapsed - min * 60 ]
if [ $hours -ne 0 ]; then
	Log "$hours hours $minDisplay minutes $secDisplay seconds"
else
	Log "$minDisplay minutes $secDisplay seconds"
fi
#if file is not of size zero => there is something to send out
if [ -s $logFile ]; then
	if cat $logFile | grep -iq 'WARN' || cat $logFile | grep -iq 'ABORT' ; then
		/bin/mail -s "$Subject2" $WHOM < $logFile $archiveList 
	else
		/bin/mail -s "$Subject" $WHOM < $logFile $archiveList 
	fi
fi

exit

