#!/bin/sh
#
#create name for directory based on the directories one level down
#considers only numbers from directory name of length 9 once
#hypens and underscores are removed
#
#masstore user name
if [ "$MSSUSER" = "" ] ; then
  echo "Please \"MSSUSER='your-DMSS-login-name'\" export MSSUSER"
  exit 1
fi

################email################
WHOM="j.l.shipman@larc.nasa.gov"
Subject="Graphix Archive - Directories List"
Subjec2="Graphix Archive - Errors"

################directories################
baseConfig='/Users/admin/Desktop/Archive/'
baseList=$baseConfig'List/'
baseError=$baseConfig'Error/'
baseTemp=$baseConfig'Temp/'
baseDirChange=$baseConfig'DirChange/'
base='/Volumes/Archive2/'

################files################
#list of dir to be searched
archiveDirFile=$baseConfig'archiveFolders.txt'
#only always one instance to run
check=$baseConfig'checkArchive'
#file to check against for new archivables
timeCheck=$baseConfig'archiveTime'
#list of files to be archived
archiveList=$baseList"NormalArchive`date +'%y-%m-%d-%T'| tr : _`.txt"
#list of find errors
errorArchive=$baseError"ErrorArchive-`date +'%y-%m-%d-%T'| tr : _`.txt"
#list of dir names changed due to spaces in name
changeDirName=$baseDirChange"DirChange-`date +'%y-%m-%d-%T'| tr : _`.txt"
#list of dirs modified
modifidiedList=$baseTemp'modified.txt'
modifidiedList2=$baseTemp'modified2.txt'
#if file does not exist =>  used to avoid double running the script
#if [ ! -e $check ]; then
	#create check file
#	touch $check

	if [ -e $modifidiedList2 ]; then
		#create check file
		rm $modifidiedList2
	fi
	
	touch $modifidiedList2
	
	if [ -e $modifidiedList ]; then
		#create check file
		rm $modifidiedList
	fi
	
	touch $modifidiedList
	
	#create archiveList file
	touch $archiveList

	#create error file
	touch $errorArchive
	
	#if script dies on hang up, interrupt, quit, or terminate rm check file
	#trap "rm $check" 0 1 2 15
	
	#cat contents and iterate through
	#produces list of directories to check for new directories to archive
	curDir=`pwd`
	
	#echo "current directory: $curDir"
	#echo ""
	cat $archiveDirFile | while read i;
	do
		#echo $i
		full=$base$i
		#avoid blank entries for find command
		if echo $i | grep -iq '^[0-9a-zA-Z]'; then		
			cd $base
			#check one level down for directories that meet time criteria
			find $i -type d -name '*' -maxdepth 1 -print >> $archiveList
			
			#check one level down for directories that meet time criteria
			#time criteria is created after timeCheck file
			#find $i -type d -name '*' -newer $timeCheck -maxdepth 1 -print >> $archiveList
			
			#check find for success
			if [ $? -ne 0 ]; then
				echo "find error:  _$i_"  >> $errorArchive
			fi		
		fi
	done
	
	#copy list of directories to dms
 	cat $archiveList | while read i; 
 	do
		#sed 's/[-_]//g'  			replace - and _ with nothing
		#awk -F"\|" '{print $2 }'   	change separator to pipe; print out second field
		#sed 's/[[:alpha:]]//g'    	remove all alpha characters
		#grep [[:digit:]]			report only digits
		var=`echo $i |sed 's/[-_]//g' | awk -F"\|" '{print $2 }' | sed 's/[[:alpha:]]//g' | grep [[:digit:]]`
 		if [ ${#var} == 9 ]; then
 			echo $var >> $modifidiedList
 		fi
	done

	sort $modifidiedList > $modifidiedList2
	
	headNo=`head -n 1 $modifidiedList2`
	tailNo=`tail -n 1 $modifidiedList2`
	
	#echo $headNo
	#echo $tailNo
	newdir=$headNo"_"$tailNo
	
	echo $newdir
#fi

exit

