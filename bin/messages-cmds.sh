#!/bin/sh

#
# This script processes a supportconfig messages.txt file.
# Based on the arguments passed, it will search the file
# for the requested log, find the error or warning lines,
# then output a list of the commands that generated the
# errors or warnings.
#
# Inputs: 1) supportconfig directory
#	  2) log filename
#	  3) message type (warning|error)
#
# Output: list of unique commands (written to stdout)
#

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] supportconfig-directory log-filename message-type"
        exit $1
}

# arguments
if [ "$1" = "--help" ]; then
        usage 0
fi
while getopts 'hd' OPTION; do
        case $OPTION in
                h)
                        usage 0
                        ;;
                d)
                        DEBUG=1
                        ;;
        esac
done
shift $((OPTIND - 1))
if [ ! "$3" ]; then
        usage 1
elif [ ! -d "$1" ]; then
        echo "Supportconfig directory $1 does not exist."
        exit 1
else
        scDir="$1"
fi
logName="$2"
msgType="$3"

msgFile="$scDir/messages.txt"
if [ ! -f $msgFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $msgFile does not exist, exiting..." >&2
	exit 1	
fi

tmpDir=`mktemp -d`
grep -na "^# /" $msgFile > $tmpDir/sub-log-info.tmp
logLineNum=`grep "# $logName" $tmpDir/sub-log-info.tmp | cut -d":" -f1`
[ $DEBUG ] && echo "*** DEBUG: $0: logLineNum: $logLineNum" >&2
if ! echo $logLineNum | cut -d" " -f1 | grep -q "[0-9]"; then
        [ $DEBUG ] && echo "*** DEBUG: $0: No $logName entry in $msgFile" >&2
        rm -rf $tmpDir
        exit 1
fi
startLineNum=$(( logLineNum + 1 ))
[ $DEBUG ] && echo "*** DEBUG: $0: startLineNum: $startLineNum" >&2
nextLogLineNum=`grep "# $logName" $tmpDir/sub-log-info.tmp -A 1 | tail -1 | cut -d":" -f1`
[ $DEBUG ] && echo "*** DEBUG: $0: nextLogLineNum: $nextLogLineNum" >&2
if (( nextLogLineNum == logLineNum )); then
        endLineNum=`wc -l $msgFile | cut -d" " -f1`
else
        endLineNum=$(( nextLogLineNum - 2 ))
fi
[ $DEBUG ] && echo "*** DEBUG: $0: endLineNum: $endLineNum" >&2

cat $msgFile | sed -n "${startLineNum},${endLineNum}p" > $tmpDir/sub-log.tmp
grep -i "$msgType" "$tmpDir"/sub-log.tmp | cut -d" " -f1-7 > "$tmpDir"/msgs.tmp
cat "$tmpDir"/msgs.tmp | grep "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] " | cut -d" " -f6 | sort -u > "$tmpDir"/cmdfields.tmp
cat "$tmpDir"/msgs.tmp | grep "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T" > "$tmpDir"/msgs-f1NumT.tmp
cat "$tmpDir"/msgs-f1NumT.tmp | cut -d" " -f3,7 | sort -u > "$tmpDir"/msgs-f1NumT-f37.tmp 
cat "$tmpDir"/msgs-f1NumT-f37.tmp | grep -E "^Jan|^Feb|^Mar|^Apr|^May|^Jun|^Jul|^Aug|^Sep|^Oct|^Nov|^Dec" | cut -d" " -f2 | sort -u >> "$tmpDir"/cmdfields.tmp
cat "$tmpDir"/msgs-f1NumT-f37.tmp | grep -v -E "^Jan|^Feb|^Mar|^Apr|^May|^Jun|^Jul|^Aug|^Sep|^Oct|^Nov|^Dec" | cut -d" " -f1 | sort -u >> "$tmpDir"/cmdfields.tmp
cat "$tmpDir"/msgs.tmp | grep -E "^Jan|^Feb|^Mar|^Apr|^May|^Jun|^Jul|^Aug|^Sep|^Oct|^Nov|^Dec" | cut -d" " -f5 | sort -u >> "$tmpDir"/cmdfields.tmp
sort -o "$tmpDir"/cmdfields.tmp "$tmpDir"/cmdfields.tmp
if [ ! -s $tmpDir/cmdfields.tmp ]; then
        [ $DEBUG ] && echo "*** DEBUG: $0: No $logName $msgType lines found" >&2
        rm -rf $tmpDir
        exit 0
fi

# get the command field
cat "$tmpDir/cmdfields.tmp" | while read cmd; do
	if echo "$cmd" | grep -q -E "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"; then
                continue
        fi
	# trim the command
	cmd=`echo "$cmd" | sed "s/:.*$//" |
		           sed "s/\[.*\]//g" |
		           sed "s/(.*)//g" |
			   sed "s/\[//g" |
			   sed "s/\]//g" |
			   sed "s/#//g" |
			   sed "s/-[0-9]*$//" |
			   sed "s/_[0-9]*$//" |
			   sed "s/\.[0-9]*$//" |
			   sed "s/^\.//"`
	if [ -z "$cmd" ]; then
		continue
	fi
	cmd=`basename $cmd 2>/dev/null`
	if [ -z "$cmd" ]; then
		continue
	fi
	cmd=`echo "$cmd" | sed "s/[0-9]*$//"`
	if ! echo "$cmd" | grep -q "[a-zA-Z]"; then
                continue
        fi
	[ $DEBUG ] && echo "*** DEBUG: $0: cmd: $cmd" >&2

	echo "$cmd" >> "$tmpDir"/cmds.tmp
done
if [ ! -f $tmpDir/cmds.tmp ]; then
	rm -rf $tmpDir
	exit 1
fi
cat $tmpDir/cmds.tmp | sort -u
rm -rf $tmpDir
exit 0
