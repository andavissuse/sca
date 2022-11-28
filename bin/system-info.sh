#!/bin/sh

#
# This script outputs information about the system (manufacturer, model)
#
# Inputs: 1) path containing features files
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  system, system-result name-value pairs written to output file 
#

# functions
usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path [output-file]"
}

function exitError() {
	echo "$1"
	[ ! -z "$tmpDir" ] && rm -rf $tmpDir
	exit 1
}

round() {
  printf "%.${2}f" "${1}"
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
if [ ! -z "$2" ]; then
	outFile="$2"
fi

if [ ! -d "$featuresPath" ]; then
	echo "$0: features path $featuresPath does not exist, exiting..." >&2
	[ $outFile ] && echo "system: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
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
#	extraConfFiles="${curPath}/../sca+.conf /etc/opt/sca/sca+.conf"
#	for extraConfFile in ${extraConfFiles}; do
#		if [ -r "$extraConfFile" ]; then
#			source $extraConfFile
#			break
#		fi
#	done
fi
[ $DEBUG ] && echo "*** DEBUG: $0: confFile: $confFile" >&2
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
susedataPath="$SCA_SUSEDATA_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, datasetsPath: $datasetsPath, susedataPath: $susedataPath" >&2

# start 
echo ">>> Checking system..."
sman=`cat $featuresPath/system-manufacturer.tmp 2>/dev/null`
smod=`cat $featuresPath/system-model.tmp 2>/dev/null`
[ $DEBUG ] && echo "*** DEBUG: $0: sman: $sman, smod: $smod, hypervisor: $hypervisor" >&2
if [ -z "$sman" ] || [ -z "$smod" ]; then
	echo "        Error retrieving system info"
	[ $outFile ] && echo "system: error" >> $outFile
	[ $outFile ] && echo "system-certs: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
	exit 1
fi
echo "        System: $sman $smod"
[ $outFile ] && echo "system: $sman $smod" >> $outFile

if [ "$sman" = "QEMU" ]; then
        echo "        System is KVM guest; no hardware certifications"
        [ $outFile ] && echo "system-certs: NA" >> $outFile
        [ $outFile ] && echo "system-result: 0" >> $outFile
        exit 0
fi

# certs
# get os, equivalent os(es), and related os(es)
os=`cat $featuresPath/os.tmp 2>/dev/null`
osEquiv=`cat $featuresPath/os-equiv.tmp 2>/dev/null | tr '\n' ' '`
osRelated=`cat $featuresPath/os-related.tmp 2>/dev/null | tr '\n' ' '`
osesToCheck="$os $osEquiv $osRelated"
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os, osEquiv: $osEquiv, osRelated: $osRelated, osesToCheck: $osesToCheck" >&2

# verify we have all info to proceed, otherwise exit
if [ -z "$osesToCheck" ]; then
        echo "        Error retrieving OS info"
        [ $outFile ] && echo "system-certs: error" >> $outFile
        [ $outFile ] && echo "system-result: 0" >> $outFile
        exit 1
fi
dataFileFound="FALSE"
for osToCheck in $osesToCheck; do
	[ $DEBUG ] && echo "*** DEBUG: $0: osToCheck: $osToCheck" >&2
	if [ -r "${susedataPath}/certs-${osToCheck}.txt" ]; then
		dataFileFound="TRUE"
                break
        fi
done
if [ "$dataFileFound" = "FALSE" ]; then
        echo "        Error retrieving certs info"
	[ $outFile ] && echo "system-certs: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
	exit 1
fi

resultVal=0
bulletinFound="FALSE"
for osToCheck in $osesToCheck; do
	[ $DEBUG ] && echo "*** DEBUG: $0: osToCheck: $osToCheck" >&2
	bulletinIds=`grep "$sman $smod" $susedataPath/certs-$osToCheck.txt 2>/dev/null | cut -d" " -f1 | tr '\n' ' '`
	[ $DEBUG ] && echo "*** DEBUG: $0: bulletinIds: $bulletinIds" >&2
	if [ -z "$bulletinIds" ]; then
		continue
	fi
	bulletinFound="TRUE"
	if echo $osToCheck | grep -q "$os" || echo $osToCheck | grep -q "$osEquiv"; then
		resultVal=1
	fi
	echo "        YES Certification Bulletins for $osToCheck:"
	for bulletinId in $bulletinIds; do
		bulletinURL="https://www.suse.com/nbswebapp/yesBulletin.jsp?bulletinNumber=$bulletinId"
		echo "            https://www.suse.com/nbswebapp/yesBulletin.jsp?bulletinNumber=$bulletinId"
		bulletinURLs="$bulletinURLs $bulletinURL"
	done
done
if [ "$bulletinFound" = "FALSE" ]; then
	echo "        No applicable certifications found"
	[ $outFile ] && echo "system-certs: none" >> $outFile
	[ $outFile ] && echo "system-result: -1" >> $outFile
else
	bulletinURLs=`echo $bulletinURLs | sed 's/^ //'`
	[ $outFile ] && echo "system-certs: $bulletinURLs" >> $outFile
	[ $outFile ] && echo "system-result: $resultVal" >> $outFile
fi

exit 0
