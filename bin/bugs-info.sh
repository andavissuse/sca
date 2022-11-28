#!/bin/sh

#
# This script outputs information about bugs.  The script requires SUSE-internal
# datasets to be present; otherwise the script will report NA.
#
# Inputs: 1) path containing features files
#	  2) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  bugs, bugs-score, bugs-result name-value pairs written to output file
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path [output-file]"
}

function exitError() {
	echo "$1"
	[ ! -z "$tmpDir" ] && rm -rf $tmpDir
	exit 1
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
        usage >&2
	exit 1
else
        featuresPath="$1"
fi
if [ "$2" ]; then
	outFile="$2"
fi

if [ ! -d "$featuresPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
        echo "$0: features path $featuresPath or output file $outFile does not exist, exiting..." >&2
        [ $outFile ] && echo "bugs: error" >> $outFile
        [ $outFile ] && echo "bugs-result: 0" >> $outFile
        exit 1
fi
[ $DEBUG ] && echo "*** DEBUG: $0: featuresPath: $featuresPath" >&2

curPath=`dirname "$(realpath "$0")"`

# conf files (if not already set by calling program)
if [ -z "$SCA_HOME" ]; then
	mainConfFiles="${curPath}/../sca.conf /etc/opt/sca/sca.conf"
	for mainConfFile in ${mainConfFiles}; do
		if [ -r "$mainConfFile" ]; then
			found="true"
			source $mainConfFile
			break
		fi
	done
	if [ -z "$found" ]; then
	    	exitError "No sca config file; exiting..."
	fi
#	extraConfFiles="${curPath}/../sca+.conf /etc/opt/sca/sca+.conf"
#	for extraConfFile in ${extraConfFiles}; do
#		if [ -r "$extraConfFile" ]; then
#			source $extraConfFile
#			break
#		fi
#	done
fi
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
bugsDataTypes="$SCA_BUGS_DATATYPES"
bugsRadius="$SCA_BUGS_RADIUS"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, datasetsPath: $datasetsPath, bugsDataTypes: $bugsDataTypes, bugsRadius: $bugsRadius" >&2

# start
echo ">>> Checking bugs..."
bugsDataset="$datasetsPath/bugs.dat"
if [ ! -r "$bugsDataset" ]; then
	echo "        No bugs.dat dataset to compare against"
	[ $outFile ] && echo "bugs: NA" >> $outFile
	[ $outFile ] && echo "bugs-result: 0" >> $outFile
	exit 0
fi

dataTypes=""
numDataTypes=0
for dataType in $bugsDataTypes; do
	if [ -s "$featuresPath/$dataType.tmp" ] && [ -r "$datasetsPath/$dataType.pkl" ]; then
		dataTypes="$dataTypes $dataType"
		numDataTypes=$((numDataTypes + 1))
	fi
done
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypes: $dataTypes" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: numDataTypes: $numDataTypes" >&2
if [ -z "$dataTypes" ]; then
	echo "        No warning/error messages to compare against bugs"
	[ $outFile ] && echo "bugs: none" >> $outFile
	[ $outFile ] && echo "bugs-result: 1" >> $outFile
	exit 0
fi

# build datasets argument to pass to knn_combined
knnCombinedArgs="$bugsDataset"
for dataType in $dataTypes; do
#	metricVar='$'`echo SCA_BUGS_"${dataType^^}"_METRIC | sed "s/-/_/g"`
#	eval metric=$metricVar
	metric="jaccard"
	radius="$bugsRadius"
#	weightVar='$'`echo SCA_BUGS_"${dataType^^}"_WEIGHT | sed "s/-/_/g"`
#	eval weight=$weightVar
	weight="1"
	[ $DEBUG ] && echo "*** DEBUG: $0: metricVar: $metricVar, radiusVar: $radiusVar, weightVar: $weightVar" >&2
	datasetArg="$datasetsPath/$dataType.pkl $featuresPath/$dataType.tmp $metric $radius $weight"
	[ $DEBUG ] && echo "*** DEBUG: $0: datasetArg: $datasetArg" >&2
	knnCombinedArgs="$knnCombinedArgs $datasetArg"
done
knnCombinedArgs=`echo $knnCombinedArgs | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: knnCombinedArgs: $knnCombinedArgs" >&2
if [ -z "$knnCombinedArgs" ]; then
	echo "        Error retrieving bugs"
	[ $outFile ] && echo "bugs: error" >> $outFile
	[ $outFile ] && echo "bugs-result: 0" >> $outFile
	exit 1
fi

if [ "$DEBUG" ]; then
	idsScores=`python3 $binPath/knn_combined.py -d $knnCombinedArgs`
else
	idsScores=`python3 $binPath/knn_combined.py $knnCombinedArgs 2>/dev/null`
fi
[ $DEBUG ] && echo "*** DEBUG: $0: idsScores: $idsScores" >&2

declare -a idsScoresArray=(`echo $idsScores | tr "[()',]" " "`)
[ $DEBUG ] && echo "*** DEBUG: $0: idsScoresArray: $idsScoresArray" >&2
if [ -z "$idsScoresArray" ]; then
	echo "        Bugs: none"
	[ $outFile ] && echo "bugs: none" >> $outFile
	[ $outFile ] && echo "bugs-result: 1" >> $outFile
else
	i=0
	bugs=""
	while [ ! -z "${idsScoresArray[i]}" ]; do
		bugs="$bugs ${idsScoresArray[i]}"
		scores="$scores ${idsScoresArray[(($i+1))]}"
		i=$((i + 2))
	done
#	[ $outFile ] && echo "bugs: $bugs" >> "$outFile"
	bugsToPrint=""
	normalizedScores=""
	i=0
	for bug in $bugs; do
		i=$((i + 1))
		score=`echo $scores | cut -d' ' -f$i`
		normalizedScore=`echo "scale=2 ; $score / $numDataTypes" | bc`
                if (( $(echo "$normalizedScore <= .50" |bc -l) )); then
                        break
                fi
		bugsToPrint="$bugsToPrint $bug"
		normalizedScores="$normalizedScores $normalizedScore"
	done
	[ $DEBUG ] && echo "*** DEBUG: $0: bugsToPrint: $bugsToPrint" >&2
	[ $DEBUG ] && echo "*** DEBUG: $0: normalizedScores: $normalizedScores" >&2
	if [ -z "$bugsToPrint" ]; then
	        echo "        Bugs: none"
		[ $outFile ] && echo "bugs: none" >> "$outFile"
		[ $outFile ] && echo "bugs-result: 1" >> "$outFile"
	else
		[ $outFile ] && echo "bugs: $bugsToPrint" >> "$outFile"
		i=0
		for bugToPrint in $bugsToPrint; do
			i=$((i + 1))
			normalizedScore=`echo $normalizedScores | cut -d' ' -f$i`
			echo "        Bug: $bugToPrint, Score: $normalizedScore"
			[ $outFile ] && echo "bugs-score-$bugToPrint: $normalizedScore" >> "$outFile"
		done
		[ $outFile ] && echo "bugs-result: -1" >> "$outFile"
	fi
fi

exit 0
