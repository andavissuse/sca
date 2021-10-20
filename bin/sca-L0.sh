#!/bin/sh

#
# This is the sca script that outputs L0-related information
# such as supportability, hardware certs, existence of srs, etc.
# Default path for datasets is ../datasets and default path for
# susedata is ../susedata, but these may be overridden with
# optional arguments.
#
# Inputs: (optional with -c) parameters-to-check (os, system, kernel, kmods, warning-cmds, error-cmds, srs, bugs)
# Inputs: (optional with -p) path to datasets
#	  (optional with -s) path to susedata
#	  (optional w/ -t) tmp path (for uncompressing supportconfig)
#         (optional with -o) output file for terse report (in addition to stdout)
#	  supportconfig tarball 
#
# Output: Various info about supportconfig
#

#
# functions
#
function usage() {
	echo "Usage: `basename $0` [-d(ebug)]"
	echo "                 [-v(ersion)]"
	echo "                 [-c(ategories) - comma-separated list of categories to check (default checks all)]"
	echo "                     categories: os system kernel kmods warning-cmds error-cmds srs bugs" 
	echo "                 [-p datasets-path]"
	echo "                 [-s susedata-path]"
	echo "                 [-t tmp-path]"
	echo "                 [-o outfile (short-form output)]"
	echo "                 supportconfig-tarfile"
	echo "                 Example: sca-L0.sh -c os,srs -o /tmp/sca-L0.out /var/log/supportconfig.tgz"
}

function exitError() {
	echo "$1"
	rm -rf $tmpDir 2>/dev/null
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

	for dataType in $SCA_ALL_DATATYPES; do
		[ $DEBUG ] && echo "*** DEBUG: $0: dataType: $dataType" >&2
		[ $DEBUG ] && "$SCA_BIN_PATH"/"$dataType".sh "$debugOpt" "$tmpDir" > "$tmpDir"/"$dataType".tmp
		[ ! $DEBUG ] && "$SCA_BIN_PATH"/"$dataType".sh "$tmpDir" > "$tmpDir"/"$dataType".tmp
	done
}

function osOtherInfo() {
	echo ">>> Determining equivalent/related OS info..."

	os=`cat "$tmpDir"/os.tmp`
	"$SCA_BIN_PATH"/os-other.sh "$os" equiv > "$tmpDir"/os-equiv.tmp
	"$SCA_BIN_PATH"/os-other.sh "$os" related > "$tmpDir"/os-related.tmp
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
			categories=`echo $OPTARG | tr ',' ' '`
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
				echo "Short-form output file $outFile already exists, overwrite (y/N)? "
				read reply
				if [ "$reply" = "y" ]; then
					rm $outFile
				else	
					exitError "Exiting..."
				fi
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

#
# conf file
#
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

#
# set variables (command-line opts override conf file)
#
[ -z "$categories" ] && categories="$SCA_CHECK_CATEGORIES"
[ -z "$datasetsPath" ] && datasetsPath="$SCA_DATASETS_PATH"
[ -z "$susedataPath" ] && susedataPath="$SCA_SUSEDATA_PATH"
[ -z "$tmpPath" ] && tmpPath="$SCA_TMP_PATH"

[ $DEBUG ] && echo "*** DEBUG: $0: SCA_HOME: $SCA_HOME" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: SCA_BIN_PATH: $SCA_BIN_PATH" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: datasetsPath: $datasetsPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: susedataPath: $susedataPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: tmpPath: $tmpPath" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: categories: $categories" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: scTar: $scTar" >&2

scaVer=`cat $SCA_HOME/sca-L0.version`
if [ ! -z "$VERSION_ARG" ]; then
	echo $scaVer
	exit 0
fi

# tmp dir and current time
tmpDir=`mktemp -p $tmpPath -d`
[ $DEBUG ] && echo "*** DEBUG: $0: tmpDir: $tmpDir" >&2
tsIso=`date +"%Y-%m-%dT%H:%M:%S"`
ts=`date -d "$tsIso" +%s`
echo ">>> sca-L0 timestamp: $ts"
[ $outFile ] && echo "sca-l0-timestamp: $ts" >> $outFile

# report sca-L0 version and default parameters to check
echo ">>> sca-L0 version: $scaVer"
[ $outFile ] && echo "sca-l0-version: $scaVer" >> $outFile
[ $outFile ] && echo "sca-l0-default-checks: $SCA_CHECK_CATEGORIES" >> $outFile

# these steps are always executed (regardless of parameter arguments)
untarAndCheck
supportconfigDate
extractScInfo
osOtherInfo

# OS version supportability
if echo "$categories" | grep -q -E "^os$|^os | os | os$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/os-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/os-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "os: NA" >> $outFile
	[ $outFile ] && echo "os-support: NA" >> $outFile
	[ $outFile ] && echo "os-result: NA" >> $outFile
fi

# system info (incl. nearest neighbor to find hardware certs)
if echo "$categories" | grep -q -E "^system$|^system | system | system$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/system-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/system-info.sh "$tmpDir" "$outFile"
else
        [ $outFile ] && echo "system: NA" >> $outFile
        [ $outFile ] && echo "system-certs: NA" >> $outFile
	[ $outFile ] && echo "system-result: NA" >> $outFile
fi

# kernel
if echo "$categories" | grep -q -E "^kernel$|^kernel | kernel | kernel$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/kernel-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/kernel-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "kernel: NA" >> $outFile
	[ $outFile ] && echo "kernel-status: NA" >> $outFile
	[ $outFile ] && echo "kernel-result: NA" >> $outFile
fi

# kernel modules
if echo "$categories" | grep -q -E "^kmods$|^kmods | kmods | kmods$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/kmods-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/kmods-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "kmods-externally-supported: NA" >> $outFile
	[ $outFile ] && echo "kmods-unsupported: NA" >> $outFile
	[ $outFile ] && echo "kmods-result: NA" >> $outFile
fi

# warning message commands
if echo "$categories" | grep -q -E "^warning-cmds$|^warning-cmds | warning-cmds | warning-cmds$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/warning-cmds-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/warning-cmds-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "warning-cmds: NA" >> $outFile
	[ $outFile ] && echo "warning-cmds-result: NA" >> $outFile
fi

# error message commands
if echo "$categories" | grep -q -E "^error-cmds$|^error-cmds | error-cmds | error-cmds$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/error-cmds-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/error-cmds-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "error-cmds: NA" >> $outFile
	[ $outFile ] && echo "error-cmds-result: NA" >> $outFile
fi

# predicting SRs
if echo "$categories" | grep -q -E "^srs$|^srs | srs | srs$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/srs-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/srs-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "srs: NA" >> $outFile
	[ $outFile ] && echo "srs-result: NA" >> $outFile
fi

# predicting bugs
if  echo "$categories" | grep -q -E "^bugs$|^bugs | bugs | bugs$"; then
	[ $DEBUG ] && $SCA_BIN_PATH/bugs-info.sh "$debugOpt" "$tmpDir" "$outFile"
	[ ! $DEBUG ] && $SCA_BIN_PATH/bugs-info.sh "$tmpDir" "$outFile"
else
	[ $outFile ] && echo "bugs: NA" >> $outFile
	[ $outFile ] && echo "bugs-result: NA" >> $outFile
fi

rm -rf $tmpDir
exit 0
