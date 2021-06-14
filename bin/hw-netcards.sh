#!/bin/sh

#
# This script processes a supportconfig hardware.txt file and 
# outputs PCI IDs of installed network hardware.
#
# Inputs: 1) supportconfig directory
#
# Output: list of network hardware PCI IDs
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

# get network hardware PCI IDs from hardware.txt file
hwFile="$scDir/hardware.txt"
if [ ! -f $hwFile ]; then
	[ $DEBUG ] && echo "*** DEBUG: $0: $hwFile does not exist, exiting..." >&2
        exit 1
fi
tmpDir=`mktemp -d`
for netcardLine in `grep -n "^  Hardware Class: network$" $hwFile | cut -d":" -f1`; do
        [ $DEBUG ] && echo "*** DEBUG: $0: netcardLine: $netcardLine" >&2
        tail -n +${netcardLine} $hwFile | while IFS= read -r line && ! echo $line | grep -q "Attached to:"; do
		[ $DEBUG ] && echo "*** DEBUG: $0: line: $line" >&2
                if echo "$line" | grep -q "^  Vendor:"; then
			vendorId=`echo "$line" | grep -o "0x[0-9a-f]*"`
                        [ $DEBUG ] && echo "*** DEBUG: $0: vendorId: $vendorId" >&2
			echo -n "$vendorId:" >> $tmpDir/net-pciids.tmp
		fi
		if echo "$line" | grep -q "^  Device:"; then
			deviceId=`echo "$line" | grep -o "0x[0-9a-f]*"`
			[ $DEBUG ] && echo "*** DEBUG: $0: deviceId: $deviceId" >&2
			echo "$deviceId" >> $tmpDir/net-pciids.tmp
			break
		fi
        done
done
cat $tmpDir/net-pciids.tmp | sort -u
rm -rf $tmpDir
exit 0 
