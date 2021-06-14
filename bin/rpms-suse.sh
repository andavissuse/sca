#!/bin/sh

#
# This script processes a supportconfig rpm.txt file and
# outputs a list of installed SUSE rpms.
#
# Inputs: 1) supportconfig directory
#
# Output: list of installed rpms (written to stdout)
#

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] supportconfig-directory"
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
if [ ! "$1" ]; then
        usage 1
elif [ ! -d "$1" ]; then
        echo "Supportconfig directory $1 does not exist."
        exit 1
else
        scDir="$1"
fi

rpmFile="$scDir/rpm.txt"
if [ ! -f $rpmFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $rpmFile does not exist, exiting..." >&2
	exit 1
fi

rpmListSectionLine=`cat $rpmFile | grep -n "^# rpm -qa --queryformat \"%-35{NAME}" | cut -d":" -f1`
lineNo=0
while IFS= read -r line; do
	[ $DEBUG ] && echo "*** DEBUG: $0: line: $line" >&2
	if [ "$lineNo" -gt "$rpmListSectionLine" ]; then
		rpmName=`echo $line | cut -d" " -f1`
		[ $DEBUG ] && echo "*** DEBUG: $0: rpmName: $rpmName" >&2
		rpmDist=`echo $line | cut -d" " -f2 | sed -e 's/ /_/g'`
		[ $DEBUG ] && echo "*** DEBUG: $0: rpmDist: $rpmDist" >&2
		if [ -z $rpmName ]; then
			break
		fi
		if echo $rpmDist | grep "^SUSE" >/dev/null; then
			echo "$rpmName"
		else
			continue"
		fi
	fi
	lineNo=$((lineNo+1))
done < $rpmFile
exit 0
