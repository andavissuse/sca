#!/bin/sh

#
# This is the sca script that outputs L0-related information
# such as supportability, hardware certs, existence of srs, etc.
# Default path for datasets is ../datasets and default path for
# susedata is ../susedata, but these may be overridden with
# optional arguments.
#
# Inputs: (optional with -p) path to datasets
#	  (optional with -s) path to susedata
#	  (optional w/ -t) tmp path (for uncompressing supportconfig)
#         (optional with -o) output file for terse report (in addition to stdout)
#	  supportconfig tarball 
#	  parameters-to-check (os, system, kernel, kmods, warning-cmds, error-cmds, srs, bugs)
#
# Output: Various info about supportconfig
#

#
# functions
#
function usage() {
	echo "Usage: `basename $0` [-d(ebug)]"
	echo "                 [-v(ersion)]"
	echo "                 [-c(ategories) - comma-separated list of categories to check (default checks all)]"
	echo "                     categories: os system kernel kmods warning-cmds error-cmds srs bugs" 
	echo "                 [-p datasets-path]"
	echo "                 [-s susedata-path]"
	echo "                 [-t tmp-path]"
	echo "                 [-o outfile (short-form output)]"
	echo "                 supportconfig-tarfile"
	echo "                 Example: sca-L0.sh -f os,srs -o /tmp/sca-L0.out /var/log/supportconfig.tgz"
}

function log() {
	printf '%s\n' "$1"
}

function logToFile() {
	printf '%s\n' "$1" >> "$2" 2>/dev/null
	if [ "$?" -eq "1" ]; then
		log "WARNING: Cannot write to $outFile, disabling -o output."
		outFile=""
	fi
}

function exitError() {
	log "$1"
	rm -rf $tmpDir 2>/dev/null
	exit 1
}

function untarAndCheck() {
	log ">>> Uncompressing $scTar..."
	scTarName=`basename $scTar`
	[ $outFile ] && logToFile "supportconfig: $scTarName" $outFile
	if ! tar xf "$scTar" -C "$tmpDir" --strip-components=1 2>/dev/null; then
        	exitError "Uncompression of $scTar failed, check file for corruption.  Exiting..."
	fi
	# check for basic files
	summaryFile="$tmpDir/summary.xml"
	basicEnvFile="$tmpDir/basic-environment.txt"
	if [ -z "$summaryFile" ] || [ -z "basicEnvFile" ]; then
        	exitError "Supportconfig file does not contain summary.xml and basic-environment.txt files, exiting..."
	fi
	# check arch
	arch=`grep -m 1 "<arch>" $summaryFile | sed 's:.*<arch>\(.*\)</arch>.*:\1:'`
	[ $DEBUG ] && log "*** DEBUG: $0: arch: $arch"
#	if [ "$arch" != "x86_64" ] && [ "$arch" != "aarch64" ]; then
#        	exitError "Unsupported architecture, exiting..."
#	fi
	# check OS and version
	etcReleaseID=`grep -m 1 "^ID=" $basicEnvFile | cut -d'=' -f2 | sed 's/\"//g'`
	[ $DEBUG ] && log "*** DEBUG: $0: etcReleaseID: $etcReleaseID"
	if [ "$etcReleaseID" = "sles" ] || [ "$etcReleaseID" = "sled" ]; then
		osName=`echo "$etcReleaseID" | tr [:lower:] [:upper:]`
        elif [ "$etcReleaseID" = "suse-microos" ]; then
                osName="SLE Micro"
	elif [ "$etcReleaseID" = "caasp" ]; then
		osName="CaaSP"
	elif [ "$etcReleaseID" = "opensuse-leap" ]; then
		osName="openSUSE Leap"
	else
		exitError "Unsupported OS, exiting..."
	fi
	[ $DEBUG ] && log "*** DEBUG: $0: osName: $osName"
#	osVerMajor=`grep -m 1 "<sle_version>" $summaryFile | sed 's:.*<sle_version>\(.*\)</sle_version>.*:\1:'`
#	osVerMinor=`grep -m 1 "sle_patchlevel>" $summaryFile | sed 's:.*<sle_patchlevel>\(.*\)</sle_patchlevel>.*:\1:'`
#	osVer="$osVerMajor.$osVerMinor"
#	osVerSP="$osVerMajor-SP$osVerMinor"
#	osVerSPStr="$osVerMajor SP$osVerMinor"
        osVer=`grep -m 1 "^VERSION_ID=" $basicEnvFile | cut -d"=" -f2 | sed 's/\"//g'`
	if [ "$osVer" = "15" ]; then
		osVer="$osVer.0"
	fi
	osVerSP=`grep -m 1 "^VERSION=" $basicEnvFile | cut -d"=" -f2 | sed 's/\"//g'`
	if [ "$osVerSP" = "15" ]; then
		osVerSP="$osVerSP-SP0"
	fi
	osVerSPStr=`echo "$osVerSP" | sed "s/-/ /g"`
	osVerMajor=`echo "$osVer" | cut -d"." -f1`
	osVerMinor=`echo "$osVer" | cut -d"." -f2`
	[ $DEBUG ] && log "*** DEBUG: $0: arch: $arch, osVer: $osVer, osVerSP: $osVerSP, osVerSPStr: $osVerSPStr, osVerMajor: $osVerMajor, osVerMinor: $osVerMinor"
	if [ "$osName" = "SLE Micro" ] && [ "$osVer" = "5.0" ]; then
		osTag="sle15.2.$arch"
	elif [ "$osName" = "CaaSP" ] && [ "$osVer" = "3.0" ]; then
		osTag="sle12.3.$arch"
	elif [ "$osName" = "openSUSE Leap" ] && [ "$osVer" = "15.2" ]; then
		osTag="sle15.2.$arch"
	elif ([ "$osVerMajor" = "15" ] && echo $osVerMinor | grep -q "^[012]$" ) || ([ "$osVerMajor" = "12" ] && echo "$osVerMinor" | grep -q "^[345]$" ); then
		osTag="sle$osVerMajor.$osVerMinor.$arch"
	else
		exitError "Unsupported OS, exiting..."
	fi
	[ $DEBUG ] && log "*** DEBUG: $0: osTag: $osTag"
}

function hardwareId() {
	[ -f "$tmpDir"/systemd.txt ] && machineId=`grep "Machine ID:" "$tmpDir"/systemd.txt | cut -d":" -f2 | sed "s/^ *//"`
	[ $DEBUG ] && log "*** DEBUG: $0: machineId: $machineId"
	if [ -z "$machineId" ]; then
		log ">>> Machine ID: Missing machine ID info in supportconfig"
	else
		log ">>> Machine ID: $machineId"
		[ $outFile ] && logToFile "machine-id: $machineId" $outFile
	fi
}

function extractScInfo() {
	log ">>> Extracting info from supportconfig..."
	for dataType in $SCA_ALL_DATATYPES; do
		"$SCA_BIN_PATH"/"$dataType".sh "$tmpDir" > "$tmpDir"/"$dataType".tmp
	done
	"$SCA_BIN_PATH"/basic-health.sh "$tmpDir" > $tmpDir/basic-health.tmp
}

function supportconfigDate() {
	scDateLine=`grep -n -m 1 "# /bin/date" $basicEnvFile | cut -d":" -f1`
	scDate=`sed -n "$((${scDateLine} + 1))p" $basicEnvFile`
	log ">>> Supportconfig date: $scDate"
	[ $outFile ] && logToFile "supportconfig-date: $scDate" $outFile
}

function os() {
	log ">>> Checking OS version supportability..."
	if [ "$osName" = "SLES" ] || [ "$osName" = "SLED" ]; then
		log "        OS: $osName $osVerSPStr"
		[ $outFile ] && logToFile "os: $osName $osVerSPStr" $outFile
	elif [ "$osName" = "SLE Micro" ] || [ "$osName" = "CaaSP" ] || [ "$osName" = "openSUSE Leap" ]; then
        	log "        OS: $osName $osVer"
        	[ $outFile ] && logToFile "os: $osName $osVer" $outFile
	else
        	log "        OS: No info available"
        	[ $outFile ] && logToFile "os: no-info" $outFile
	fi
	lifecycleInfo=`grep "$osName"-"$osVerSP" $susedataPath/lifecycles.csv`
	[ $DEBUG ] && log "*** DEBUG: $0: lifecycleInfo: $lifecycleInfo"
	if [ -z "$lifecycleInfo" ]; then
		log "        No lifecycle data available."
		[ $outFile ] && logToFile "os-support: no-info" $outFile
	else
        	endLtss=`echo $lifecycleInfo | grep "$osName"-"$osVerSP" | cut -d"," -f4`
        	endLtssStr=`date -d$endLtss +%Y-%m-%d 2>/dev/null`
        	[ $DEBUG ] && log "*** DEBUG: $0: endLtss: $endLtssStr"
        	endGeneral=`echo $lifecycleInfo | grep "$osName"-"$osVerSP" | cut -d"," -f3`
        	endGeneralStr=`date -d$endGeneral +%Y-%m-%d 2>/dev/null`
        	[ $DEBUG ] && log "*** DEBUG: endGeneral is $endGeneralStr"
        	if (( curDate > endLtss )); then
                	log "        Support status: Custom support contract required"
                	[ $outFile ] && logToFile "os-support: out-of-support" $outFile
			osResult=-1
        	elif (( curDate > endGeneral )); then
                	log "        Support status: LTSS support contract required"
                	[ $outFile ] && logToFile "os-support: ltss" $outFile
			osResult="0"
        	else
                	log "        Support status: Supported"
                	[ $outFile ] && logToFile "os-support: supported" $outFile
			osResult="1"
        	fi
	fi
}

function kernelInfo() {
	kern=`cat $tmpDir/kernels.tmp`
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: kernel is $kern"
	kVer=`echo $kern | sed 's/-[a-z]*$//'`
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: kVer is $kVer"
	flavor=`echo $kern | sed "s/$kVer-//"`
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: flavor is $flavor"
	kPkg="kernel-$flavor-$kVer"
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: kPkg is $kPkg"
}

function kernel() {
	log ">>> Checking kernel..."
	if [ -z "$kern" ] || [ -z "$kVer" ] || [ -z "$flavor" ] || [ -z "$kPkg" ]; then
		kernelInfo
	fi
	kern=`cat $tmpDir/kernels.tmp`
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: kernel is $kern"
	kVer=`echo $kern | sed 's/-[a-z]*$//'`
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: kVer is $kVer"
	flavor=`echo $kern | sed "s/$kVer-//"`
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: flavor is $flavor"
	kPkg="kernel-$flavor-$kVer"
	[ $DEBUG ] && log "*** DEBUG: sca-L0.sh: kPkg is $kPkg"
	log "        Kernel: $kern"
	[ $outFile ] && logToFile "kernel: $kern" $outFile
	kPkgCur=`grep "kernel-$flavor-[0-9]" $susedataPath/rpms-$osTag.txt | tail -1`
	[ $DEBUG ] && log "*** DEBUG: kPkgCur is $kPkgCur"
	kVerCur=`echo $kPkgCur | sed "s/^kernel-$flavor-//" | sed 's/\.${arch}\.rpm//'`
	if ! grep $kPkg $susedataPath/rpms-$osTag.txt >/dev/null; then
        	log "        Kernel version is not an official SUSE kernel"
        	[ $outFile ] && logToFile "kernel-status: non-suse-kernel" $outFile
		kernelResult=-1
	elif ! echo "$kPkgCur" | grep "$kVer" >/dev/null; then
        	log "        Support status: Downlevel (current version: $kVerCur)"
        	[ $outFile ] && logToFile "kernel-status: downlevel" $outFile
	else
        	log "        Support status: Current"
        	[ $outFile ] && logToFile "kernel-status: current" $outFile
		kernelResult=1
	fi
}

function kmods() {
	log ">>> Checking kernel modules..."
	taintVal=`grep "taint:" $tmpDir/basic-health.tmp`
	if grep -q "taint:X" $tmpDir/basic-health.tmp; then
		[ $DEBUG ] && echo "*** DEBUG: $0: Found taint:X"
		modsExt=""
        	while IFS= read -r mod; do
			modsExt="$modsExt $mod"
			[ $DEBUG ] && echo "*** DEBUG: $0: modsExt: $modsExt"
        	done < $tmpDir/kmods-external.tmp
		log "        Externally-supported kernel modules loaded: $modsExt"
		[ $outFile ] && logToFile "kmods-externally-supported: $modsExt" $outFile
	else
		log "        No externally-supported kernel modules loaded"
		[ $outFile ] && logToFile "kmods-externally-supported: none" $outFile
		kmodsResult=1
	fi
	if grep "taint:N" $tmpDir/basic-health.tmp >/dev/null; then
		modsUnsupported=""
        	while IFS= read -r mod; do
			modsUnsupported="$modsUnsupported $mod"
			[ $DEBUG ] && echo "*** DEBUG: $0: modsUnsupported: $modsUnsupported"
		done < $tmpDir/kmods-unsupported.tmp
                log "        Unsupported kernel modules loaded: $modsUnsupported"
		[ $outFile ] && logToFile "kmods-unsupported: $modsUnsupported" $outFile
		kmodsResult=-1
	else	
        	log "        No unsupported kernel modules loaded"
		[ $outFile ] && logToFile "kmods-unsupported: none" $outFile
	fi
}

function systemInfo() {
	log ">>> Checking system and certifications..."
	[ -f "$tmpDir"/system-manufacturers.tmp ] && sman=`cat $tmpDir/system-manufacturers.tmp`
	[ -f "$tmpDir"/system-models.tmp ] && smod=`cat $tmpDir/system-models.tmp`
	[ $DEBUG ] && log "*** DEBUG: $0: sman: $sman, smod: $smod"
	if [ -z "$sman" ] || [ -z "$smod" ]; then
        	log "        Missing system manufacturer and/or model info in supportconfig"
		[ $outFile ] && logToFile "system: no-info" $outFile
	elif echo "$sman" | grep -q -E "QEMU|Xen"; then
        	if echo "$sman" | grep -q QEMU; then
                	sman="KVM"
        	fi
        	log "        System is a $sman virtual machine running on SLES; no hardware certifications"
        	[ $outFile ] && logToFile "system: $sman" $outFile
	else
        	log "        System Manufacturer and Model: $sman $smod"
        	[ $outFile ] && logToFile "system: $sman $smod" $outFile
        	if [ "$osName" = "SLE Micro" ] || [ "$osName" = "CaaSP" ] || [ "$osName" = "openSUSE Leap" ]; then
                	log "        Searching applicable SLE certifications for $osName..."
        	fi
        	verMajorToCheck=`echo "$osTag" | cut -d"." -f1 | sed "s/^sle//"`
        	verMinorToCheck=`echo "$osTag" | cut -d"." -f2`
        	if [ "$osVerMajor" = "12" ]; then
                	verMinorBase="3"
        	else
                	verMinorBase="0"
        	fi
		foundCert="FALSE"
        	while (( verMinorToCheck >= verMinorBase )); do
                	tagToCheck="sle$verMajorToCheck.$verMinorToCheck.$arch"
                	[ $DEBUG ] && log "*** DEBUG: $0: tagToCheck: $tagToCheck"
                	certsFromModels=`python3 $SCA_BIN_PATH/knn.py $tmpDir/system-models.tmp $datasetsPath/certs.dat $datasetsPath/system-models-$tagToCheck.dat "jaccard" "true"`
                	[ $DEBUG ] && log "*** DEBUG: $0: certsFromModels: $certsFromModels"
                	if [ "$certsFromModels" != "[]" ]; then
                        	certsMod=`echo $certsFromModels | sed "s/^\[//" | sed "s/\]$//" | sed "s/,//g" | sed "s/'//g"`
                        	[ $DEBUG ] && log "*** DEBUG: $0: certsMod: $certsMod"
                        	if [ ! -z "$certsMod" ]; then
                                	certs=`echo $certsMod | grep -E -o "[0-9]{6}" | sort -u | tr '\n' ' '`
                                	[ $DEBUG ] && log "*** DEBUG: $0: certs: $certs"
                                	if [ ! -z "$certs" ]; then
                                        	log "        YES Certification Bulletins for SLE $verMajorToCheck SP$verMinorToCheck:"
						certURLs=""
                                        	for bulletinId in $certs; do
							foundCert="TRUE"
							certURL="https://www.suse.com/nbswebapp/yesBulletin.jsp?bulletinNumber=$bulletinId"
							certURLs="$certURLs $certURL"
						done
						for certURL in $certURLs; do
                                                	log "            $certURL"
						done
                                	fi
                        	fi
                	else
                        	log "        YES certifications found for SLE $verMajorToCheck SP$verMinorToCheck: none"
                	fi
                	verMinorToCheck=$(( verMinorToCheck - 1 ))
       		done
		if [ "$foundCert" = "TRUE" ]; then
			certURLs=`echo $certURLs | sed "s/^ //"`
			[ $outFile ] && logToFile "system-certs: $certURLs" $outFile
			systemResult=1
		else
			[ $outFile ] && logToFile "system-certs: none" $outFile
		fi
#		Search linux-hardware.org
#		
	fi
}

function msgsCmds() {
	msgsCmdsResult=0
	msgsType="$1"
	log ">>> Checking $msgsType message commands..."
	[ $DEBUG ] && log "*** DEBUG: $0: msgsType: $msgsType"
	if [ "$msgsType" = "error" ]; then
		msgsDataTypes="$SCA_ERR_MSG_CMDS_DATATYPES"
	elif [ "$msgsType" = "warning" ]; then
		msgsDataTypes="$SCA_WARN_MSG_CMDS_DATATYPES"
	else
		log "        Unusupported message type"
	fi
        [ $DEBUG ] && log "*** DEBUG: $0: msgsDataTypes: $msgsDataTypes"
	if [ -z "$kVer" ] || [ -z "$flavor" ]; then
		kernelInfo
	fi
        rm $tmpDir/msgs.tmp $tmpDir/smsgs.tmp 2>/dev/null
        for dataType in $msgsDataTypes; do
                cat $tmpDir/"$dataType".tmp >> $tmpDir/msgs.tmp
        done
        if [ ! -s "$tmpDir/msgs.tmp" ]; then
                log "        No $msgsType messages in supportconfig messages.txt file"
		[ $outFile ] && logToFile "$msgsType-cmds: none" $outFile
		msgsCmdsResult=1
	else
		[ $DEBUG ] && echo "*** DEBUG: $0: $tmpDir/msgs.tmp:"
		[ $DEBUG ] && cat $tmpDir/msgs.tmp
        	cat $tmpDir/msgs.tmp | sort -u > $tmpDir/smsgs.tmp
		[ $DEBUG ] && echo "*** DEBUG: $0: $tmpDir/smsgs.tmp:"
		[ $DEBUG ] && cat $tmpDir/smsgs.tmp
		cmds=""
		while IFS= read -r cmd; do
			cmds="$cmds $cmd"
		done < $tmpDir/smsgs.tmp	
		cmds=`echo $cmds | sed "s/^ //"`
		[ $DEBUG ] && echo "*** $DEBUG: $0: cmds: $cmds"
		[ $outFile ] && logToFile "$msgsType-cmds: $cmds" $outFile
		for cmd in $cmds; do
			log "        $msgsType message generated by: $cmd"
			if echo $cmd | grep -q "^kernel"; then
				[ $DEBUG ] && log "*** DEBUG: $0: cmd is kernel"
				cmdPkgNames="kernel-$flavor"
			else
				sleCmdPkgNames=`grep "/$cmd " $susedataPath/rpmfiles-$osTag.txt | cut -d" " -f2 | sort -u | tr '\n' ' '`
				[ $DEBUG ] && log "*** DEBUG: $0: sleCmdPkgNames: $sleCmdPkgNames"
				scCmdPkgNames=""
				for sleCmdPkgName in $sleCmdPkgNames; do
					if scCmdPkgName=`grep "^$sleCmdPkgName " $tmpDir/rpm.txt | cut -d" " -f1`; then
						scCmdPkgNames="$scCmdPkgNames $scCmdPkgName"
					fi
				done
				[ $DEBUG ] && log "*** DEBUG: $0: scCmdPkgNames: $scCmdPkgNames"
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
			[ $DEBUG ] && log "*** DEBUG: $0: cmdPkgNames: $cmdPkgNames"
			if [ -z "$cmdPkgNames" ]; then
				log "            No package info for $cmd"
				[ $outFile ] && logToFile "$msgsType-cmds-pkgs-$cmd: no-info" $outFile
			else
				cmdPkgs=""
				for cmdPkgName in $cmdPkgNames; do
					[ $DEBUG ] && log "*** DEBUG: $0: cmdPkgName: $cmdPkgName"
					if [ "$cmdPkgName" = "kernel-$flavor" ]; then
						cmdPkgVer="$kVer"
					else
						cmdPkgVer=`grep "^$cmdPkgName " $tmpDir/rpm.txt | rev | cut -d" " -f1 | rev`
					fi
					cmdPkgs="$cmdPkgs $cmdPkgName-$cmdPkgVer"
				done
				cmdPkgs=`echo $cmdPkgs | sed "s/^ //"`
				[ $outFile ] && logToFile "$msgsType-cmds-pkgs-$cmd: $cmdPkgs" $outFile
				for cmdPkg in $cmdPkgs; do
					[ $DEBUG ] && log "*** DEBUG: $0: cmdPkg: $cmdPkg"
					log "            $cmd Package: $cmdPkg"
					cmdPkgName=`echo $cmdPkg | rev | cut -d"-" -f1,2 --complement | rev`
					cmdPkgVer=`echo $cmdPkg | rev | cut -d"-" -f1,2 | rev`
					[ $DEBUG ] && log "*** DEBUG: $0: cmdPkgName: $cmdPkgName, cmdPkgVer: $cmdPkgVer"
					cmdPkgCur=`grep "^$cmdPkgName-[0-9]" $susedataPath/rpms-$osTag.txt | tail -1 | sed "s/\.rpm$//" | sed "s/\.noarch$//" | sed "s/\.${arch}$//"`
					cmdPkgCurVer=`echo $cmdPkgCur | sed "s/${cmdPkgName}-//"`
					[ $DEBUG ] && log "*** DEBUG: $0: cmdPkgCur: $cmdPkgCur, cmdPkgCurVer: $cmdPkgCurVer"
					if [ -z "$cmdPkgCurVer" ]; then
						log "                No current version info for $cmdPkgName"
						[ $outFile ] && log "$msgsType-cmds-pkg-status-$cmdPkg: no-info" $outFile
					elif ! echo "$cmdPkgCur" | grep -q "$cmdPkgVer"; then
						log "                $cmdPkgName-$cmdPkgVer package status: Downlevel (current version: $cmdPkgCur)"
						[ $outFile ] && logToFile "$msgsType-cmds-pkg-status-$cmdPkg: downlevel" $outFile
					else
						log "                $cmdPkgName-$cmdPkgVer package status: Current"
						[ $outFile ] && logToFile "$msgsType-cmds-pkg-status-$cmdPkg: current" $outFile
					fi
				done
			fi
		done < $tmpDir/smsgs.tmp
		msgsCmdsResult=-1
	fi
	if [ "$msgsType" = "error" ]; then
		errCmdsResult="$msgsCmdsResult"
	elif [ "$msgsType" = "warning" ]; then
		warnCmdsResult="$msgsCmdsResult"
	fi
}

function srsBugs() {
	srsBugsResult=0
	srsBugsType="$1"
	if [ "$srsBugsType" = "srs" ]; then
		srsBugsTypeStr="SRs"
	elif [ "$srsBugsType" = "bugs" ]; then
		srsBugsTypeStr="bugs"
	fi
	singleType=`echo $srsBugsType | sed "s/s$//"`
	cutoffVal="0.8"
	cutoffStr="80%"
	log ">>> Finding $srsBugsType..."
	dataTypes=""
	for dataType in $SCA_SRS_BUGS_DATATYPES; do
        	if [ -s "$tmpDir"/"$dataType".tmp ] && [ -s "$datasetsPath"/"$dataType"-"$osTag".dat ]; then
                	dataTypes="$dataTypes $dataType"
        	fi
	done
	[ $DEBUG ] && log "*** DEBUG: $0: dataTypes: $dataTypes"
	dataTypeArgs=""
	for dataType in $dataTypes; do
		metricVar='$'`echo SCA_"${dataType^^}"_METRIC | sed "s/-/_/g"`
		eval metric=$metricVar
		weightVar='$'`echo SCA_"${dataType^^}"_WEIGHT | sed "s/-/_/g"`
		eval weight=$weightVar
		[ $DEBUG ] && echo "*** DEBUG: $0: metricVar: $metricVar, weightVar: $weightVar"
		dataTypeArg="$datasetsPath/$dataType-$osTag.dat $metric $weight"
		[ $DEBUG ] && echo "*** DEBUG: $0: dataTypeArg: $dataTypeArg"
        	dataTypeArgs="$dataTypeArgs $dataTypeArg"
	done
	dataTypeArgs=`echo $dataTypeArgs | sed "s/^ //"`
	[ $DEBUG ] && log "*** DEBUG: $0: dataTypeArgs: $dataTypeArgs"
	if [ -z "$dataTypeArgs" ]; then
        	log "        Unable to compare error/warning messages: no error/warning messages in supportconfig or no applicable datasets"
		[ $outFile ] && logToFile "$srsBugsType: no-info" $outFile
	else
                [ $DEBUG ] && log "*** DEBUG: $0: tmpDir: $tmpDir, datasetsPath: $datasetsPath, srsBugsType: $srsBugsType"
		idsScores=`python3 $SCA_BIN_PATH/knn_combined.py "$tmpDir" "$datasetsPath"/"$srsBugsType".dat $dataTypeArgs`
		[ $DEBUG ] && log "*** DEBUG: $0: idsScores: $idsScores"
		ids=""
		scores=""
		let numHighIds=0
		realIds=""
		isId="TRUE"
		for entry in `echo $idsScores | tr -d "[],'" | cut -d" " -f1-10`; do
			if [ "$isId" = "TRUE" ]; then
				id="$entry"
				isId="FALSE"
			else
				score="$entry"
				formattedScore=`printf "%0.2f" $score`
				ids="$ids $id"
				scores="$scores $formattedScore"
				if (( $(echo "$score >= $cutoffVal" | bc -l) )); then
					numHighIds=$(( numHighIds + 1 ))
					srsBugsResult=-1
				fi
				isId="TRUE"
			fi
		done
		ids=`echo $ids | sed "s/^ //"`
		scores=`echo $scores | sed "s/^ //"`
		[ $DEBUG ] && echo "*** DEBUG: $0: ids: $ids"
		[ $DEBUG ] && echo "*** DEBUG: $0: scores: $scores"
		[ $DEBUG ] && echo "*** DEBUG: $0: numHighIds: $numHighIds"
		if [ "$numHighIds" -eq "0" ]; then
			log "            No matching $srsBugsTypeStr found"
			[ $outFile ] && logToFile "$srsBugsType: none" $outFile
			srsBugsResult=1
		else
			log "        Found $numHighIds $srsBugsTypeStr with $cutoffStr or greater match"
			highIds=`echo $ids | cut -d" " -f1-${numHighIds}`
			[ $DEBUG ] && echo "*** DEBUG: $0: highIds: $highIds"
			[ $outFile ] && logToFile "$srsBugsType: $highIds" $outFile
			for index in $(seq 1 $numHighIds); do
				 highId=`echo $highIds | cut -d" " -f$index`
				 highScore=`echo $scores | cut -d" " -f$index`
				 log "             ID: $highId, Score: $highScore"
				 [ $outFile ] && logToFile "$srsBugsType-score-$highId: $highScore" $outFile
			done
			srsBugsResult=-1
		fi
	fi
	if [ "$srsBugsType" = "srs" ]; then
		srsResult="$srsBugsResult"
	elif [ "$srsBugsType" = "bugs" ]; then
		bugsResult="$srsBugsResult"
	fi
}

#
# main routine
#

# arguments
if [ "$1" = "--help" ]; then
	usage
	exit 0
fi
while getopts 'hdvc:p:s:t:o:' OPTION; do
        case $OPTION in
                h)
                        usage
			exit 0
                        ;;
                d)
                        DEBUG=1
                        ;;
		v)
			echo "$VERSION"
			exit 0
			;;
		c)
			categories=`echo $OPTARG | tr ',' ' '`
			;;	
		p)
			datasetsPath="$OPTARG"
			if [ ! -d "$datasetsPath" ]; then
				exitError "datasets path $datasetsPath does not exist, exiting..."
			fi
			;;
		s)
			susedataPath="$OPTARG"
			if [ ! -d "$susedataPath" ]; then
				exitError "susedata path $susedataPath does not exist, exiting..."
			fi
			;;
		t)
			tmpPath="$OPTARG"
			if [ ! -d "$tmpPath" ]; then
				exitError "tmp path $tmpPath does not exist, exiting..."
			fi
			;;
		o)
			outFile="$OPTARG"
			if [ -f "$outFile" ]; then
				exitError "Output file already exists, exiting..."
			fi
			if [ ! -d `dirname "$outFile"` ]; then
				exitError "output file path `dirname $outFile` does not exist, exiting..."
			fi
			;;
        esac
done
shift $((OPTIND - 1))
if [ ! "$1" ]; then
        usage
        exit 1
else
	scTar="$1"
fi

#
# read conf file
#
confFile="/usr/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="../sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
if [ -z "$SCA_HOME" ]; then
	exitError "No sca-L0.conf file info; exiting..."
fi
VERSION=`cat "$SCA_HOME"/version`

#
# set variables (command-line opts override conf file)
#
scaEnv="$SCA_ENV"
[ -z "$categories" ] && categories="$SCA_CATEGORIES"
[ -z "$datasetsPath" ] && datasetsPath="$SCA_DATASETS_PATH"
[ -z "$susedataPath" ] && susedataPath="$SCA_SUSEDATA_PATH"
[ -z "$tmpPath" ] && tmpPath="$SCA_TMP_PATH"
osResult=0
systemResult=0
kernelResult=0
kmodsResult=0
warnCmdsResult=0
errCmdsResult=0
srsResult=0

[ $DEBUG ] && echo "*** DEBUG: $0: SCA_HOME: $SCA_HOME"
[ $DEBUG ] && echo "*** DEBUG: $0: SCA_BIN_PATH: $SCA_BIN_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: datasetsPath: $datasetsPath"
[ $DEBUG ] && echo "*** DEBUG: $0: susedataPath: $susedataPath"
[ $DEBUG ] && echo "*** DEBUG: $0: tmpPath: $tmpPath"
[ $DEBUG ] && echo "*** DEBUG: $0: categories: $categories"
[ $DEBUG ] && echo "*** DEBUG: $0: scTar: $scTar"

# tmp dir and current time
tmpDir=`mktemp -p $tmpPath -d`
[ $DEBUG ] && echo "*** DEBUG: $0: tmpDir: $tmpDir"
curDate=`date +%Y%m%d`
[ $DEBUG ] && log "*** DEBUG: $0: curDate: $curDate"
tsIso=`date +"%Y-%m-%dT%H:%M:%S"`
ts=`date -d "$tsIso" +%s`
log ">>> sca-L0 timestamp: $ts"
[ $outFile ] && logToFile "sca-l0-timestamp: $ts" $outFile

# report sca-L0 version and default parameters to check
log ">>> sca-L0 version: $VERSION"
[ $outFile ] && logToFile "sca-l0-version: $VERSION" $outFile
[ $outFile ] && logToFile "sca-l0-default-checks: $SCA_CATEGORIES" $outFile

# these steps are always executed (regardless of parameter arguments)
untarAndCheck
extractScInfo
#hardwareId
supportconfigDate

# OS version supportability
if echo "$categories" | grep -q -E "^os$|^os | os | os$"; then
	os
	log "    OS result: $osResult"
	[ $outFile ] && logToFile "os-result: $osResult" $outFile
else
	[ $outFile ] && logToFile "os: NA" $outFile
	[ $outFile ] && logToFile "os-support: NA" $outFile
	[ $outFile ] && logToFile "os-result: NA" $outFile
fi

# system info (incl. nearest neighbor to find hardware certs)
if echo "$categories" | grep -q -E "^system$|^system | system | system$"; then
	systemInfo
	log "    System result: $systemResult"
	[ $outFile ] && logToFile "system-result: $systemResult" $outFile
else
        [ $outFile ] && logToFile "system: NA" $outFile
        [ $outFile ] && logToFile "system-certs: NA" $outFile
	[ $outFile ] && logToFile "system-result: NA" $outFile
fi

# kernel
if echo "$categories" | grep -q -E "^kernel$|^kernel | kernel | kernel$"; then
	kernel
	log "    Kernel result: $kernelResult"
	[ $outFile ] && logToFile "kernel-result: $kernelResult" $outFile
else
	[ $outFile ] && logToFile "kernel: NA" $outFile
	[ $outFile ] && logToFile "kernel-status: NA" $outFile
	[ $outFile ] && logToFile "kernel-result: NA" $outFile
fi

# kernel modules
if echo "$categories" | grep -q -E "^kmods$|^kmods | kmods | kmods$"; then
	kmods
	log "    Kernel modules result: $kmodsResult"
	[ $outFile ] && logToFile "kmods-result: $kmodsResult" $outFile
else
	[ $outFile ] && logToFile "kmods-externally-supported: NA" $outFile
	[ $outFile ] && logToFile "kmods-unsupported: NA" $outFile
	[ $outFile ] && logToFile "kmods-result: NA" $outFile
fi

# warning message commands
if echo "$categories" | grep -q -E "^warning-cmds$|^warning-cmds | warning-cmds | warning-cmds$"; then
	msgsCmds warning
	log "    Warning message commands result: $warnCmdsResult"
	[ $outFile ] && logToFile "warning-cmds-result: $warnCmdsResult" $outFile
else
	[ $outFile ] && logToFile "warning-cmds: NA" $outFile
	[ $outFile ] && logToFile "warning-cmds-result: NA" $outFile
fi

# error message commands
if echo "$categories" | grep -q -E "^error-cmds$|^error-cmds | error-cmds | error-cmds$"; then
	msgsCmds error
	log "    Error message commands result: $errCmdsResult"
	[ $outFile ] && logToFile "error-cmds-result: $errCmdsResult" $outFile
else
	[ $outFile ] && logToFile "error-cmds: NA" $outFile
	[ $outFile ] && logToFile "error-cmds-result: NA" $outFile
fi

# predicting SRs
if echo "$categories" | grep -q -E "^srs$|^srs | srs | srs$"; then
	srsBugs srs
	log "    SRs result: $srsResult"
	[ $outFile ] && logToFile "srs-result: $srsResult" $outFile
else
	[ $outFile ] && logToFile "srs: NA" $outFile
	[ $outFile ] && logToFile "srs-result: NA" $outFile
fi

# predicting bugs
if  echo "$categories" | grep -q -E "^bugs$|^bugs | bugs | bugs$"; then
	srsBugs bugs
	log "    Bugs result: $bugsResult"
	[ $outFile ] && logToFile "bugs-result: $bugsResult" $outFile
else
	[ $outFile ] && logToFile "bugs: NA" $outFile
	[ $outFile ] && logToFile "bugs-result: NA" $outFile
fi

# firmware versions?
# repos - other stuff
# /usr/local and /opt?
# security
# rankings vs. existing data - do we want to do this?

rm -rf $tmpDir
exit 0
