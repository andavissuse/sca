#!/bin/sh

#
# This script outputs information about SRs.
#
# Inputs: 1) path containing features files
#	  2) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  srs, srs-score, srs-result name-value pairs written to output file
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
        [ $outFile ] && echo "srs: error" >> $outFile
        [ $outFile ] && echo "srs-result: 0" >> $outFile
        exit 1
fi
[ $DEBUG ] && echo "*** DEBUG: $0: featuresPath: $featuresPath" >&2

# config file
curPath=`dirname "$(realpath "$0")"`
confFile="/usr/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="$curPath/../sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
if [ -z "$SCA_HOME" ]; then
        echo "No sca-L0.conf file info; exiting..." >&2
	[ $outFile ] && echo "srs: error" >> $outFile
	[ $outFile ] && echo "srs-result: error" >> $outFile
	exit 1
fi
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
datasetsPathPrivate="$SCA_DATASETS_PATH_PRIVATE"
srsDataTypes="$SCA_SRS_DATATYPES"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, datasetsPath: $datasetsPath, datasetsPathPrivate: $datasetsPathPrivate, srsDataTypes: $srsDataTypes" >&2

# start
echo ">>> Checking SRs..."

os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "srs: error" >> $outFile
        [ $outFile ] && echo "srs-result: 0" >> $outFile
        exit 1
fi
osEquiv=`$binPath/os-other.sh "$os" equiv`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ ! -z "$osEquiv" ]; then
	os="$osEquiv"
fi

dataTypes=""
for dataType in $srsDataTypes; do
	if [ -s "$featuresPath/$dataType.tmp" ] && [ -r "$datasetsPath/$dataType.dat" ]; then
		dataTypes="$dataTypes $dataType"
	fi
done
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypes: $dataTypes" >&2
if [ -z "$dataTypes" ]; then
	echo "        No warning/error messages to compare against SRs"
	[ $outFile ] && echo "srs: none" >> $outFile
	[ $outFile ] && echo "srs-result: 1" >> $outFile
	exit 0
fi

# build datasets argument to pass to knn_combined
knnCombinedArgs="$datasetsPath/srs.dat"
for dataType in $dataTypes; do
#	metricVar='$'`echo SCA_SRS_"${dataType^^}"_METRIC | sed "s/-/_/g"`
#	eval metric=$metricVar
	metric="jaccard"
	radius="0.2"
#	weightVar='$'`echo SCA_SRS_"${dataType^^}"_WEIGHT | sed "s/-/_/g"`
#	eval weight=$weightVar
	weight="1"
	[ $DEBUG ] && echo "*** DEBUG: $0: metricVar: $metricVar, radiusVar: $radiusVar, weightVar: $weightVar" >&2
	datasetArg="$datasetsPath/$dataType.dat $featuresPath/$dataType.tmp $metric $radius $weight"
	[ $DEBUG ] && echo "*** DEBUG: $0: datasetArg: $datasetArg" >&2
	knnCombinedArgs="$knnCombinedArgs $datasetArg"
done
knnCombinedArgs="$knnCombinedArgs $datasetsPath/os.dat $featuresPath/os.tmp jaccard 0 1"
knnCombinedArgs=`echo $knnCombinedArgs | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: knnCombinedArgs: $knnCombinedArgs" >&2
if [ -z "$knnCombinedArgs" ]; then
	echo "        Error retrieving SRs"
	[ $outFile ] && echo "srs: error" >> $outFile
	[ $outFile ] && echo "srs-result: 0" >> $outFile
	exit 1
fi

if [ "$DEBUG" ]; then 
	idsScores=`python3 $binPath/knn_combined.py -d $knnCombinedArgs`
else
	idsScores=`python3 $binPath/knn_combined.py $knnCombinedArgs`
fi
[ $DEBUG ] && echo "*** DEBUG: $0: idsScores: $idsScores" >&2

declare -a idsScoresArray=(`echo $idsScores | tr -d "[],'"`)
if [ -z "$idsScoresArray" ]; then
	echo "        SRs: none"
	[ $outFile ] && echo "srs: none" >> $outFile
	[ $outFile ] && echo "srs-result: 1" >> $outFile
else
	i=0
	srs=""
	while [ ! -z "${idsScoresArray[i]}" ]; do
		srs="$srs ${idsScoresArray[i]}"
		scores="$scores ${idsScoresArray[(($i+1))]}"
		i=$((i + 2))
	done
	realSrs=""
	if [ -r "$datasetsPathPrivate/srs-hash.dat" ]; then
		for sr in $srs; do
			realSr=`grep "$sr" "$datasetsPathPrivate/srs-hash.dat" | cut -d' ' -f1`
			realSrs="$realSrs $realSr"
		done
		srs="$realSrs"
	fi
	[ $outFile ] && echo "srs: $srs" >> "$outFile"
	i=1
	for sr in $srs; do
		score=`echo $scores | cut -d' ' -f$i`
		echo "        SR: $sr, Score: $score"
		[ $outFile ] && echo "srs-score-$sr: $score" >> "$outFile"
		i=$((i + 1))
	done
	[ $outFile ] && echo "srs-result: -1" >> "$outFile"
fi

exit 0
