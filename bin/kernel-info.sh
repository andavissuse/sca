#!/bin/sh

#
# This script outputs kernel information (version, support status, etc.)
#
# Inputs: 1) path containing features files
#	  3) susedata path
#	  4) short-form output file (optional)
#
# Output: Info messages written to stdout (and output file if specified)
#
# Return Value:  1 if cert exists
#		 0
#		-1 if no cert exists
#		 2 for usage
#		-2 for error
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path susedata-path [output-file]"
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
if [ ! "$2" ]; then
        usage
else
        featuresPath="$1"
	susedataPath="$2"
fi
if [ "$3" ]; then
	outFile="$3"
fi

if [ ! -z "$4" ]; then
	outFile="$4"
fi
if [ ! -d "$featuresPath" ]; then
	exitError "$featuresPath does not exist, exiting..."
fi
if [ ! -d "$susedataPath" ]; then
	exitError "$susedataPath does not exist, exiting..."
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

echo ">>> Checking kernel..."
kern=`cat $featuresPath/kernel.tmp`
[ $DEBUG ] && echo "*** DEBUG: sca-L0.sh: kernel is $kern" >&2
kVer=`echo $kern | sed 's/-[a-z]*$//'`
[ $DEBUG ] && echo "*** DEBUG: sca-L0.sh: kVer is $kVer" >&2
flavor=`echo $kern | sed "s/$kVer-//"`
[ $DEBUG ] && echo "*** DEBUG: sca-L0.sh: flavor is $flavor" >&2
kPkg="kernel-$flavor-$kVer"
[ $DEBUG ] && echo "*** DEBUG: sca-L0.sh: kPkg is $kPkg" >&2
echo "        Kernel: $kern"
[ $outFile ] && echo "kernel: $kern" >> $outFile
os=`cat $featuresPath/os.tmp`
osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
if [ "$osEquiv" ]; then
	os="$osEquiv"
fi
kPkgCur=`grep "kernel-$flavor-[0-9]" $susedataPath/rpms-$os.txt | tail -1`
[ $DEBUG ] && echo "*** DEBUG: kPkgCur is $kPkgCur" >&2
kVerCur=`echo $kPkgCur | sed "s/^kernel-$flavor-//" | sed 's/\.${arch}\.rpm//'`
if ! grep $kPkg $susedataPath/rpms-$os.txt >/dev/null; then
	echo "        Kernel version is not an official SUSE kernel"
	[ $outFile ] && echo "kernel-status: non-suse-kernel" >> $outFile
	kernelResult=-1
elif ! echo "$kPkgCur" | grep "$kVer" >/dev/null; then
	echo "        Support status: Downlevel (current version: $kVerCur)"
	[ $outFile ] && echo "kernel-status: downlevel" >> $outFile
else
	echo "        Support status: Current"
	[ $outFile ] && echo "kernel-status: current" >> $outFile
	kernelResult=1
fi

[ $outFile ] && echo "kernel-result: $kernelResult" >> "$outFile"
exit 0
