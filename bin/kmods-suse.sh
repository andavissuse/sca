#!/bin/sh

#
# This script processes a supportconfig modules.txt file and
# outputs a list of the loaded SUSE modules.
#
# Inputs: 1) supportconfig directory
#
# Output: list of loaded SUSE modules (written to stdout)
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

modFile="$scDir/modules.txt"
if [ ! -f $modFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $modFile does not exist, exiting..." >&2
	exit 1	
fi

for module in `grep "^# /sbin/modinfo" $modFile | cut -d" " -f3`; do
	modLine=`grep -n "^# /sbin/modinfo $module$" $modFile | cut -d":" -f1`
	[ $DEBUG ] && echo "*** DEBUG: $0: modLine: $modLine" >&2
	tail -n +${modLine} $modFile | while IFS= read -r line && ! echo $line | grep -q "^#.*Command"; do
                if echo $line | grep "^signer:" > /dev/null; then
                        signer=`echo $line | cut -d":" -f2`
			[ $DEBUG ] && echo "*** DEBUG: $0: signer: $signer" >&2
                        if echo $signer | grep "SUSE Linux Enterprise" >/dev/null; then
                                echo "$module"
                        fi
			break
                fi
	done
done
exit 0
