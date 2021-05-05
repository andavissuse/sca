#!/bin/sh

#
# This script creates the spec file and source tarfiles used for packaging.
#
# Inputs: None (retrieves info from sca-L0.conf file)
#
# Outputs: sca-L0.spec, sca-L0-<sca-version>.tgz, sca-datasets-<datasets-version>.tgz,
#	   sca-susedata-<susedata-version>.tgz
#

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] [-c(onfig-file)] [-t(emp-path)]"
}

# arguments
if [ "$1" = "--help" ]; then
        usage 0
fi
while getopts 'hdc:t:' OPTION; do
	case $OPTION in
		h)
			usage
			exit 0
			;;
		d)
			DEBUG=1
			;;
		c)
			confFile="$OPTARG"
			if [ ! -r "$confFile" ]; then
				echo "Config file $confFile does not exist or is not readable, exiting..."
				exit 1
			fi
			;;
		t)
			tmpPath="$OPTARG"
			if [ ! -d "$tmpPath" ]; then
				echo "Temp path $tmpPath does not exist, exiting..."
				exit 1
			fi
			;;
	esac
done

# This script is not in the package, so only look for confFile in parent directory 
confFile="../sca-L0.conf"
source "$confFile"
[ $DEBUG ] && echo "*** DEBUG: $0: SCA_BIN_PATH: $SCA_BIN_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: SCA_DATASETS_PATH: $SCA_DATASETS_PATH"
[ $DEBUG ] && echo "*** DEBUG: $0: SCA_SUSEDATA_PATH: $SCA_SUSEDATA_PATH"
pkgingPath="$SCA_HOME/packaging"
if [ -z "$tmpPath" ]; then
	tmpPath="$SCA_TMP_PATH"
fi
tmpDir=`mktemp -d --tmpdir="$tmpPath"`

# Pull version from code
scaL0version=`grep "^VERSION=" "$SCA_BIN_PATH"/sca-L0.sh | cut -d"=" -f2 | sed 's/"//g'`
scaDatasetsVersion=`cat "$SCA_DATASETS_PATH"/version`
scaSusedataVersion=`cat "$SCA_SUSEDATA_PATH"/version`
[ $DEBUG ] && echo "*** DEBUG: $0: scaL0version: $scaL0version"
[ $DEBUG ] && echo "*** DEBUG: $0: scaDatasetsVersion: $scaDatasetsVersion"
[ $DEBUG ] && echo "*** DEBUG: $0: scaSusedataVersion: $scaSusedataVersion"

# sca-L0 files (modify config file if/as needed for external use)
mkdir "$tmpDir"/sca-L0-"$scaL0version"
confFileName=`basename $confFile`
cp "$SCA_HOME"/"$confFileName".prod "$tmpDir"/sca-L0-"$scaL0version"/$confFileName
cp "$SCA_BIN_PATH"/*.sh "$tmpDir"/sca-L0-"$scaL0version"/
cp "$SCA_BIN_PATH"/*.py "$tmpDir"/sca-L0-"$scaL0version"/

# datasets
mkdir "$tmpDir"/sca-datasets-"$scaDatasetsVersion"
cp "$SCA_DATASETS_PATH"/* "$tmpDir"/sca-datasets-"$scaDatasetsVersion"/

# susedata
mkdir "$tmpDir"/sca-susedata-"$scaSusedataVersion"
cp "$SCA_SUSEDATA_PATH"/* "$tmpDir"/sca-susedata-"$scaSusedataVersion"/

# build the source tarfiles
[ $DEBUG ] && echo "*** DEBUG: $0: Building tarfiles..."
pushd $tmpDir >/dev/null
tar cvzf sca-L0-"$scaL0version".tgz sca-L0-"$scaL0version"
tar cvzf sca-datasets-"$scaDatasetsVersion".tgz sca-datasets-"$scaDatasetsVersion"
tar cvzf sca-susedata-"$scaSusedataVersion".tgz sca-susedata-"$scaSusedataVersion"
popd >/dev/null
cp "$tmpDir"/sca-L0-"$scaL0version".tgz "$tmpDir"/sca-datasets-"$scaDatasetsVersion".tgz "$tmpDir"/sca-susedata-"$scaSusedataVersion".tgz .

# create the spec file
cat "$pkgingPath"/sca-L0.spec.tmpl | sed "s/%define sca_L0_version.*/%define sca_L0_version $scaL0version/" |
				     sed "s/%define sca_datasets_version.*/%define sca_datasets_version $scaDatasetsVersion/" |
				     sed "s/%define sca_susedata_version.*/%define sca_susedata_version $scaSusedataVersion/" \
				     > "$pkgingPath"/sca-L0.spec

rm -rf "$tmpDir"
exit 0 
