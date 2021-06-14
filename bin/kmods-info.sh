#!/bin/sh

#
# This script outputs kernel modules information (supported, SolidDriver, unsupported, etc.)
#
# Inputs: 1) path containing features files
#	  2) short-form output file (optional)
#
# Output: Info messages written to stdout (and output file if specified)
#
# Return Value:  1 if only supported kernel modules loaded
#		 0 if only supported and "supported: external" (SolidDriver) kernel modules loaded
#		-1 if unsupported kernel modules loaded 
#		 2 for usage
#		-2 for error
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path [output-file]"
	exit 2
}

function exitError() {
	echo "$1"
        exit -2
}

# arguments
while getopts 'hd' OPTION; do
        case $OPTION in
                h)
                        usage
                        exit 0
                        ;;
                d)
                        DEBUG=1
                        ;;
        esac
done
shift $((OPTIND - 1))
if [ ! "$1" ]; then
        usage
else
        featuresPath="$1"
fi
if [ "$2" ]; then
	outFile="$2"
fi

if [ ! -z "$4" ]; then
	outFile="$4"
fi
if [ ! -d "$featuresPath" ]; then
	exitError "$featuresPath does not exist, exiting..."
fi
if [ ! -f "$outFile" ]; then
	exitError "$outFile does not exist, exiting..."
fi

echo ">>> Checking kernel modules..."
basicHealthFile="$featuresPath/basic-health-check.txt"
if [ ! -f $basicHealthFile ]; then
        [ $DEBUG ] && echo "*** DEBUG: $0: $basicHealthFile does not exist" >&2
	echo "        No module info available"
	[ $outFile ] && echo "kmods-external: no-info"
	[ $outFile ] && echo "kmods-supported: no-info"
        exit 0
else
	taintVal=`grep "Kernel Status -- Tainted:" $basicHealthFile | cut -d":" -f2 | sed -e 's/ //g'`
	if echo $taintVal | grep -q "X"; then
		[ $DEBUG ] && echo "*** DEBUG: $0: Found taint value X" >&2
		modsExt=""
		while IFS= read -r mod; do
			modsExt="$modsExt $mod"
			[ $DEBUG ] && echo "*** DEBUG: $0: modsExt: $modsExt" >&2
		done < $featuresPath/kmods-external.tmp
		echo "        Externally-supported kernel modules loaded: $modsExt"
		[ $outFile ] && echo "kmods-externally-supported: $modsExt" >> $outFile
	else
		echo "        No externally-supported kernel modules loaded"
		[ $outFile ] && echo "kmods-externally-supported: none" >> $outFile
		kmodsResult=1
	fi
	if echo $taintVal | grep -q "N"; then
		modsUnsupported=""
		while IFS= read -r mod; do
			modsUnsupported="$modsUnsupported $mod"
			[ $DEBUG ] && echo "*** DEBUG: $0: modsUnsupported: $modsUnsupported" >&2
		done < $featuresPath/kmods-unsupported.tmp
		echo "        Unsupported kernel modules loaded: $modsUnsupported"
		[ $outFile ] && echo "kmods-unsupported: $modsUnsupported" >> $outFile
		kmodsResult=-1
	else
		echo "        No unsupported kernel modules loaded"
		[ $outFile ] && echo "kmods-unsupported: none" >> $outFile
	fi
fi

[ $outFile ] && echo "kmods-result: $kmodsResult" >> "$outFile"
exit 0
