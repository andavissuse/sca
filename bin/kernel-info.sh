#!/bin/sh

#
# This script outputs kernel information (version, support status, etc.)
#
# Inputs: 1) path containing features files
#	  2) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  kernel, kernel-status, kernel-result name-value pairs written to output file
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
	[ $outFile ] && echo "kernel: error" >> $outFile
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: error" >> $outFile
	exit 1
fi

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
	extraConfFiles="${curPath}/../sca+.conf /etc/opt/sca/sca+.conf"
	for extraConfFile in ${extraConfFiles}; do
		if [ -r "$extraConfFile" ]; then
			source $extraConfFile
			break
		fi
	done
fi
[ $DEBUG ] && echo "*** DEBUG: $0: confFile: $confFile" >&2
binPath="$SCA_BIN_PATH"
susedataPath="$SCA_SUSEDATA_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, susedataPath: $susedataPath" >&2

#
# start
#

# get kernel
echo ">>> Checking kernel..."
kern=`cat $featuresPath/kernel.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: kern: $kern" >&2
if [ -z "$kern" ]; then
	echo "        Error retrieving kernel info"
	[ $outFile ] && echo "kernel: error" >> $outFile
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: error" >> $outFile
	exit 1
fi
echo "        Kernel: $kern"
[ $outFile ] && echo "kernel: $kern" >> $outFile

# get os
os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outfile ] && echo "kernel-result: 0" >> $outFile
	exit 1
fi
osEquiv=`$binPath/os-other.sh $os equiv`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ ! -z "$osEquiv" ]; then
	os="$osEquiv"
fi
if [ ! -r "$susedataPath/rpms-$os.txt" ]; then
	echo "        Error retrieving OS data"
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: 0" >> $outFile
	exit 1
fi

# get kernel status
kVer=`echo $kern | sed 's/-[a-z]*$//'`
flavor=`echo $kern | sed "s/$kVer-//"`
[ $DEBUG ] && echo "*** DEBUG: $0: kVer: $kVer, flavor: $flavor" >&2
kPkg="kernel-${flavor}-${kVer}"
if [ ! -f "$SCA_SUSEDATA_PATH/rpms-$os.txt" ]; then
	echo "            No current kernel-${flavor} rpm info for $os"
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: 0" >> $outFile
	exit 1
fi
kPkgCur=`grep "kernel-$flavor-[0-9]" $SCA_SUSEDATA_PATH/rpms-$os.txt | tail -1`
kVerCur=`echo $kPkgCur | sed "s/^kernel-$flavor-//" | sed 's/\.${arch}\.rpm//'`
[ $DEBUG ] && echo "*** DEBUG: $0: kPkg: $kPkg, kPkgCur: $kPkgCur, kVerCur: $kVerCur" >&2
if ! grep $kPkg $SCA_SUSEDATA_PATH/rpms-$os.txt >/dev/null; then
	echo "        Kernel version is not an official SUSE kernel"
	[ $outFile ] && echo "kernel-status: non-suse-kernel" >> $outFile
	[ $outFile ] && echo "kernel-result: -1" >> $outFile
elif ! echo "$kPkgCur" | grep "$kVer" >/dev/null; then
	echo "        Support status: Downlevel (current version: $kVerCur)"
	[ $outFile ] && echo "kernel-status: downlevel" >> $outFile
	[ $outFile ] && echo "kernel-result: 0" >> $outFile
else
	echo "        Support status: Current"
	[ $outFile ] && echo "kernel-status: current" >> $outFile
	[ $outFile ] && echo "kernel-result: 1" >> $outFile
fi

exit 0
