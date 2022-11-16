#!/bin/sh

#
# This is the main sca script that outputs analyzes a supportconfig.
#
# Inputs: (optional with -c) category-to-check (default checks all categories defined in sca.conf)
# 	  (optional with -p) path to datasets (default defined in sca.conf)
#	  (optional with -s) path to susedata (default defined in sca.conf) 
#	  (optional w/ -t) tmp path (default defined in sca.conf)
#         (optional with -o) name:value output file (in addition to stdout)
#	  supportconfig tarball 
#
# Output: Various info about supportconfig
#

#
# functions
#
function usage() {
	echo "Usage: `basename $0` [options] <supportconfig-tarfile>"
	echo "Options:"
	echo "    -d        debug"
	echo "    -v        version"
	echo "    -c        category (default checks all categories):"
	echo "                     $allCategories" 
	echo "    -p        datasets-path (default: $datasetsPath)"
	echo "    -s        susedata-path (default: $susedataPath)"
	echo "    -t        tmp-path (default: $tmpPath)"
	echo "    -o        file for short-form name:value output"
	echo "Example: sca.sh -c os -c system -o /tmp/sca.out /var/log/scc_*.txz"
}

function exitError() {
	echo "$1"
	[ ! -z "$tmpDir" ] && rm -rf $tmpDir 2>/dev/null
	exit 1
}

function untarAndCheck() {
	echo ">>> Uncompressing $scTar..."
	scTarName=`basename $scTar`
	[ $outFile ] && echo "supportconfig: $scTarName" >> $outFile
	if ! tar xf "$scTar" -C "$tmpDir" --strip-components=1 2>/dev/null; then
        	exitError "Uncompression of $scTar failed, check file for corruption.  Exiting..."
	fi
	# check that supportconfig contains basic info
	if [ -z "$tmpDir/basic-environment.txt" ]; then
        	exitError "No basic-environment.txt file in supportconfig, exiting..."
	fi
}

function extractScInfo() {
	echo ">>> Extracting info from supportconfig..."

	for dataType in $allDatatypes; do
		[ $DEBUG ] && echo "*** DEBUG: $0: dataType: $dataType" >&2
		[ $DEBUG ] && "$binPath"/"$dataType".sh "$debugOpt" "$tmpDir" > "$tmpDir"/"$dataType".tmp
		[ ! $DEBUG ] && "$binPath"/"$dataType".sh "$tmpDir" > "$tmpDir"/"$dataType".tmp
	done
}

function osOtherInfo() {
	echo ">>> Determining equivalent/related OS info..."

	os=`cat "$tmpDir"/os.tmp`
	"$binPath"/os-other.sh "$os" equiv > "$tmpDir"/os-equiv.tmp
	"$binPath"/os-other.sh "$os" related > "$tmpDir"/os-related.tmp
}

function supportconfigDate() {
	basicEnvFile="$tmpDir/basic-environment.txt"
	scDateLine=`grep -n -m 1 "# /bin/date" $basicEnvFile | cut -d":" -f1`
	scDate=`sed -n "$((${scDateLine} + 1))p" $basicEnvFile`
	echo ">>> Supportconfig date: $scDate"
	[ $outFile ] && echo "supportconfig-date: $scDate" >> $outFile
}

#
# main routine
#

curPath=`dirname "$(realpath "$0")"`

# conf files
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
extraConfFiles="${curPath}/../sca+.conf /etc/opt/sca/sca+.conf"
for extraConfFile in ${extraConfFiles}; do
	if [ -r "$extraConfFile" ]; then
		source $extraConfFile
		break
	fi
done
scaHome="$SCA_HOME"
allCategories="$SCA_CATEGORIES"
p1Categories="$SCA_P1_CATEGORIES"
p1Actions="$SCA_P1_ACTIONS"
p2Categories="$SCA_P2_CATEGORIES"
p2Actions="$SCA_P2_ACTIONS"
p3Categories="$SCA_P3_CATEGORIES"
p3Actions="$SCA_P3_ACTIONS"
allDatatypes=`echo "$SCA_DATATYPES" | xargs -n1 | sort -u | xargs`
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
susedataPath="$SCA_SUSEDATA_PATH"
parserBinPath="$SCA_PARSER_BIN_PATH"
tmpPath="$SCA_TMP_PATH"

# arguments
if [ "$1" = "--help" ]; then
	usage
	exit 0
fi
while getopts 'hdvc:p:s:t:o:' OPTION; do
        case $OPTION in
                h)
                        usage
			exit 0
                        ;;
                d)
                        DEBUG=1
			debugOpt="-d"
                        ;;
		v)
			VERSION_ARG=1
			;;
		c)
			categories+="$OPTARG "
			;;	
		p)
			datasetsPath="$OPTARG"
			if [ ! -d "$datasetsPath" ]; then
				exitError "datasets path $datasetsPath does not exist, exiting..."
			fi
			;;
		s)
			susedataPath="$OPTARG"
			if [ ! -d "$susedataPath" ]; then
				exitError "susedata path $susedataPath does not exist, exiting..."
			fi
			;;
		t)
			tmpPath="$OPTARG"
			if [ ! -d "$tmpPath" ]; then
				exitError "tmp path $tmpPath does not exist, exiting..."
			fi
			;;
		o)
			outFile="$OPTARG"
			if [ -f "$outFile" ]; then
#				echo "Short-form output file $outFile already exists, overwrite (y/N)? "
#				read reply
#				if [ "$reply" = "y" ]; then
#					rm $outFile
#				else	
#					exitError "Exiting..."
#				fi
				exitError "Short-form output file already exists, exiting..."
			fi
			if [ ! -d `dirname "$outFile"` ]; then
				exitError "Short-form output file path `dirname $outFile` does not exist, exiting..."
			fi
			;;
        esac
done
shift $((OPTIND - 1))
if [ ! $VERSION_ARG ] && [ ! "$1" ]; then
        usage
        exit 1
else
	scTar="$1"
fi

if [ -z "$categories" ]; then
	categories="$allCategories"
fi
[ $DEBUG ] && echo "*** DEBUG: $0: mainConfFile: $mainConfFile" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: extraConfFile: $extraConfFile" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: scaHome: $scaHome" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: allCategories: $allCategories" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: categories: $categories" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: datasetsPath: $datasetsPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: susedataPath: $susedataPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: tmpPath: $tmpPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: scTar: $scTar" >&2

scaVer=`cat $scaHome/sca.version`
if [ ! -z "$VERSION_ARG" ]; then
	echo $scaVer
	exit 0
fi

# tmp dir and current time
tmpDir=`mktemp -p $tmpPath -d`
[ $DEBUG ] && echo "*** DEBUG: $0: tmpDir: $tmpDir" >&2
tsIso=`date +"%Y-%m-%dT%H:%M:%S"`
ts=`date -d "$tsIso" +%s`
echo ">>> sca timestamp: $ts"
[ $outFile ] && echo "sca-timestamp: $ts" >> $outFile

# report sca info
echo ">>> sca version: $scaVer"
[ $outFile ] && echo "sca-version: $scaVer" >> $outFile
[ $outFile ] && echo "sca-default-checks: $allCategories" >> $outFile
[ $outFile ] && echo "sca-p1-categories: $p1Categories" >> $outFile
[ $outFile ] && echo "sca-p1-actions: $p1Actions" >> $outFile
[ $outFile ] && echo "sca-p2-categories: $p2Categories" >> $outFile
[ $outFile ] && echo "sca-p2-actions: $p2Actions" >> $outFile
[ $outFile ] && echo "sca-p3-categories: $p3Categories" >> $outFile
[ $outFile ] && echo "sca-p3-actions: $p3Actions" >> $outFile

# these steps are always executed (regardless of categories)
untarAndCheck
supportconfigDate
extractScInfo
osOtherInfo

# check categories
for category in $allCategories; do
	[ $DEBUG ] && echo "*** DEBUG: $0: category: $category" >&2
	if echo $categories | grep -q $category; then
		[ $DEBUG ] && $binPath/$category-info.sh "$debugOpt" "$tmpDir" "$outFile" ||
		$binPath/$category-info.sh "$tmpDir" "$outFile"
	else
		categoryUpper=`echo $category | tr '[:lower:]' '[:upper:]' | tr '-' '_'`
#		tags="SCA_${categoryUpper}_TAGS"
#		for tag in ${!tags}; do
#			[ $DEBUG ] && echo "*** DEBUG: $0: tag: $tag" >&2
#			[ $outFile ] && echo "$tag: NA" >> $outFile
#		done
		[ $outFile ] && echo "$category: NA" >> $outFile
	fi
done
rm -rf $tmpDir

# parse the output
parser="$parserBinPath/sca-parser.sh"
if [ -x "$parser" ]; then
	[ $DEBUG ] && $parser "$debugOpt" -c $mainConfFile $outFile ||
	$parser -c $mainConfFile $outFile
fi	

exit 0
