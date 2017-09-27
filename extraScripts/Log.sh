Log () 
  { echo "`date '+%y%m%d-%T'` $*" | tee -a $LOG;  }

Warn () 
  { Log "$*" 1>&2 ; }

Abort () 
  { Log "ABORT: $*" 1>&2 ; exit 1; }

PROG="`basename $0`"

Log "Initiated $PROG"
Log "Looking for DB2 backup tapes from today ($DATE)"

grep "^$DATE|TPE" $TAPE_LOG | grep 'Backup successful' | tail -2 >$TMP

TAPE1="`awk -F'|' 'NR == 1 { print substr($3,1,6) }' $TMP`"

if [ "$TAPE1" = "" ] ; then
  Warn "ERROR: No successful DB2 backups to tape were found for $DATE"
  Warn "ERROR: So, no tapes can be written (appended)"
  Abort "Terminating without doing anything!"
fi

