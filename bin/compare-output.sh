#!/bin/sh

#
# This script compares 2 sca-L0 output files and reports on
# differences.
#
# Inputs: 1) 2 or more sca-L0 output files
#
# Output: csv-separated data
#

#
# preset variables
#
categories="os system kernel kmods warning-cmds error-cmds srs bugs"

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] [ -c categories (comma-separated)] [-o csv-output-file] sca-L0-output-file1 sca-L0-output-file2 [ sca-L0-output-file3 ] ..."
	echo "       Categories: os system kernel kmods warning-cmds error-cmds srs bugs"
        exit $1
}

# arguments
if [ "$1" = "--help" ]; then
        usage 0
fi
while getopts 'hdc:o:' OPTION; do
        case $OPTION in
                h)
                        usage 0
                        ;;
                d)
                        DEBUG=1
                        ;;
		c)
			categories=`echo $OPTARG | tr ',' ' '`
			;;
		o)
			outFile="$OPTARG"
			if [ -f "$outFile" ]; then
				echo "Output file $outFile already exists, exiting..."
				exit 1
			fi
			;;
        esac
done
shift $((OPTIND - 1))
if [ ! "$2" ]; then
        usage 1
fi
declare -a scaFiles="$@"
for scaFile in $scaFiles; do
	if [ ! -f $scaFile ]; then
		echo "sca-L0 output file $scaFile does not exist, exiting..."
		exit 1
	fi
done
[ $DEBUG ] && echo "*** DEBUG: $0: categories: $categories"
[ $DEBUG ] && echo "*** DEBUG: $0: scaOutFiles: $scaOutFiles"

# Required fields (always in sca-L0 output)
scaFields="sca-l0-timestamp sca-l0-version sca-l0-default-checks"
supportconfigFields="supportconfig supportconfig-date"

# Optional fields (may be in sca-L0 output)
osFields="os os-support"
systemFields="system system-certs"
kernelFields="kernel kernel-status"
kmodsFields="kmods-externally-supported kmods-unsupported"
warningcmdsFields="warning-cmds"
errorcmdsFields="error-cmds"
srsFields="srs"
bugsFields="bugs"

# Build fields list
fields="$scaFields $supportconfigFields"
for field in $categories; do
	if [ "$field" = "warning-cmds" ]; then
		fieldNoHyphen="warningcmds"
	elif [ "$field" = "error-cmds" ]; then
		fieldNoHyphen="errorcmds"
	else
		fieldNoHyphen="$field"
	fi
	declare newFields=${fieldNoHyphen}Fields
	fields="$fields ${!newFields}"
done
[ $DEBUG ] && echo "*** DEBUG: $0: fields: $fields"

hdr="field,`echo $scaFiles | tr ' ' ','`"
[ $DEBUG ] && echo "*** DEBUG: $0: hdr: $hdr"
if [ -z "$outFile" ]; then
	echo "$hdr"
else
	echo "$hdr" >> "$outFile"
fi

for field in $fields; do
	[ $DEBUG ] && echo "*** DEBUG: $0: field: $field"
	fieldVals=""
	for scaFile in $scaFiles; do
		fieldVal=""
		case $field in
			sca-l0-version)
				fieldVal=`grep -E "^sca-l0-version:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			sca-l0-default-checks)
				fieldVal=`grep -E "^sca-l0-default-checks:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			supportconfig)
				fieldVal=`grep -E "^supportconfig:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			supportconfig-date)
				fieldVal=`grep -E "^supportconfig-date:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			os)
				fieldVal=`grep -E "^os:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			os-support)
				fieldVal=`grep -E "^support-status:|^os-support:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			system)
				fieldVal=`grep -E "^system:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			system-certs)
				fieldVal=`grep -E "^system-bulletin:|^system-cert[s]?:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
			kernel)
				fieldVal=`grep -E "^kernel:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			kernel-status)
				fieldVal=`grep -E "^kernel-status:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
				;;
			kmods-externally-supported)
				fieldVal=`grep -E "^kmod[s]?-externally-supported:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
			kmods-unsupported)
				fieldVal=`grep -E "^kmod[s]?-unsupported:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
			warning-cmds)
				fieldVal=`grep -E "^warning-command:|^warning-cmds:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
			error-cmds)
				fieldVal=`grep -E "^error-command:|^error-cmds:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
			srs)
				fieldVal=`grep -E "^sr[s]?:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
			bugs)
				fieldVal=`grep -E "^bug[s]?:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
				;;
		esac
		[ $DEBUG ] && echo "*** DEBUG: $0: fieldVal: $fieldVal"
		fieldVals="$fieldVals,$fieldVal"
	done
	fieldVals=`echo $fieldVals | sed "s/^,//"`
	[ $DEBUG ] && echo "*** DEBUG: $0: fieldVals: $fieldVals"
	if [ -z "$outFile" ]; then
		echo "$field,$fieldVals"
	else
		echo "$field,$fieldVals" >> $outFile
	fi
	case $field in
		warning-cmds|error-cmds)
			msgType=`echo "$field" | cut -d"-" -f1`
			allCmds=`echo "$fieldVals" | tr ',' ' ' | sed "s/NA//g" | sed "s/no-info//g" | sed "s/none//g"`
			[ $DEBUG ] && echo "*** DEBUG: $0: allCmds: $allCmds"
			processedCmds=""
			for cmd in $allCmds; do
				[ $DEBUG ] && echo "*** DEBUG: $0: processedCmds: $processedCmds"
				if echo $processedCmds | grep -q -E "^$cmd;|;$cmd;|;$cmd$"; then
					continue
				fi
				[ $DEBUG ] && echo "*** DEBUG: $0: cmd: $cmd"
				cmdPkgsField="$field-pkgs-$cmd"
				cmdPkgs=""
				for scaFile in $scaFiles; do
					tsCmdPkgs=`grep -E "^$field-pkgs-$cmd:|^$msgType-command-$cmd-package:" $scaFile | cut -d":" -f1 --complement | tr '\n' ' ' | sed "s/^ //" | sed "s/ $//"`
					cmdPkgs="$cmdPkgs,$tsCmdPkgs"
				done
				cmdPkgs=`echo $cmdPkgs | sed "s/,//"`
				[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgs: $cmdPkgs"
				if [ -z "$outFile" ]; then
					echo "$cmdPkgsField,$cmdPkgs"
				else
					echo "$cmdPkgsField,$cmdPkgs" >> $outFile
				fi
				pkgs=`echo $cmdPkgs | tr ',' ' ' | sed "s/NA//g" | sed "s/no-info//g" | sed "s/none//g"`
				pkgNum=0
				processedPkgs=""
				for pkg in $pkgs; do
					if echo $processedPkgs | grep -q -E "^$pkg;|;$pkg;|;$pkg$"; then
						continue
					fi
					[ $DEBUG ] && echo "*** DEBUG: $0: msgType: $msgType, cmd: $cmd, pkg: $pkg"
					pkgNum=$((pkgNum + 1))
					cmdPkgStatusField="$field-pkg-status-$pkg"
					cmdPkgStatuses=""
					for scaFile in $scaFiles; do
						tsCmdPkgStatus=`grep "$field-pkg-status-$pkg:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
                                                if [ -z "$tsCmdPkgStatus" ]; then
                                                        tsCmdPkgLineNum=`grep -n "$msgType-command-$cmd-package: $pkg" $scaFile | cut -d":" -f1`
                                                        [ $DEBUG ] && echo "*** DEBUG: $0: tsCmdPkgLineNum: $tsCmdPkgLineNum"
                                                        if [ ! -z "$tsCmdPkgLineNum" ]; then
                                                                tsCmdPkgStatusLineNum=$((tsCmdPkgLineNum + 1))
                                                                [ $DEBUG ] && echo "*** DEBUG: $0: tsCmdPkgStatusLineNum: $tsCmdPkgStatusLineNum"
                                                                tsCmdPkgStatus=`sed -n "${tsCmdPkgStatusLineNum}p" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
                                                        else
                                                                tsCmdPkgStatus=""
                                                        fi
                                                fi
                                                [ $DEBUG ] && echo "*** DEBUG: $0: tsCmdPkgStatus: $tsCmdPkgStatus"
                                                cmdPkgStatuses="$cmdPkgStatuses,$tsCmdPkgStatus"
						[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgStatuses: $cmdPkgStatuses"
					done
					cmdPkgStatuses=`echo "$cmdPkgStatuses" | sed "s/^,//"`
					[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgStatuses: $cmdPkgStatuses"
					if [ -z "$outFile" ]; then
						echo "$cmdPkgStatusField,$cmdPkgStatuses"
					else
						echo "$cmdPkgStatusField,$cmdPkgStatuses" >> $outFile
					fi
					processedPkgs="$processedPkgs;$pkg"
				done
				processedCmds="$processedCmds;$cmd"
			done
			;;
		srs|bugs)
			srBugType=`echo "$field" | sed "s/s$//"`
			srsBugs=`echo $fieldVals | tr ',' ' ' | sed "s/[^0-9 ]*//g"`
			processedSrBugs=""
			for srBug in $srsBugs; do
				[ $DEBUG ] && echo "*** DEBUG: $0: srBug: $srBug"
				if echo $processedSrBugs | grep -q -E "^$srBug;|;$srBug;|;$srBug$"; then
					break
				fi
				srBugScoreField="$field-score-$srBug"
				srBugScores=""
				for scaFile in $scaFiles; do
					srBugScore=`grep "$field-score-$srBug:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
					if [ -z "$srBugScore" ]; then
						srBugScore=`grep "$srBugType-$srBug-score:" $scaFile | cut -d":" -f1 --complement | sed "s/^ //"`
					fi
					srBugScores="$srBugScores,$srBugScore"
					[ $DEBUG ] && echo "*** DEBUG: $0: srBugScores: $srBugScores"
				done
				srBugScores=`echo "$srBugScores" | sed "s/^,//"`
				if [ -z "$outFile" ]; then
					echo "$srBugScoreField,$srBugScores"
				else
					echo "$srBugScoreField,$srBugScores" >> $outFile
				fi
				processedSrBugs="$processedSrBugs;$srBug"
			done
			;;
		*)
			;;
	esac
done
