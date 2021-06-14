#!/bin/sh

#
# This script processes a supportconfig messages.txt file.
# Based on the arguments passed, it will search the file
# for the requested log, find the error or warning lines,
# then output a list of keywords that appear in those lines.
# Keywords are simply "words" with 4 or more characters from
# [A-Z], [a-z], ".", "-", "_".
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

# get error/warning lines from the sub log
[ $DEBUG ] && echo "*** DEBUG: $0: getting error/warning lines from sub log..." >&2
cat $msgFile | sed -n "${startLineNum},${endLineNum}p" > $tmpDir/sub-log.tmp
grep -i "$msgType" "$tmpDir"/sub-log.tmp > "$tmpDir"/msgs.tmp

# get all words that are 4 characters or more
[ $DEBUG ] && echo "*** DEBUG: $0: getting words with 4 or more characters..." >$2
grep -o " [a-zA-Z]\{4,\} " "$tmpDir"/msgs.tmp | grep -o "\S*[g-z]\S*" | tr '[:upper:]' '[:lower:]' | sort -u > "$tmpDir"/words.tmp
# ignore prepositions and other common words
[ $DEBUG ] && echo "*** DEBUG: $0: removing prepositions and other common words..." >&2
grep -v -E "above|about|again|already|also|another|around|because|before|belong|between|cannot|could|does|doing|during|error|from|must|should|such|their|these|this|until|warn|warning|when|which|while|will|with|your" "$tmpDir"/words.tmp > "$tmpDir"/kwds.tmp
if [ ! -f $tmpDir/kwds.tmp ]; then
	rm -rf $tmpDir
	exit 1
fi
cat $tmpDir/kwds.tmp
rm -rf $tmpDir
exit 0
