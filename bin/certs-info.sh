#!/bin/sh

#
# This script outputs information about YES certs
#
# Inputs: 1) path containing features files
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  certs, certs-result name-value pairs written to output file 
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
	[ $outFile ] && echo "certs: error" >> $outFile
	[ $outFile ] && echo "certs-result: 0" >> $outFile
	exit 1
fi

curPath=`dirname "$(realpath "$0")"`

# conf files (if not already set by calling program)
if [ -z "$SCA_HOME" ]; then
	mainConfFiles="${curPath}/../sca-L0.conf /etc/opt/sca/sca-L0.conf"
	for mainConfFile in ${mainConfFiles}; do
		if [ -r "$mainConfFile" ]; then
			found="true"
			source $mainConfFile
			break
		fi
	done
	if [ -z "$found" ]; then
		exitError "No sca-L0 conf file info; exiting..."
	fi
	extraConfFiles="${curPath}/../sca-L0+.conf /etc/opt/sca/sca-L0+.conf"
	for extraConfFile in ${extraConfFiles}; do
		if [ -r "$extraConfFile" ]; then
			source $extraConfFile
			break
		fi
	done
fi
[ $DEBUG ] && echo "*** DEBUG: $0: confFile: $confFile" >&2
binPath="$SCA_BIN_PATH"
datasetsPath="$SCA_DATASETS_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath, datasetsPath: $datasetsPath" >&2

# start 
echo ">>> Checking certifications..."
smod=`cat $featuresPath/system-model.tmp 2>/dev/null`
[ $DEBUG ] && echo "*** DEBUG: $0: smod: $smod" >&2
if [ -z "$smod" ]; then
	echo "        Error retrieving certification info"
	[ $outFile ] && echo "certs: error" >> $outFile
	[ $outFile ] && echo "certs-result: 0" >> $outFile
	exit 1
fi

# get os, equivalent os(es), and related os(es)
os=`cat $featuresPath/os.tmp 2>/dev/null`
osEquiv=`cat $featuresPath/os-equiv.tmp 2>/dev/null | tr '\n' ' '`
osRelated=`cat $featuresPath/os-related.tmp 2>/dev/null | tr '\n' ' '`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2

# verify that we have all req'd info to proceed; otherwise exit
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "certs: error" >> $outFile
	[ $outFile ] && echo "certs-result: 0" >> $outFile
	exit 1
fi
if [ ! -s "$datasetsPath/system-model.pkl" ] || [ ! -s "$datasetsPath/os.pkl" ] || [ ! -s "$datasetsPath/certs.dat" ]; then
        echo "        Error retrieving certification info"
        [ $outFile ] && echo "certs: error" >> $outFile
        [ $outFile ] && echo "certs-result: 0" >> $outFile
        exit 1
fi

# certs
# stage 1: os, stage 2: equivalent os(es), stage 3: related os(es)
osesToCheck="$os $osEquiv $osRelated"
[ $DEBUG ] && echo "*** DEBUG: $0: osesToCheck: $osesToCheck" >&2
matchFound="FALSE"
for osToCheck in $osesToCheck; do
	[ $DEBUG ] && echo "*** DEBUG: $0: osToCheck: $osToCheck" >&2
	echo $osToCheck > $featuresPath/osToCheck.tmp
	knnCombinedArgs="$datasetsPath/certs.dat $datasetsPath/system-model.pkl $featuresPath/system-model.tmp jaccard 0 1 $datasetsPath/os.pkl $featuresPath/osToCheck.tmp jaccard 0 1"
	[ $DEBUG ] && echo "*** DEBUG: $0: knnCombinedArgs: $knnCombinedArgs" >&2
	[ $DEBUG ] && echo "*** DEBUG: $0: initial bulletinIds: $bulletinIds" >&2
	if [ $DEBUG ]; then
		knnResult=`python3 $binPath/knn_combined.py -d $knnCombinedArgs`
	else
		knnResult=`python3 $binPath/knn_combined.py $knnCombinedArgs 2>/dev/null`
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
		[ $outFile ] && echo "certs: $certURLs" >> $outFile
		if echo "$os" | grep -q "$osToCheck" || echo $osEquiv | grep "$osToCheck"; then
			[ $outFile ] && echo "certs-result: 1" >> $outFile
		else
			[ $outFile ] && echo "certs-result: 0" >> $outFile
		fi
		break
	fi
done
if [ "$matchFound" = "FALSE" ]; then
	echo "        No certifications"
	[ $outFile ] && echo "certs: none" >> $outFile
	[ $outFile ] && echo "certs-result: -1" >> $outFile
fi

exit 0
