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
Subject="Graphix Archive - Directories List"
Subject2="Graphix Archive - Errors"

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
archiveDirFileAZ=$baseConfig'archiveFoldersAZ.txt'
#list of dir to be searched
archiveDirFile=$baseConfig'archiveFolders.txt'
archiveDirFile2=$baseConfig'archiveFolders2.txt'
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

cd $unprocessed
if [ $? -ne 0 ] ; then
  Abort "Cannot chdir to $unprocessed"
fi

Log "check directory for directories"
find $unprocessed -maxdepth 1 -type d -print > $checkDirRun
noline="`wc -l $checkDirRun | awk '{print $1}'`"

numLine=`expr $noline - 1`
if [ "$numLine" == 0 ];then
	Log "No Directories to Process"
	/bin/mail -s "$Subject" $WHOM < $logFile
	exit
else
	Log "    $numLine Directories to Process"
fi
Log "    number of dir:  $numLine"

#if file does not exist =>  used to avoid double running the script
if [ -e $check ]; then
	Abort "double run script check file exists $check"
fi

#create check file
touch $check
	  
#create archiveList file
touch $archiveList

Log "touch files created"

#if script dies on hang up, interrupt, quit, or terminate rm check file
trap "rm $check; rm $checkDirRun" 0 1 2 15

Log "trap"

#cat contents and iterate through
#produces list of directories to check for new directories to archive
	
#affirm drop off point is 770
sudo -i /bin/chmod 770 "$unprocessed"
if [ $? -ne 0 ]; then
	Abort "chown 770 $unprocessed"
fi	

Log "create list of files to distribute in archive from unprocessed area"
ls $unprocessed > $archiveDirFile
Log "    ls $unprocessed > $archiveDirFile"	
#remove all lines starting with a period
cat $archiveDirFile | grep -v "^\." > $archiveDirFile2
Log "    cat $archiveDirFile | grep -v '^\.' > $archiveDirFile2"
sort $archiveDirFile2 > $archiveList
Log "    $archiveDirFile2 > $archiveList"
Log "    find of selected directories completed" 

#copy list of directories to dms
cat $archiveList | while read i; 
do
	#don't take directories starting with .
	Log "processing $i"

	#take directory names with spaces and remove them
	#convert | to #
	j=`echo $i | sed 's/ //g' | tr A-Z a-z | sed 's/|/#/g' `
	Log "j: $j"
	firstLetter=`echo $j | cut -c1 | tr a-z A-Z`
	Log "firstLetter: $firstLetter"
	j=`echo $j | cut -c2-`
	Log "j: $j"
	j="$firstLetter$j"
	
	if [ ! -d $base$firstLetter ]; then
		mkdir $base$firstLetter
	fi
	if [ $? -ne 0 ]; then
		Abort "FAILED to make directory:  $base$firstLetter"
	fi
		
	#if the names do not match then there are spaces
	#rename the directory
	if [ "$unprocessed$i" != "$unprocessed$j" ]; then
		#write list of new directores to file
		echo "$j" >> $changeDirName
		
		#rename directories
		sudo -i mv "$unprocessed$i" "$unprocessed$j"
		if [ $? -ne 0 ]; then
			Abort "mv $unprocessed$i $unprocessed$j error - could not remove spaces"
		fi
	fi
	
	########take directories in unprocess that exist in the repository add _C - begin ########
	Log "take directories in unprocess that exist in the repository add _C"
	oldDir="$unprocessed$j"	
	reposDir=`echo $j | cut -c1 | tr a-z A-Z`
	Log "    old dir $oldDir"
	Log "    reposidtory dir $reposDir"
	Log "    fullpath ${base}${reposDir}/${j}"
	changeName=0
	while [ -d "$base$reposDir/$j" ]; do
		j="${j}_C"
		Log "    j  $j"
		Log "    fullpath ${base}${reposDir}/${j}"
		changeName=1
	done
	
	#check if new directory is unprocess and alter
	if [ $changeName -eq 1 ]; then
		while [ -d "$unprocessed$j" ]; do
			j="${j}_C"
			Log "    j  $j"
			Log "    fullpath $unprocessed$j"
		done
	fi
	
	if [ $oldDir != "$unprocessed$j" ]; then
		#rename directories
		sudo -i mv "$oldDir" "$unprocessed$j"
		if [ $? -ne 0 ]; then
			Abort "mv $oldDir $unprocessed$j error - could not rename directory"
		fi
	fi	
	########take directories in unprocess that exist in the repository add _C - end  ########
	
	
	########change ownership to admin - begin ########
	Log "change ownership to admin"
	Log "    first chown"
	Log "    sudo -i /bin/chown -R msbadmin ${unprocessed}${j}"
	sudo -i /bin/chown -R msbadmin "$unprocessed$j"
	
	if [ $? -ne 0 ]; then
		Abort "msbadmin could not take ownership of ${unprocessed}${j}"
	fi
	########change ownership to admin - end######## 
	
	
	########create new directory name and mv catch bad characters - begin ########
	
	holdDir="`echo ${j} | sed 's/[^A-Za-z0-9|]+//g'`"
	Log "create new directory name and mv catch bad characters"
	Log "    unprocessed  $unprocessed"
	Log "    holdDir  $holdDir"
	Log "    unprocessedj  $unprocessed$j"
	Log "    unprocessedholdDir  $unprocessed$holdDir"
	
	if [ "$unprocessed$j" != "$unprocessed$holdDir" ]; then
		#move directory to temp
		#mv "$unprocessed$j" "$baseTemp$holdDir"
		#if [ $? -ne 0 ]; then
		#	Abort "cp ${unprocessed}${j} ${baseTemp}${holdDir} failed"
		#fi
		#delete original directory
		#rm -rf "$unprocessed$j"
		#if [ $? -ne 0 ]; then
		#	Abort "rm -rf ${unprocessed}${j} failed"
		#fi
		#move temp directory back
		#mv "$baseTemp$holdDir" "$unprocessed$holdDir"
		#if [ $? -ne 0 ]; then
		#	Abort "mv ${baseTemp}${holdDir} ${unprocessed}${holdDir} failed"
		#fi
		sudo -i mv "$unprocessed$j" "$unprocessed$holdDir"
		j="$holdDir"
		#^[a-zA-z]+   #one or more alpha characters - customer name
		#[|\s_]*      #zero or more pipes, whites space or underscores - dividers
		#[0-9-]+      #one or more numbers - job id
		#[|\s_]*      #zero or more pipes, whites space or underscores - dividers
		#[a-zA-z]+/)  #one or more alpha characters - artist name
		

		Log "    second chown with remane"
		Log "    /bin/chown -R msbadmin ${unprocessed}${j}"		
		sudo -i /bin/chown -R msbadmin "$unprocessed$j"
		if [ $? -ne 0 ]; then
			Abort "msbadmin could not take ownership of ${unprocessed}${j}"
		fi
	fi
	########create new directory name and mv catch bad characters - end ########
			
	
	###########change group ownership to graphics - begin ########
	Log "change group ownership to graphics"
	Log "    sudo -i /bin/chgrp -R graphicsrw ${unprocessed}${j}"	
	sudo -i /bin/chgrp -R graphicsrw "$unprocessed$j"
	if [ $? -ne 0 ]; then
		Abort "chgrp -R graphicsrw error:  _${unprocessed}${j}_"
	fi
	###########change group ownership to graphics - end ########
	
	###########change privilege settings to 750 - begin ########
	Log "change privilege settings to 750"
	Log "    sudo -i /bin/chmod -R 750 ${unprocessed}${j}"	
	sudo -i /bin/chmod -R 750 "$unprocessed$j"
	if [ $? -ne 0 ]; then
		Abort "chmod -R 750 error:  _${unprocessed}${j}_"
	fi
	###########change privilege settings to 750 - end ########
	
	################     DMS CODE  - begin ##########################
	Log "DMS Code"
	#take first letter of directory and return capitalized
	dmss_dir=`echo $j | cut -c1 | tr a-z A-Z`
	dmss_dirTest=`echo $dmss_dir | egrep '^\.'`
	archives="archive1 archive2 archive3"
	
	if [ "$dmss_dirTest" != "." ]; then
		Log "    dmss_dir:   $dmss_dir"
		local_dir=$j		
		dmss_tar="`echo $j | sed 's/|/#/g'`.tar.gz"
		dmss_ls="`echo $j | sed 's/|/#/g'`.ls"
		Log "    dmss_tar:   $dmss_tar"
		Log "    dmss_ls:   $dmss_ls"
		
		################     create one letter directories if they don't exist - begin ##########################
		for a in $archives ; do
			Log "    masmkdir of $dmss_dir archive $a"	
			Log "        mkdir in masstore for archive1, create if it does not exist"
			Log "        /usr/local/rears/bin/masmkdir -p $archivePath/$a/$dmss_dir 2>${baseTemp}stderr"
			/usr/local/rears/bin/masmkdir -p "$archivePath/$a/$dmss_dir" 2>${baseTemp}stderr
			if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
				Abort "masmkdir error for $a for $dmss_dir"
				cat ${baseTemp}stderr >>$logFile
				cat ${baseTemp}stderr 1>&2
			fi
		done
		################     create one letter directories if they don't exist - end ##########################
			
		################     place archive in masstore - end ##########################
		for a in $archives ; do

			###################### put tar - begin ###################################
			##place archive in masstore for $a
			Log "    place archive in CSS for $a"
			Log "        tar -cvf - $local_dir 2>${baseTemp}$dmss_ls | gzip -1 |/usr/local/rears/bin/masput - $archivePath/$a/$dmss_dir/work/$dmss_tar 2>${baseTemp}stderr"
			tar -cvf - "$local_dir" 2>${baseTemp}$dmss_ls | gzip -1 |/usr/local/rears/bin/masput - "$archivePath/$a/$dmss_dir/work/$dmss_tar" 2>${baseTemp}stderr		
			if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
				Warn "tar error:  _$local_dir_ for $a"
				cat ${baseTemp}stderr >>$logFile
				cat ${baseTemp}stderr 1>&2
			###################### put tar - end ###################################
			else	
				###################### put ls - begin ###################################
				egrep '^tar: ' ${baseTemp}$dmss_ls
				if [ $? -eq 0 ] ; then
					Abort "tar of $localdir FAILED for $a"
				fi
	
				Log "    tar and put of of $dmss_ls for $a"
				Log "        /usr/local/bin/masput ${baseTemp}$dmss_ls $archivePath/$a/$dmss_dir/list/$dmss_ls 2>${baseTemp}stderr"
				#place contents list of archive in CSS
				/usr/local/bin/masput "${baseTemp}$dmss_ls" "$archivePath/$a/$dmss_dir/list/$dmss_ls" 2>${baseTemp}stderr
				if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
					Abort "masput ls error for $a"
					cat ${baseTemp}stderr >>$logFile
					cat ${baseTemp}stderr 1>&2
				fi
				###################### put ls - end ###################################
				
				###################### put checksum - begin ###################################
				tar -cvf $local_dir ${baseTemp}$dmss_tar
				curDir=pwd
				cd ${baseTemp}
				Log "   checksum
				Log "      sum $dmss_tar" 
				ckfile=${dmss_tar}.ck
				sum $dmss_tar > ${ckfile}
				if [ $? -ne 0 ]; then
					Abort "        	sum error $dmss_tar"
					cat ${baseTemp}stderr >>$logFile
					cat ${baseTemp}stderr 1>&2
				fi	
				Log "      Put checksum $ckfile
				
				ckCSSPath= $archivePath/$a/$dmss_dir/ck/${ckfile}
				Log "         ckCSSPath $ckCSSPath"
				
				Log "         put $ckfile"  
				Log "         /usr/local/bin/masput ${ckfile} ${ckCSSPath} 2>${baseTemp}stderr"
				/usr/local/bin/masput "${ckfile}" "$ckCSSPath" 2>${baseTemp}stderr
				if [ $? -ne 0 -o -s ${baseTemp}stderr ]; then
					Abort "masput error for $ckfile"
					cat ${baseTemp}stderr >>$logFile
					cat ${baseTemp}stderr 1>&2
				fi
				###################### put checksum - begin ###################################
				
			fi  
		done
		################     place archive in masstore - end ##########################
		
		################     move directory to repository  - begin ##########################
		Log "move directory to repository"
		Log "    sudo -i mv $unprocessed$local_dir  $base$dmss_dir/$local_dir"
		sudo -i mv "$unprocessed$local_dir"  "$base$dmss_dir/$local_dir"
		if [ $? -ne 0 ]; then
			Warn "mv $unprocessed$local_dir  $base$dmss_dir/$local_dir failed for repository move"
		fi
		################ move directory to repository  - end  ##########################

		
	fi
	################     DMS CODE  - end ##########################

done

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

