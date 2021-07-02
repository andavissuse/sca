#!/bin/sh

#
# This script extracts OS info from a supportconfig.
#
# Inputs: 1) supportconfig directory
#
# Output: osId_versionId_arch
#

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] supportconfig-directory" >&2
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
if [ -z "$1" ]; then
        usage 1
elif [ ! -d "$1" ]; then
        echo "Supportconfig directory $1 does not exist." >&2
        exit 1
else
        scDir="$1"
fi

basicEnvFile="$scDir/basic-environment.txt"
if [ ! -f $basicEnvFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $modFile does not exist, exiting..." >&2
	exit 1	
fi
osId=`grep -m 1 "^ID=" "$basicEnvFile" | cut -d'=' -f2 | sed 's/\"//g'`
osVerId=`grep -m 1 "^VERSION_ID=" $basicEnvFile | cut -d'=' -f2 | sed 's/\"//g'`
osArch=`grep "GNU/Linux$" $basicEnvFile | rev | cut -d" " -f2 | rev`
os="${osId}_${osVerId}_${osArch}"
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
echo "$os"

exit 0
