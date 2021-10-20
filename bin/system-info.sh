#!/bin/sh

#
# This script outputs information about the system (manufacturer, model, YES certs)
#
# Inputs: 1) path containing features files
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  system, system-certs, system-result name-value pairs written to output file 
#

# functions
usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path [output-file]"
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
	[ $outFile ] && echo "system-certs: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
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
	[ $outFile ] && echo "system: error" >> $outFile
	[ $outFile ] && echo "system-certs: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
	exit 1
fi
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, datasetsPath: $datasetsPath" >&2

# start 
echo ">>> Checking system and certifications..."
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

#
# certs
#

# get os, equivalent os(es), and related os(es)
os=`cat $featuresPath/os.tmp 2>/dev/null`
osEquiv=`cat $featuresPath/os-equiv.tmp 2>/dev/null | tr '\n' ' '`
osRelated=`cat $featuresPath/os-related.tmp 2>/dev/null | tr '\n' ' '`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2

# verify that we have all req'd info to proceed; otherwise exit
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "system-certs: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
	exit 1
fi
if [ ! -s "$datasetsPath/system-model.dat" ] || [ ! -s "$datasetsPath/os.dat" ] || [ ! -s "$datasetsPath/certs.dat" ]; then
        echo "        Error retrieving certification info"
        [ $outFile ] && echo "system-certs: no-info" >> $outFile
        [ $outFile ] && echo "system-result: 0" >> $outFile
        exit 1
fi

# certs
# stage 1: os, stage 2: equivalent os(es), stage 3: related os(es)
osesToCheck="$os $osEquiv $osRelated"
[ $DEBUG ] && echo "*** DEBUG: $0: osesToCheck: $osesToCheck" >&2
for osToCheck in $osesToCheck; do
	[ $DEBUG ] && echo "*** DEBUG: $0: osToCheck: $osToCheck" >&2
	echo $osToCheck > $featuresPath/osToCheck.tmp
	knnCombinedArgs="$datasetsPath/certs.dat $datasetsPath/system-model.dat $featuresPath/system-model.tmp jaccard 0 1 $datasetsPath/os.dat $featuresPath/osToCheck.tmp jaccard 0 1"
	[ $DEBUG ] && echo "*** DEBUG: $0: knnCombinedArgs: $knnCombinedArgs" >&2
	[ $DEBUG ] && echo "*** DEBUG: $0: initial bulletinIds: $bulletinIds" >&2
	if [ $DEBUG ]; then
		knnResult=`python3 $binPath/knn_combined.py -d $knnCombinedArgs`
	else
		knnResult=`python3 $binPath/knn_combined.py $knnCombinedArgs`
	fi
	[ $DEBUG ] && echo "*** DEBUG: $0: knnResult: $knnResult"
	bulletinIds=`echo $knnResult | tr -d "[],'" | sed -r 's/ [^ ]*( |$)/\1/g'`
	[ $DEBUG ] && echo "*** DEBUG: $0: bulletinIds: $bulletinIds" >&2
	if [ ! -z "$bulletinIds" ]; then
		matchFound="TRUE"
		echo "        YES Certification Bulletins for $os:"
		for bulletinId in $bulletinIds; do
			certURL="https://www.suse.com/nbswebapp/yesBulletin.jsp?bulletinNumber=$bulletinId"
			echo "            https://www.suse.com/nbswebapp/yesBulletin.jsp?bulletinNumber=$bulletinId"
			certURLs="$certURLs $certURL"
		done
		certURLs=`echo $certURLs | sed 's/^ //'`
		[ $outFile ] && echo "system-certs: $certURLs" >> $outFile
		if echo "$os" | grep -q "$osToCheck" || echo $osEquiv | grep "$osToCheck"; then
			[ $outFile ] && echo "system-result: 1" >> $outFile
		else
			[ $outFile ] && echo "system-result: 0" >> $outFile
		fi
		break
	fi
	if [ "$matchFound" = "TRUE" ]; then
		[ $outfile ] && echo "system-result: -1" >> $outFile
	fi
done

exit 0
