#!/bin/sh

#
# This script outputs kernel information (version, support status, etc.)
#
# Inputs: 1) path containing features files
#	  2) susedata path
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  kernel, kernel-status, kernel-result name-value pairs written to output file
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path susedata-path [output-file]"
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
	exit 1
else
        featuresPath="$1"
	susedataPath="$2"
fi
if [ "$3" ]; then
	outFile="$3"
fi

if [ ! -d "$featuresPath" ] || [ ! -d "$susedataPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
	echo "$0: features path $featuresPath, susedata path $susedataPath, or output file $outFile  does not exist, exiting..."
	[ $outFile ] && echo "kernel: error" >> $outFile
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: error" >> $outFile
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
	[ $outFile ] && echo "kernel: error" >> $outFile
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: error" >> $outFile
	exit 1
fi

# intro
echo ">>> Checking kernel..."

# kernel
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

# kernel status
os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving kernel info"
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: 0" >> $outFile
	exit 1
fi
osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ "$osEquiv" ]; then
	os="$osEquiv"
fi
kVer=`echo $kern | sed 's/-[a-z]*$//'`
flavor=`echo $kern | sed "s/$kVer-//"`
[ $DEBUG ] && echo "*** DEBUG: $0: kVer: $kVer, flavor: $flavor" >&2
kPkg="kernel-${flavor}-${kVer}"
if [ ! -f "$susedataPath/rpms-$os.txt" ]; then
	echo "        No susedata rpm info for $os"
	[ $outFile ] && echo "kernel-status: error" >> $outFile
	[ $outFile ] && echo "kernel-result: 0" >> $outFile
	exit 1
fi
kPkgCur=`grep "kernel-$flavor-[0-9]" $susedataPath/rpms-$os.txt | tail -1`
kVerCur=`echo $kPkgCur | sed "s/^kernel-$flavor-//" | sed 's/\.${arch}\.rpm//'`
[ $DEBUG ] && echo "*** DEBUG: $0: kPkg: $kPkg, kPkgCur: $kPkgCur, kVerCur: $kVerCur" >&2
if ! grep $kPkg $susedataPath/rpms-$os.txt >/dev/null; then
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
