#!/bin/sh

#
# This script creates the source tarfiles used for packaging.
#
# Inputs: None (retrieves info from sca-L0.conf file)
#
# Outputs: sca-L0-<version>.tgz, sca-datasets-<version>.tgz, sca-susedata-<version>.tgz
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
				echo "Conffig file $confFile does not exist or is not readable, exiting..."
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

# This script is not in the package, so don't look for confFile in /etc
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
scaL0version=`cat "$SCA_HOME"/version`
scaDatasetsVersion=`cat "$SCA_DATASETS_PATH"/version`
scaSusedataVersion=`cat "$SCA_SUSEDATA_PATH"/version`

# sca-L0 files (modify config file if/as needed for external use)
mkdir "$tmpDir"/sca-L0-"$version"
cp "$confFile" "$tmpDir"/sca-L0-"$version"/
cp "$SCA_BIN_PATH"/*.sh "$tmpDir"/sca-L0-"$version"/
cp "$SCA_BIN_PATH"/*.py "$tmpDir"/sca-L0-"$version"/

# datasets
mkdir "$tmpDir"/datasets-"$version"
cp "$SCA_DATASETS_PATH"/* "$tmpDir"/datasets-"$version"/
rm "$tmpDir"/datasets-"$version"/*-hash.dat 2>/dev/null
rm "$tmpDir"/datasets-"$version"/sca-names.dat 2>/dev/null

# susedata
mkdir "$tmpDir"/susedata-"$version"
cp "$SCA_SUSEDATA_PATH"/* "$tmpDir"/susedata-"$version"/

# build the source tarfiles
echo "*** building tarfiles"
pushd $tmpDir >/dev/null
tar cvzf sca-L0-"$version".tgz sca-L0-"$version"
tar cvzf datasets-"$version".tgz datasets-"$version"
tar cvzf susedata-"$version".tgz susedata-"$version"
popd
cp "$tmpDir"/sca-L0-"$version".tgz "$tmpDir"/datasets-"$version".tgz "$tmpDir"/susedata-"$version".tgz .

# create the spec file
cat "$pkgingPath"/sca-L0.spec.tmpl | sed -i "s/%define sca_L0_version.*/%define sca_L0_version $scaL0version/" > "$pkgingPath"/sca-L0.spec
cat "$pkgingPath"/sca-L0.spec.tmpl | sed -i "s/%define sca_datasets_version.*/%define sca_datasets_version $scaDatasetsVersion" > "$pkgingPath"/sca-L0.spec
cat "$pkgingPath"/sca-L0.spec.tmpl | sed -i "s/%define sca_susedata_version.*/%define sca_susedata_version $scaSusedataVersion" > "$pkgingPath"/sca-L0.spec

rm -rf "$tmpDir"
exit 0 
