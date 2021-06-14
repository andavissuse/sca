#!/bin/sh

#
# This script outputs information about SRs and bugs.
#
# Inputs: 1) path containing features files
#	  2) datasets path
#	  3) sr/bug type
#	  4) short-form output file (optional)
#
# Output: Info messages written to stdout (and output file if specified)
#
# Return Value:  1 if sr/bug exists
#		 0
#		-1 if no sr/bug exists
#		 2 for usage
#		-2 for error
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path datasets-path [output-file]"
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
if [ ! "$3" ]; then
        usage
else
        featuresPath="$1"
	datasetsPath="$2"
	srsBugsType="$3"
fi
if [ "$4" ]; then
	outFile="$4"
fi

if [ ! -d "$featuresPath" ]; then
	exitError "$featuresPath does not exist, exiting..."
fi
if [ ! -d "$datasetsPath" ]; then
	exitError "$datasetsPath does not exist, exiting..."
fi
if [ "$srsBugsType" != "srs" ] && [ "$srsBugsType" != "bugs" ]; then
	exitError "$srsBugsType is not srs or bugs, exiting..."
fi
if [ ! -f "$outFile" ]; then
	exitError "$outFile does not exist, exiting..."
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
        exitError "No sca-L0.conf file info; exiting..."
fi

srsBugsResult=0
if [ "$srsBugsType" = "srs" ]; then
	srsBugsTypeStr="SRs"
fi
if [ "$srsBugsType" = "bugs" ]; then
	srsBugsTypeStr="bugs"
fi
singleType=`echo $srsBugsType | sed "s/s$//"`
cutoffVal="0.8"
cutoffStr="80%"
os=`cat $featuresPath/os.tmp`
osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ ! -z "$osEquiv" ]; then
	os="$osEquiv"
fi
osId=`echo $os | cut -d'_' -f1`
osVerId=`echo $os | cut -d'_' -f2`
osArch=`echo $os | cut -d'_' -f1,2 --complement`
echo ">>> Finding $srsBugsType..."
dataTypes=""
for dataType in $SCA_SRS_BUGS_DATATYPES; do
	if [ -s "$featuresPath"/"$dataType".tmp ] && [ -s "$datasetsPath"/"$dataType"-"$os".dat ]; then
		dataTypes="$dataTypes $dataType"
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
	echo "        Unable to compare error/warning messages: no error/warning messages in supportconfig or no applicable datasets"
	[ $outFile ] && echo "$srsBugsType: no-info" >> $outFile
else
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
fi

[ $outFile ] && echo "$srsBugsType-result: $srsBugsResult" >> "$outFile"
exit 0
