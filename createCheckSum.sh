#!/bin/sh
#archiveScript.sh
#
#Author:  Jeffery Shipman
#date:  11/3/09
#
#evaluates the Check Sum within the proscribe selection
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
Subject="Graphix Archive Create Check Sum - Check Sum List"
Subject2="Graphix Archive Create Check Sum - Errors"

################Check Sum################
baseConfig='/Graphics/scripts/ArchiveBash/'
baseList=$baseConfig'List/'
baseError=$baseConfig'Error/'
baseTemp=$baseConfig'Temp/'
baseLog=$baseConfig'Log/'
baseDirChange=$baseConfig'DirChange/'
base='/Graphics/GraphicsRepository/'
archivePath='/mss/ms/msb/graphics/archives'
################files################
#check if Check Sum exist in the unprocessed area
checkDirRun=$baseTemp'noDir.txt'
#list of dir to be place incoming work
#list of dir to be searched
archiveDirFile=$baseTemp'archiveFolders.txt'
alphaDir=$baseTemp'alphaDir.txt'
chksumListTemp=$baseTemp'chksumListTemp.txt'
chksumList=$baseTemp'chksumList.txt'
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

archives="archive1 archive2 archive3"
########get listing of dir in CSS  - begin ########
# Log "    get listing of dir in CSS"	
# Log "        masls -1 /mss/ms/msb/graphics/archives/archive1 > $alphaDir"
# masls -1 /mss/ms/msb/graphics/archives/archive1 > $alphaDir
# cat $alphaDir | while read n;
# do
# 	Log "        $n"
# done
########get listing of dir in CSS  - end  ########

########create list of work files in CSS  - begin ########
# touch $chksumList
# Log "    create check sum for work files in CSS "
# for a in $archives ; do
# 	cat $alphaDir | while read f;
# 	do
# 		Log "        masls -1 /mss/ms/msb/graphics/archives/$a/$f/work/*.gz > $chksumListTemp"
# 		masls -1 /mss/ms/msb/graphics/archives/$a/$f/work/*.gz > $chksumListTemp
# 		cat $chksumListTemp >> $chksumList
# 	done
# done
########create list of work files in CSS  - end ########

########create chksum and put in CSS  - begin ########
Log "    create chksum and put in CSS "
Log "		masget CSS file"

cd $baseTemp
if [ $? -ne 0 ]; then
		Abort "        	error cd $baseTemp"
		cat ${baseTemp}stderr >>$logFile
		cat ${baseTemp}stderr 1>&2
	fi	
	
cat $chksumList | while read f;
do
	Log "        masget $f  2>${baseTemp}stderr"
	masget $f  2>${baseTemp}stderr
	if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
		Abort "        	masget error for get on $f"
		cat ${baseTemp}stderr >>$logFile
		cat ${baseTemp}stderr 1>&2
	fi
	
	base=$(echo $f | rev | cut -d'/' -f1 | rev)
	Log "        base $base" 
	
	Log "        sum $base" 
	ckfile=${base}.ck
	sum $base > ${ckfile}
	if [ $? -ne 0 ]; then
		Abort "        	sum error $base"
		cat ${baseTemp}stderr >>$logFile
		cat ${baseTemp}stderr 1>&2
	fi	
	
	comp=$(echo $f | rev | cut -d'/' -f1 --complement | cut -d'/' -f1 --complement | rev)
	Log "        comp $comp"
	
	ckCSSPath=${comp}/ck/${base}.ck
	Log "        ckCSSPath $ckCSSPath"
	
 	Log "        put $base"  
	Log "        /usr/local/bin/masput ${ckfile} ${ckCSSPath} 2>${baseTemp}stderr"
	/usr/local/bin/masput "${ckfile}" "$ckCSSPath" 2>${baseTemp}stderr
	if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
		Abort "masput error for $base"
		cat ${baseTemp}stderr >>$logFile
		cat ${baseTemp}stderr 1>&2
	fi
	
	Log "        rm local $base"
	rm $base
	if [ $? -ne 0 ] ; then
		Abort "        	rm error $base"
		cat ${baseTemp}stderr >>$logFile
		cat ${baseTemp}stderr 1>&2
	fi
	
	Log "        rm local $ckfile"
	ckfile=${base}.ck
	rm $ckfile
	if [ $? -ne 0 ] ; then
		Abort "        	rm error $ckfile"
		cat ${baseTemp}stderr >>$logFile
		cat ${baseTemp}stderr 1>&2
	fi
	
    sed -i '1,1 d' $chksumList
	
done < $chksumList
########create check sum for work files in CSS  - end ########


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

