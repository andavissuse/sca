#!/bin/sh

#
# This script processes the /usr/bin/journalctl portion of a
# supportconfig messages.txt file. For each warning line,
# the script outputs the command that generated the warning.
#
# Inputs: 1) supportconfig directory
#
# Output: list of unique commands (written to stdout)
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

# config file
curPath=`dirname "$(realpath "$0")"`
confFile="/usr/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="$curPath/../sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
if [ -z "$SCA_HOME" ]; then
        exitError "No sca-L0.conf file info; exiting..."
fi

logName="/usr/bin/journalctl"
if [ $DEBUG ]; then
	$SCA_BIN_PATH/messages-cmds.sh -d $scDir $logName warn
else
	$SCA_BIN_PATH/messages-cmds.sh $scDir $logName warn
fi
exit 0
