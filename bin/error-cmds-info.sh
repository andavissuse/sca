#!/bin/sh

#
# This script outputs information about commands that generated errors.
#
# Inputs: 1) path containing features files
#	  2) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  error-cmds, error-cmd-pkgs, error-cmd-pkg-status
#	  name-value pairs written to output file
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path [output-file]"
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
[ $DEBUG ] && echo "*** DEBUG: $0: featuresPath: $featuresPath, outFile: $outFile" >&2

if [ ! -d "$featuresPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
	echo "$0: features path $featuresPath or output file $outFile does not exist, exiting..." >&2
	[ $outFile ] && echo "error-cmds: error" >> $outFile
	[ $outFile ] && echo "error-cmds-result: 0" >> $outFile
	exit 1
fi

# conf files
curPath=`dirname "$(realpath "$0")"`
mainConfFile="/usr/etc/sca-L0.conf"
extraConfFiles=`find /usr/etc -name "sca-L0?.conf"`
if [ ! -r "$mainConfFile" ]; then
        mainConfFile="/etc/sca-L0.conf"
        extraConfFiles=`find /etc -name "sca-L0?.conf"`
        if [ ! -r "$mainConfFile" ]; then
                mainConfFile="$curPath/../sca-L0.conf"
                extraConfFiles=`find $curPath/.. -name "sca-L0?.conf"`
                if [ ! -r "$mainConfFile" ]; then
                        exitError "No sca-L0 conf file info; exiting..."
                fi
        fi
fi
source $mainConfFile
for extraConfFile in $extraConfFiles; do
        source ${extraConfFile}
done
binPath="$SCA_BIN_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: binPath: $binPath" >&2

# start
echo ">>> Checking error message commands..."
rm $featuresPath/msgs.tmp $featuresPath/smsgs.tmp 2>/dev/null
for dataType in $SCA_ERROR_CMDS_DATATYPES; do
	cat $featuresPath/"$dataType".tmp >> $featuresPath/msgs.tmp
done
if [ ! -s "$featuresPath/msgs.tmp" ]; then
	echo "        No error messages in supportconfig messages.txt file"
	[ $outFile ] && echo "error-cmds: none" >> $outFile
	[ $outFile ] && echo "error-cmds-result: 1" >> $outFile
	exit 0
fi
[ $DEBUG ] && echo "*** DEBUG: $0: $featuresPath/msgs.tmp:" >&2
[ $DEBUG ] && cat $featuresPath/msgs.tmp >&2
cat $featuresPath/msgs.tmp | sort -u > $featuresPath/smsgs.tmp
[ $DEBUG ] && echo "*** DEBUG: $0: $featuresPath/smsgs.tmp:" >&2
[ $DEBUG ] && cat $featuresPath/smsgs.tmp >&2
cmds=""
while IFS= read -r cmd; do
	cmds="$cmds $cmd"
done < $featuresPath/smsgs.tmp
cmds=`echo $cmds | sed "s/^ //"`
[ $DEBUG ] && echo "*** DEBUG: $0: cmds: $cmds" >&2
[ $outFile ] && echo "error-cmds: $cmds" >> $outFile

# packages and status
os=`cat $featuresPath/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	for cmd in $cmds; do
		[ $outFile ] && echo "error-cmds-pkgs-$cmd: error" >> $outFile
	done
	[ $outFile ] && echo "error-cmds-result: 0" >> $outFile
	exit 1
fi
osEquiv=`$binPath/os-other.sh $os equiv`
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
if [ ! -z "$osEquiv" ]; then
	os="$osEquiv"
fi
for cmd in $cmds; do
	echo "        Error message generated by: $cmd"
	if echo $cmd | grep -q "^kernel"; then
		kern=`cat $featuresPath/kernel.tmp`
       		kVer=`echo $kern | sed 's/-[a-z]*$//'`
       		flavor=`echo $kern | sed "s/$kVer-//"`
		cmdPkgNames="kernel-$flavor"
	else
		sleCmdPkgNames=`grep "/$cmd " $SCA_SUSEDATA_PATH/rpmfiles-$os.txt 2>/dev/null | cut -d" " -f2 | sort -u | tr '\n' ' '`
		[ $DEBUG ] && echo "*** DEBUG: $0: sleCmdPkgNames: $sleCmdPkgNames" >&2
		if ! ls $SCA_SUSEDATA_PATH/rpmfiles-"$os".txt >/dev/null 2>&1; then 
			echo "            No package info for $cmd"
			[ $outFile ] && echo "error-cmds-pkgs-$cmd: error" >> $outFile
			errorState="TRUE"
			continue
		fi
		scCmdPkgNames=""
		for sleCmdPkgName in $sleCmdPkgNames; do
			if scCmdPkgName=`grep "^$sleCmdPkgName " $featuresPath/rpm.txt | cut -d" " -f1`; then
				scCmdPkgNames="$scCmdPkgNames $scCmdPkgName"
			fi
		done
		[ $DEBUG ] && echo "*** DEBUG: $0: scCmdPkgNames: $scCmdPkgNames" >&2
		cmdPkgNames=""
		for i in $scCmdPkgNames; do
			if echo $i | grep -q "$cmd"; then
				if [ "$i" = "$cmd" ]; then
					cmdPkgNames="$i"
					break
				else
					cmdPkgNames="$cmdPkgNames $i"
				fi
			fi
		done
		if [ -z "$cmdPkgNames" ]; then
			cmdPkgNames="$scCmdPkgNames"
		fi
	fi
	[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgNames: $cmdPkgNames" >&2
	if [ -z "$cmdPkgNames" ]; then
		echo "            No package info for $cmd"
		[ $outFile ] && echo "error-cmds-pkgs-$cmd: error" >> $outFile
		errorState="TRUE"
	else
		cmdPkgs=""
		for cmdPkgName in $cmdPkgNames; do
			[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgName: $cmdPkgName" >&2
			if [ "$cmdPkgName" = "kernel-$flavor" ]; then
				cmdPkgVer="$kVer"
			else
				cmdPkgVer=`grep "^$cmdPkgName " $featuresPath/rpm.txt | rev | cut -d" " -f1 | rev`
			fi
			cmdPkgs="$cmdPkgs $cmdPkgName-$cmdPkgVer"
		done
		cmdPkgs=`echo $cmdPkgs | sed "s/^ //"`
		[ $outFile ] && echo "error-cmds-pkgs-$cmd: $cmdPkgs" >> $outFile
		for cmdPkg in $cmdPkgs; do
			[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkg: $cmdPkg" >&2
			echo "            $cmd package: $cmdPkg"
			cmdPkgName=`echo $cmdPkg | rev | cut -d"-" -f1,2 --complement | rev`
			cmdPkgVer=`echo $cmdPkg | rev | cut -d"-" -f1,2 | rev`
			[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgName: $cmdPkgName, cmdPkgVer: $cmdPkgVer" >&2
			cmdPkgCur=`grep "^$cmdPkgName-[0-9]" $SCA_SUSEDATA_PATH/rpms-$os.txt 2>/dev/null | tail -1 | sed "s/\.rpm$//" | sed "s/\.noarch$//" | sed "s/\.${arch}$//"`
			if ! ls $SCA_SUSEDATA_PATH/rpms-"$os".txt >/dev/null 2>&1; then
				echo "                No current rpm version info for $cmdPkgName"
				[ $outFile ] && echo "error-cmds-pkg-status-$cmdPkg: error" >> $outFile
				errorState="TRUE"
				continue
			fi
			cmdPkgCurVer=`echo $cmdPkgCur | sed "s/${cmdPkgName}-//"`
			[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgCur: $cmdPkgCur, cmdPkgCurVer: $cmdPkgCurVer" >&2
			if [ -z "$cmdPkgCurVer" ]; then
				echo "                Error retrieving version info for $cmdPkgName"
				[ $outFile ] && echo "error-cmds-pkg-status-$cmdPkg: error" >> $outFile
				errorState="TRUE"
			elif ! echo "$cmdPkgCur" | grep -q "$cmdPkgVer"; then
				echo "                $cmdPkgName-$cmdPkgVer package status: downlevel (current version: $cmdPkgCur)"
				[ $outFile ] && echo "error-cmds-pkg-status-$cmdPkg: downlevel" >> $outFile
				downlevelState="TRUE"
			else
				echo "                $cmdPkgName-$cmdPkgVer package status: current"
				[ $outFile ] && echo "error-cmds-pkg-status-$cmdPkg: current" >> $outFile
			fi
		done
	fi
done < $featuresPath/smsgs.tmp

if [ "$errorState" = "TRUE" ] || [ "$downlevelState" = "TRUE" ] ; then
	errorCmdsResult="0"
else
	errorCmdsResult="-1"
fi
[ $outFile ] && echo "error-cmds-result: $errorCmdsResult" >> "$outFile"
exit 0
