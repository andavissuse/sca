#!/bin/sh

#
# This script processes a supportconfig and outputs the
# system UUID.
#
# Inputs: 1) supportconfig directory
#
# Output: System UUID (as listed in sysfs.txt)
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

sysfsFile="$scDir/sysfs.txt"
if [ ! -f $sysfsFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $sysfsFile does not exist."
        exit 1
fi

sysUUID=`grep "product_uuid" $sysfsFile | grep "=" | cut -d"=" -f2 | sed 's/^ *//' | sed 's/ *$//' | sed 's/"//g'`
if [ ! -z "$sysUUID" ]; then
	echo "$sysUUID"
fi
