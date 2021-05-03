#!/bin/sh

#
# This script processes a supportconfig and outputs the
# system manufacturer.
#
# Inputs: 1) supportconfig directory
#
# Output: System manufacturer (as listed in basic-environment.txt)
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

basicEnvFile="$scDir/basic-environment.txt"
if [ ! -f $basicEnvFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $basicEnvFile does not exist."
        exit 1
fi

hwMod=`grep "^Hardware:" $basicEnvFile | cut -d":" -f2 | sed 's/^ *//' | sed 's/ *$//' | sed 's/ /_/g'`
if [ ! -z "$hwMod" ]; then
	echo "$hwMod"
fi
