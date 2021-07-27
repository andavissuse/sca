#!/bin/sh

#
# This script outputs information about the system (manufacturer, model, YES certs)
#
# Inputs: 1) path containing features files
#	  2) datasets path
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  system, system-certs, system-result name-value pairs written to output file 
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
if [ ! "$2" ]; then
        usage >&2
	exit 1
else
        featuresPath="$1"
	datasetsPath="$2"
fi
if [ ! -z "$3" ]; then
	outFile="$3"
fi

if [ ! -d "$featuresPath" ] || [ ! -d "$datasetsPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
	echo "$0: features path $featuresPath, datasets path $datasetsPath, or output file $outFile does not exist, exiting..." >&2
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

# intro
echo ">>> Checking system and certifications..."

# system
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
os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "system-certs: error" >> $outFile
	[ $outFile ] && echo "system-result: 0" >> $outFile
	exit 1
fi
osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ "$osEquiv" ]; then
	echo "        Checking relevant $osEquiv certifications..."
	os="$osEquiv"
fi
osId=`echo $os | cut -d'_' -f1`
osVerId=`echo $os | cut -d'_' -f2`
osArch=`echo $os | cut -d'_' -f1,2 --complement`
[ $DEBUG ] && echo "*** DEBUG: $0: osId: $osId, osVerId: $osVerId, osArch: $osArch"
if ! ls $datasetsPath/system-model-"$osId"_*_"$osArch".dat >/dev/null 2>&1; then
        echo "        No certification data for "$osId" "$osArch""
        [ $outFile ] && echo "system-certs: no-info" >> $outFile
        [ $outFile ] && echo "system-result: 0" >> $outFile
        exit 1
fi
osVerMajor=`echo $osVerId | cut -d'.' -f1`
osVerMinor=`echo $osVerId | cut -d'.' -f2`
if [ "$osVerMajor" = "12" ]; then
	verMinorBase="3"
else
	verMinorBase="0"
fi
[ $DEBUG ] && echo "*** DEBUG: $0: osId: $osId, osVerId: $osVerId, osArch: $osArch, osVerMajor: $osVerMajor, osVerMinor: $osVerMinor"
foundCert="FALSE"
verMinorToCheck="$osVerMinor"
while (( verMinorToCheck >= verMinorBase )); do
	osToCheck="${osId}_${osVerMajor}.${verMinorToCheck}_${osArch}"
	[ $DEBUG ] && echo "*** DEBUG: $0: osToCheck: $osToCheck" >&2
	certsFromModels="[]"
	[ -f "$datasetsPath/system-model-$osToCheck.dat" ] && certsFromModels=`python3 $SCA_BIN_PATH/knn.py $featuresPath/system-model.tmp $datasetsPath/certs.dat $datasetsPath/system-model-$osToCheck.dat "jaccard" "true" 2>/dev/null`
	[ $DEBUG ] && echo "*** DEBUG: $0: certsFromModels: $certsFromModels" >&2
	if [ "$certsFromModels" != "[]" ]; then
		certsMod=`echo $certsFromModels | sed "s/^\[//" | sed "s/\]$//" | sed "s/,//g" | sed "s/'//g"`
		[ $DEBUG ] && echo "*** DEBUG: $0: certsMod: $certsMod" >&2
		if [ ! -z "$certsMod" ]; then
			certs=`echo $certsMod | grep -E -o "[0-9]{6}" | sort -u | tr '\n' ' '`
			[ $DEBUG ] && echo "*** DEBUG: $0: certs: $certs" >&2
			if [ ! -z "$certs" ]; then
				echo "        YES Certification Bulletins for SLE $osVerMajor SP$verMinorToCheck:"
				certURLs=""
				for bulletinId in $certs; do
					foundCert="TRUE"
					certURL="https://www.suse.com/nbswebapp/yesBulletin.jsp?bulletinNumber=$bulletinId"
					certURLs="$certURLs $certURL"
				done
				for certURL in $certURLs; do
					echo "            $certURL"
				done
			fi
		fi
	else
		echo "        YES certifications found for SLE $osVerMajor SP$verMinorToCheck: none"
	fi
	verMinorToCheck=$(( verMinorToCheck - 1 ))
done
if [ "$foundCert" = "TRUE" ]; then
	certURLs=`echo $certURLs | sed "s/^ //"`
	[ $outFile ] && echo "system-certs: $certURLs" >> $outFile
	[ $outFile ] && echo "system-result: 1" >> $outFile
else
	echo "        No system certifications"
	[ $outFile ] && echo "system-certs: none" >> $outFile
	[ $outFile ] && echo "system-result: -1" >> $outFile
fi
exit 0
