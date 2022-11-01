#!/bin/sh

#
# This script processes the /var/log/messages portion of a
# supportconfig messages.txt file. For each warning line,
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

function exitError() {
	echo "$1"
	[ ! -z "$tmpDir" ] && rm -rf $tmpDir
	exit 1
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

curPath=`dirname "$(realpath "$0")"`

# conf files (if not already set by calling program)
if [ -z "$SCA_HOME" ]; then
	mainConfFiles="${curPath}/../sca-L0.conf /etc/opt/sca/sca-L0.conf"
	for mainConfFile in ${mainConfFiles}; do
		if [ -r "$mainConfFile" ]; then
			found="true"
			source $mainConfFile
			break
		fi
	done
	if [ -z "$found" ]; then
		exitError "No sca-L0 conf file info; exiting..."
	fi
	extraConfFiles="${curPath}/../sca-L0+.conf /etc/opt/sca/sca-L0+.conf"
	for extraConfFile in ${extraConfFiles}; do
		if [ -r "$extraConfFile" ]; then
			source $extraConfFile
			break
		fi
	done
fi
[ $DEBUG ] && echo "*** DEBUG: $0: confFile: $confFile" >&2

logName="/var/log/messages"
if [ $DEBUG ]; then
	$SCA_BIN_PATH/messages-kwds.sh -d "$scDir" "$logName" warn
else
	$SCA_BIN_PATH/messages-kwds.sh "$scDir" "$logName" warn
fi
exit 0
