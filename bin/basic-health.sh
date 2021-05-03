#!/bin/sh

#
# This script processes a supportconfig and outputs values
# for parameters reported in the basic-health.txt file .
#
# Inputs: 1) supportconfig directory
#
# Output: list of parameter values
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
if [ -z $basicHealthFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $basicHealthFile does not exist."
        exit 1
fi

# taint info
charTaintVal=`grep "Kernel Status -- Tainted:" $basicHealthFile | cut -d":" -f2 | sed -e 's/ //g'`
[ $DEBUG ] && "*** DEBUG: $0: charTaintVal: $charTaintVal"
if echo $charTaintVal | grep "P" > /dev/null; then
        echo "taint:P"
fi
if echo $charTaintVal | grep "N" >/dev/null; then
        echo "taint:N"
fi
if echo $charTaintVal | grep "X" >/dev/null; then
        echo "taint:X"
fi
exit 0
