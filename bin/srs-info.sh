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

# start
echo ">>> Checking SRs..."
srsResult=0
cutoffStr=`echo $SCA_SRS_CUTOFF | sed 's/\.//' | sed 's/$/%/'`
os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "srs: error" >> $outFile
        [ $outFile ] && echo "srs-result: 0" >> $outFile
        exit 1
fi
osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ ! -z "$osEquiv" ]; then
	os="$osEquiv"
fi
osId=`echo $os | cut -d'_' -f1`
osVerId=`echo $os | cut -d'_' -f2`
osArch=`echo $os | cut -d'_' -f1,2 --complement`
dataTypes=""
for dataType in $SCA_SRS_DATATYPES; do
	if [ -s "$featuresPath"/"$dataType".tmp ]; then
		dataTypes="$dataTypes $dataType"
	fi
done
if [ -z "$dataTypes" ]; then
	echo "        No warning/error messages to compare against SRs"
	[ $outFile ] && echo "srs: none" >> $outFile
	[ $outFile ] && echo "srs-result: 1" >> $outFile
	exit 0
fi
for dataType in $dataTypes; do
	if [ ! -s "$SCA_DATASETS_PATH"/"$dataType"-"$os".dat ]; then
		echo "        Missing one or more datasets for $os"
		[ $outFile ] && echo "srs: no-info" >> $outFile
		[ $outFile ] && echo "srs-result: 0" >> $outFile
		exit 1
	fi
done
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypes: $dataTypes" >&2
dataTypeArgs=""
for dataType in $dataTypes; do
	metricVar='$'`echo SCA_SRS_"${dataType^^}"_METRIC | sed "s/-/_/g"`
	eval metric=$metricVar
	weightVar='$'`echo SCA_SRS_"${dataType^^}"_WEIGHT | sed "s/-/_/g"`
	eval weight=$weightVar
	[ $DEBUG ] && echo "*** DEBUG: $0: metricVar: $metricVar, weightVar: $weightVar" >&2
	dataTypeArg="$SCA_DATASETS_PATH/$dataType-$os.dat $metric $weight"
	[ $DEBUG ] && echo "*** DEBUG: $0: dataTypeArg: $dataTypeArg" >&2
	dataTypeArgs="$dataTypeArgs $dataTypeArg"
done
dataTypeArgs=`echo $dataTypeArgs | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypeArgs: $dataTypeArgs" >&2
if [ -z "$dataTypeArgs" ]; then
	echo "        Error retrieving SRs"
	[ $outFile ] && echo "srs: error" >> $outFile
	[ $outFile ] && echo "srs-result: 0" >> $outFile
	exit 1
fi
[ $DEBUG ] && echo "*** DEBUG: $0: featuresPath: $featuresPath" >&2
idsScores=`python3 $SCA_BIN_PATH/knn_combined.py "$featuresPath" "$SCA_DATASETS_PATH"/srs.dat $dataTypeArgs 2>/dev/null`
[ $DEBUG ] && echo "*** DEBUG: $0: idsScores: $idsScores" >&2
ids=""
scores=""
let numHighIds=0
realIds=""
isId="TRUE"
for entry in `echo $idsScores | tr -d "[],'" | cut -d" " -f1-10`; do
	if [ "$isId" = "TRUE" ]; then
		id="$entry"
		isId="FALSE"
	else
		score="$entry"
		formattedScore=`printf "%0.2f" $score`
		ids="$ids $id"
		scores="$scores $formattedScore"
		[ $DEBUG ] && echo "*** DEBUG: $0: score: $score" >&2
		if (( $(echo "$score >= $SCA_SRS_CUTOFF" | bc -l) )); then
			numHighIds=$(( numHighIds + 1 ))
			srsResult=-1
		fi
		isId="TRUE"
	fi
done
ids=`echo $ids | sed "s/^ //"`
scores=`echo $scores | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: ids: $ids" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: scores: $scores" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: numHighIds: $numHighIds" >&2
if [ "$numHighIds" -eq "0" ]; then
	echo "        No matching SRs found"
	[ $outFile ] && echo "srs: none" >> $outFile
	srsResult=1
else
	echo "        Found $numHighIds SRs with $cutoffStr or greater match"
	highIds=`echo $ids | cut -d" " -f1-${numHighIds}`
	hashFile="$SCA_DATASETS_PATH_PRIVATE/srs-hash.dat"
	[ $DEBUG ] && echo "*** DEBUG: $0: hashFile: $hashFile" >&2
	if [ -f "$hashFile" ]; then
		for highId in $highIds; do
			realId=`grep $highId $hashFile | cut -d" " -f1`
			[ $DEBUG ] && echo "*** DEBUG: $0: highId: $highId, realId: $realId" >&2
			realIds="$realIds $realId"
		done
		highIds=`echo $realIds | sed "s/^ //"`
	fi
	[ $DEBUG ] && echo "*** DEBUG: $0: highIds: $highIds" >&2
	[ $outFile ] && echo "srs: $highIds" >> $outFile
	for index in $(seq 1 $numHighIds); do
		highId=`echo $highIds | cut -d" " -f$index`
		highScore=`echo $scores | cut -d" " -f$index`
		echo "             ID: $highId, Score: $highScore"
		[ $outFile ] && echo "srs-score-$highId: $highScore" >> $outFile
	done
	srsResult=-1
fi

[ $outFile ] && echo "srs-result: $srsResult" >> "$outFile"
exit 0
