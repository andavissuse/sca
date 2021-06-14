#!/bin/sh

#
# This script outputs information about the system (manufacturer, model, YES certs)
#
# Inputs: 1) path containing features files
#	  2) datasets path
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout (and output file if specified)
#         system-result value written to output file:  1 if cert exists for specified or previous SP
#						       0 if cert exists for equivalent OS
#						      -1 if no cert exists
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

if [ ! -d "$featuresPath" ]; then
	echo "$featuresPath does not exist, exiting..." >&2
	exit 1
fi
if [ ! -d "$datasetsPath" ]; then
	echo "$datasetsPath does not exist, exiting..." >&2
	exit 1
fi
if [ ! -z "$outFile" ] && [ ! -f "$outFile" ]; then
	echo "$outFile does not exist, exiting..." >&2
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
fi

echo ">>> Checking system and certifications..."
sman=`cat $featuresPath/system-manufacturer.tmp 2>/dev/null`
smod=`cat $featuresPath/system-model.tmp 2>/dev/null`
[ $DEBUG ] && echo "*** DEBUG: $0: sman: $sman, smod: $smod" >&2
if [ -z "$sman" ] || [ -z "$smod" ]; then
	echo "        Missing system manufacturer and/or model info in supportconfig"
	[ $outFile ] && echo "system: no-info" >> $outFile
elif echo "$sman" | grep -q -E "QEMU|Xen"; then
	if echo "$sman" | grep -q QEMU; then
		sman="KVM"
	fi
	echo "        System is a $sman virtual machine running on SLES; no hardware certifications"
	[ $outFile ] && echo "system: $sman" >> $outFile
	systemResult="0"
else
	echo "        System Manufacturer and Model: $sman $smod"
	[ $outFile ] && echo "system: $sman $smod" >> $outFile
	os=`cat $featuresPath/os.tmp`
	osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
	[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
	if [ ! -z "$osEquiv" ]; then
		if echo "$os" | grep "opensuse"; then
			"Checking appropriate SLE certifications..."
		fi
		os="$osEquiv"
	fi
        osId=`echo $os | cut -d'_' -f1`
        osVerId=`echo $os | cut -d'_' -f2`
	osArch=`echo $os | cut -d'_' -f1,2 --complement`
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
		certsFromModels=`python3 $SCA_BIN_PATH/knn.py $featuresPath/system-model.tmp $datasetsPath/certs.dat $datasetsPath/system-model-$osToCheck.dat "jaccard" "true"`
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
		if echo "$os" | grep -q "opensuse-leap"; then
			systemResult="0"
		else
			systemResult="1"
		fi
	else
		[ $outFile ] && echo "system-certs: none" >> $outFile
		systemResult="-1"
	fi
fi

[ $outFile ] && echo "system-result: $systemResult" >> "$outFile"
exit 0
