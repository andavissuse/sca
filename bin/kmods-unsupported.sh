#!/bin/sh

#
# This script processes a supportconfig basic-health.txt file and
# outputs a list of the loaded unsupported modules.
#
# Inputs: 1) supportconfig directory
#
# Output: list of loaded unsupported modules (written to stdout)
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

basicHealthFile="$scDir/basic-health-check.txt"
if [ ! -f $basicHealthFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $basicHealthFile does not exist, exiting..." >&2
	exit 1	
fi

grep "supported=no" $basicHealthFile | while IFS= read -r line; do
	module=`echo $line | cut -d" " -f1 | cut -d"=" -f2`
	echo $module
done
exit 0
