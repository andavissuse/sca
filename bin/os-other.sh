#!/bin/sh

#
# This script returns related OS versions.
#
# Inputs: 1) OS (name_ver-and-SP_arch)
#	  2) types of other OSes to return (currently supports "equiv", "related")
#
# Output: Equivalent or related OSes
#

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] os-name_os-version_os-arch type"
	echo "       type: (equiv|related)"
        exit $1
}

# arguments
if [ "$1" = "--help" ]; then
        usage 0
fi
while getopts 'hd' OPTION; do
        case $OPTION in
                h)
                        usage 0
                        ;;
                d)
                        DEBUG=1
                        ;;
        esac
done
shift $((OPTIND - 1))
if [ ! "$2" ]; then
        usage 1
fi
os="$1"
returnOsType="$2"
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os, returnOsType: $returnOsType" >&2

osEquiv=""
osRel=""
case "$os" in
	caasp_3.0_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In caasp_3.0_*" >&2
		arch=`echo $os | cut -d'_' -f1,2 --complement`
		osEquiv="sles_12.3_${arch}"
		osRel="sled_12.3_${arch} sles_12.2_${arch} sled_12.2_${arch} sles_12.1_${arch} sled_12.1_${arch} sles_12_${arch} sled_12_${arch}"
		;;	
	caasp_4.0_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In caasp_4.0_*" >&2
		arch=`echo $os | cut -d'_' -f1,2 --complement`
		osEquiv="sles_15.1_${arch}"
		osRel="sled_15.1_${arch} sles_15_${arch} sled_15_${arch}"
		;;	
	opensuse-leap_15.3_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In opensuse-leap_15.3_*" >&2
		arch=`echo $os | cut -d'_' -f1,2 --complement`
		osRel="sles_15.3_${arch} sled_15.3_${arch}"
		;;		
	opensuse-tumbleweed_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In opensuse-tumbleweed_*" >&2
		;;
        sle_hpc_*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In sle_hpc_*_*" >&2
		verAndSp=`echo $os | cut -d'_' -f3`
		ver=`echo $verAndSp | cut -d'.' -f1`
		sp=`echo $verAndSp | cut -d'.' -f2`
                arch=`echo $os | cut -d'_' -f1-3 --complement`
		osEquiv="sles_${verAndSp}_${arch}"
                if [ ! -z "$sp" ]; then
                        osRel="sled_${ver}.${sp}_${arch}"
                        for i in `seq -s ' ' $((sp - 1)) -1 1`; do
                                osRel="$osRel sles_${ver}.${i}_${arch} sled_${ver}.${i}_${arch}"
                        done
		fi
		osRel="$osRel sles_${ver}_${arch} sled_${ver}_${arch}"
                ;;
	sle_*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In sle_*_*" >&2
		verAndSp=`echo $os | cut -d'_' -f2`
		ver=`echo $verAndSp | cut -d'.' -f1`
                sp=`echo $verAndSp | cut -d'.' -f2`
		arch=`echo $os | cut -d'_' -f1,2 --complement`
		osRel="sles_${ver}.${sp}_${arch} sled_${ver}.${sp}_${arch}"
		if [ ! -z "$sp" ]; then
			for i in `seq -s ' ' $((sp - 1)) -1 1`; do
                        	osRel="$osRel sles_${ver}.${i}_${arch} sled_${ver}.${i}_${arch}"
                	done
		fi
		osRel="$oxRel sles_${ver}_${arch} sled_${ver}_${arch}"
		;;
	sles_sap_12.0*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In sles_sap_12.0*_*" >&2
		arch=`echo $os | cut -d'_' -f1-3 --complement`
		osEquiv="sles_12_${arch}"
		osRel="sled_12_${arch}"
		;;
	sles_sap_12.1*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In sles_sap_12.1*_*" >&2
		arch=`echo $os | cut -d'_' -f1-3 --complement`
		osEquiv="sles_12.1_${arch}"
		osRel="sled_12.1_${arch} sles_12_${arch} sled_12_${arch}"
		;;
        sles_sap_12.2*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In sles_sap_12.2*_*" >&2
                arch=`echo $os | cut -d'_' -f1-3 --complement`
                osEquiv="sles_12.2_${arch}"
                osRel="sled_12.2_${arch} sles_12.1_${arch} sled_12.1_${arch} sles_12_${arch} sled_12_${arch}"
                ;;
	sle[ds]_*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In sle[ds]_*_*" >&2
		prod=`echo $os | cut -d'_' -f1`
                verAndSp=`echo $os | cut -d'_' -f2`
                ver=`echo $verAndSp | cut -d'.' -f1`
                sp=`echo $verAndSp | cut -d'.' -f2`
		arch=`echo $os | cut -d'_' -f1,2 --complement`
		[ $DEBUG ] && echo "*** DEBUG: $0: prod: $prod, verAndSp: $verAndSp, ver: $ver, sp: $sp, arch: $arch" >&2
		if [ "$prod" = "sles" ]; then
			osRel="sled_${verAndSp}_${arch}"
		fi
		if [ "$prod" = "sled" ]; then
			osRel="sles_${verAndSp}_${arch}"
		fi
                if [ ! -z "$sp" ]; then
                        for i in `seq -s ' ' $((sp - 1)) -1 1`; do
				[ $DEBUG ] && echo "*** DEBUG: $0: i: $i" >&2
                                osRel="$osRel sles_${ver}.${i}_${arch} sled_${ver}.${i}_${arch}"
                        done
                fi
                osRel="$osRel sles_${ver}_${arch} sled_${ver}_${arch}"
                ;;
	suse-microos_*_*)
		[ $DEBUG ] && echo "*** DEBUG: $0: In suse-microos_*_*" >&2
		verAndSp=`echo $os | cut -d'_' -f2`
                ver=`echo $verAndSp | cut -d'.' -f1`
                sp=`echo $verAndSp | cut -d'.' -f2`
		arch=`echo $os | cut -d'_' -f1,2 --complement`
		if [ "$verAndSp" = "5.0" ]; then
			sleVer="15"
			sleSp="2"
		fi
		if [ "$verAndSp" = "5.1" ]; then
			sleVer="15"
			sleSp="3"
		fi
		osEquiv="sles_${sleVer}.${sleSp}_${arch}"
                if [ ! -z "$sleSp" ]; then
                        osRel="sled_${sleVer}.${sleSp}_${arch}"
                        for i in `seq -s ' ' $((sleSp - 1)) -1 1`; do
                                osRel="$osRel sles_${sleVer}.${i}_${arch} sled_${sleVer}.${i}_${arch}"
                        done
                fi
                osRel="$osRel sles_${sleVer}_${arch} sled_${sleVer}_${arch}"
		;;
	*)
		;;
esac	
[ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv, osRel: $osRel" >&2
if [ "$returnOsType" = "equiv" ] && [ ! -z "$osEquiv" ]; then
	echo $osEquiv | tr ' ' '\n'
fi
if [ "$returnOsType" = "related" ] && [ ! -z "$osRel" ]; then
	echo $osRel | tr ' ' '\n'
fi

exit 0
