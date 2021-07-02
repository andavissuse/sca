#!/bin/sh

#
# This script outputs kernel modules information (supported, SolidDriver, unsupported, etc.)
#
# Inputs: 1) path containing features files
#	  2) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  kmods-external, kmods-unsupported, kmods-result name-value pairs written to output file
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path [output-file]"
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
	exit 1
else
        featuresPath="$1"
fi
if [ "$2" ]; then
	outFile="$2"
fi

if [ ! -d "$featuresPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
        echo "$0: features path $featuresPath or output file $outFile  does not exist, exiting..."
        [ $outFile ] && echo "kmods-external: error" >> $outFile
        [ $outFile ] && echo "kmods-unsupported: error" >> $outFile
        [ $outFile ] && echo "kmods-result: 0" >> $outFile
        exit 1
fi

# intro
echo ">>> Checking kernel modules..."

# kmods
basicHealthFile="$featuresPath/basic-health-check.txt"
[ $DEBUG ] && echo "*** DEBUG: $0: basicHealthFile: $basicHealthFile"
if [ ! -f $basicHealthFile ]; then
	echo "        No module info available"
	[ $outFile ] && echo "kmods-external: error" >> $outFile
	[ $outFile ] && echo "kmods-unsupported: error" >> $outFile
	[ $outFile ] && echo "kmods-result: 0" >> $outFile
        exit 1
else
	taintVal=`grep "Kernel Status -- Tainted:" $basicHealthFile | cut -d":" -f2 | sed -e 's/ //g'`
	if echo $taintVal | grep -q "X"; then
		[ $DEBUG ] && echo "*** DEBUG: $0: Found taint value X" >&2
		if [ ! -s "$featuresPath/kmods-external.tmp" ]; then
			echo "        Error retrieving external module info"
			[ $outFile ] && echo "kmods-external: error" >> $outFile
			errorState="TRUE"
		else	
			modsExt=""
			while IFS= read -r mod; do
				modsExt="$modsExt $mod"
				[ $DEBUG ] && echo "*** DEBUG: $0: modsExt: $modsExt" >&2
			done < $featuresPath/kmods-external.tmp
			echo "        Externally-supported kernel modules loaded: $modsExt"
			[ $outFile ] && echo "kmods-external: $modsExt" >> $outFile
			kmodsResult="0"
		fi
	else
		echo "        No externally-supported kernel modules loaded"
		[ $outFile ] && echo "kmods-external: none" >> $outFile
		kmodsResult="1"
	fi
	if echo $taintVal | grep -q "N"; then
		[ $DEBUG ] && echo "*** DEBUG: $0: Found taint value N" >&2
		if [ ! -s "$featuresPath/kmods-unsupported.tmp" ]; then
			echo "        Error retrieving unsupported module info"
			[ $outFile ] && echo "kmods-unsupported: error" >> $outFile
			errorState="TRUE"
		else
			modsUnsupported=""
			while IFS= read -r mod; do
				modsUnsupported="$modsUnsupported $mod"
				[ $DEBUG ] && echo "*** DEBUG: $0: modsUnsupported: $modsUnsupported" >&2
			done < $featuresPath/kmods-unsupported.tmp
			echo "        Unsupported kernel modules loaded: $modsUnsupported"
			[ $outFile ] && echo "kmods-unsupported: $modsUnsupported" >> $outFile
			kmodsResult="-1"
		fi
	else
		echo "        No unsupported kernel modules loaded"
		[ $outFile ] && echo "kmods-unsupported: none" >> $outFile
	fi
fi
if [ "$errorState" = "TRUE" ]; then
	kmodsResult="0"
fi
[ $outFile ] && echo "kmods-result: $kmodsResult" >> "$outFile"
exit 0
