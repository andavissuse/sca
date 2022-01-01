#!/bin/sh

#
# This script outputs information about bugs.
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

# conf files
curPath=`dirname "$(realpath "$0")"`
mainConfFile="/usr/etc/sca-L0.conf"
extraConfFiles=`find /usr/etc -name "sca-L0?.conf"`
if [ ! -r "$mainConfFile" ]; then
        mainConfFile="/etc/sca-L0.conf"
        extraConfFiles=`find /etc -name "sca-L0?.conf"`
        if [ ! -r "$mainConfFile" ]; then
                mainConfFile="$curPath/../sca-L0.conf"
                extraConfFiles=`find $curPath/.. -name "sca-L0?.conf"`
                if [ ! -r "$mainConfFile" ]; then
                        exitError "No sca-L0 conf file info; exiting..."
                fi
        fi
fi
source $mainConfFile
for extraConfFile in $extraConfFiles; do
        source ${extraConfFile}
done
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
bugsDataTypes="$SCA_BUGS_DATATYPES"
bugsRadius="$SCA_BUGS_RADIUS"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, datasetsPath: $datasetsPath, bugsDataTypes: $bugsDataTypes, bugsRadius: $bugsRadius" >&2

# start
echo ">>> Checking bugs..."

dataTypes=""
for dataType in $bugsDataTypes; do
	if [ -s "$featuresPath/$dataType.tmp" ] && [ -r "$datasetsPath/$dataType.pkl" ]; then
		dataTypes="$dataTypes $dataType"
	fi
done
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypes: $dataTypes" >&2
if [ -z "$dataTypes" ]; then
	echo "        No warning/error messages to compare against bugs"
	[ $outFile ] && echo "bugs: none" >> $outFile
	[ $outFile ] && echo "bugs-result: 1" >> $outFile
	exit 0
fi

# build datasets argument to pass to knn_combined
knnCombinedArgs="$datasetsPath/bugs.dat"
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
	[ $outFile ] && echo "bugs: $bugs" >> "$outFile"
	i=1
	for bug in $bugs; do
		score=`echo $scores | cut -d' ' -f$i`
		echo "        Bug: $bug, Score: $score"
		[ $outFile ] && echo "bugs-score-$bug: $score" >> "$outFile"
		i=$((i + 1))
	done
	[ $outFile ] && echo "bugs-result: -1" >> "$outFile"
fi

exit 0
