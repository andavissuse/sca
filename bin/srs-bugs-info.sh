#!/bin/sh

#
# This script outputs information about SRs and bugs.
#
# Inputs: 1) path containing features files
#	  2) datasets path
#	  3) sr/bug type
#	  4) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  srs/bugs, srs/bugs-score, srs/bugs-result name-value pairs written to output file
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path datasets-path [output-file]"
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
if [ ! "$3" ]; then
        usage >&2
	exit 1
else
        featuresPath="$1"
	datasetsPath="$2"
	srsBugsType="$3"
fi
if [ "$4" ]; then
	outFile="$4"
fi

if [ ! -d "$featuresPath" ] || [ ! -d "$datasetsPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
        echo "$0: features path $featuresPath, datasets path $datasetsPath, or output file $outFile does not exist, exiting..." >&2
        [ $outFile ] && echo "$srsBugsType: error" >> $outFile
        [ $outFile ] && echo "$srsBugsType-result: 0" >> $outFile
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
	[ $outFile ] && echo "$srsBugsType: error" >> $outFile
	[ $outFile ] && echo "$srsBugsType-result: error" >> $outFile
	exit 1
fi

# intro
srsBugsResult=0
if [ "$srsBugsType" = "srs" ]; then
	srsBugsTypeStr="SRs"
fi
if [ "$srsBugsType" = "bugs" ]; then
	srsBugsTypeStr="bugs"
fi
echo ">>> Checking $srsBugsTypeStr..."

# SRS/bugs
os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "$srsBugsType: error" >> $outFile
        [ $outFile ] && echo "$srsBugsType-result: 0" >> $outFile
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
cutoffVal="0.8"
cutoffStr="80%"
dataTypes=""
for dataType in $SCA_SRS_BUGS_DATATYPES; do
	if [ -s "$featuresPath"/"$dataType".tmp ]; then
		dataTypes="$dataTypes $dataType"
	fi
done
if [ -z "$dataTypes" ]; then
	echo "        No warning/error messages to compare against $srsBugsTypeStr"
	[ $outFile ] && echo "$srsBugsType: none" >> $outFile
	[ $outFile ] && echo "$srsBugsType-result: 1" >> $outFile
	exit 0
fi
for dataType in $dataTypes; do
	if [ ! -s "$datasetsPath"/"$dataType"-"$os".dat ]; then
		echo "        Missing one or more datasets for $os"
		[ $outFile ] && echo "$srsBugsType: no-info" >> $outFile
		[ $outFile ] && echo "$srsBugsType-result: 0" >> $outFile
		exit 1
	fi
done
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypes: $dataTypes"
dataTypeArgs=""
for dataType in $dataTypes; do
	metricVar='$'`echo SCA_"${dataType^^}"_METRIC | sed "s/-/_/g"`
	eval metric=$metricVar
	weightVar='$'`echo SCA_"${dataType^^}"_WEIGHT | sed "s/-/_/g"`
	eval weight=$weightVar
	[ $DEBUG ] && echo "*** DEBUG: $0: metricVar: $metricVar, weightVar: $weightVar"
	dataTypeArg="$datasetsPath/$dataType-$os.dat $metric $weight"
	[ $DEBUG ] && echo "*** DEBUG: $0: dataTypeArg: $dataTypeArg"
	dataTypeArgs="$dataTypeArgs $dataTypeArg"
done
dataTypeArgs=`echo $dataTypeArgs | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: dataTypeArgs: $dataTypeArgs"
if [ -z "$dataTypeArgs" ]; then
	echo "        Error retrieving $srsBugsTypeStr"
	[ $outFile ] && echo "$srsBugsType: error" >> $outFile
	[ $outFile ] && echo "$srsBugsType-result: 0" >> $outFile
	exit 1
fi
[ $DEBUG ] && echo "*** DEBUG: $0: featuresPath: $featuresPath, datasetsPath: $datasetsPath, srsBugsType: $srsBugsType"
idsScores=`python3 $SCA_BIN_PATH/knn_combined.py "$featuresPath" "$datasetsPath"/"$srsBugsType".dat $dataTypeArgs`
[ $DEBUG ] && echo "*** DEBUG: $0: idsScores: $idsScores"
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
		if (( $(echo "$score >= $cutoffVal" | bc -l) )); then
			numHighIds=$(( numHighIds + 1 ))
			srsBugsResult=-1
		fi
		isId="TRUE"
	fi
done
ids=`echo $ids | sed "s/^ //"`
scores=`echo $scores | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: ids: $ids"
[ $DEBUG ] && echo "*** DEBUG: $0: scores: $scores"
[ $DEBUG ] && echo "*** DEBUG: $0: numHighIds: $numHighIds"
if [ "$numHighIds" -eq "0" ]; then
	echo "        No matching $srsBugsTypeStr found"
	[ $outFile ] && echo "$srsBugsType: none" >> $outFile
	srsBugsResult=1
else
	echo "        Found $numHighIds $srsBugsTypeStr with $cutoffStr or greater match"
	highIds=`echo $ids | cut -d" " -f1-${numHighIds}`
	[ $DEBUG ] && echo "*** DEBUG: $0: highIds: $highIds"
	[ $outFile ] && echo "$srsBugsType: $highIds" >> $outFile
	for index in $(seq 1 $numHighIds); do
		highId=`echo $highIds | cut -d" " -f$index`
		highScore=`echo $scores | cut -d" " -f$index`
		echo "             ID: $highId, Score: $highScore"
		[ $outFile ] && echo "$srsBugsType-score-$highId: $highScore" >> $outFile
	done
	srsBugsResult=-1
fi

[ $outFile ] && echo "$srsBugsType-result: $srsBugsResult" >> "$outFile"
exit 0
