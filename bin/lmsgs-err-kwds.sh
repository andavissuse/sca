#!/bin/sh

#
# This script processes the /var/log/localmessages portion of a
# supportconfig messages.txt file. For each error line,
# the script outputs keywords.
#
# Inputs: 1) supportconfig directory
#
# Output: list of unique keywords (written to stdout)
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

# conf file
curPath=`dirname "$(realpath "$0")"`
confFile="/etc/sca-L0.conf"
if [ ! -r "$confFile" ]; then
        confFile="/usr/etc/sca-L0.conf"
        if [ ! -r "$confFile" ]; then
                confFile="$curPath/../sca-L0.conf"
                if [ ! -r "$confFile" ]; then
                        exitError "No sca-L0 conf file info; exiting..."
                fi
        fi
fi
source $confFile
[ $DEBUG ] && echo "*** DEBUG: $0: confFile: $confFile" >&2

logName="/var/log/localmessages"
if [ $DEBUG ]; then
	$SCA_BIN_PATH/messages-kwds.sh -d $scDir $logName error
else
	$SCA_BIN_PATH/messages-kwds.sh $scDir $logName error
fi
exit 0
