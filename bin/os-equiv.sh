#!/bin/sh

#
# This script maps an OS to another equivalent OS.
#
# Inputs: 1) OS (name_version_arch)
#
# Output: Equivalent OS (name_version_arch) or empty string (if no
#	  equivalent OS
#

# functions
function usage() {
	echo "Usage: `basename $0` [-d(ebug)] os-name_os-version_os-arch"
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
if [ ! "$1" ]; then
        usage 1
fi
os="$1"

osId=`echo $os | cut -d'_' -f1`
osVerId=`echo $os | cut -d'_' -f2`
if ! echo $osVerId | grep -q '\.'; then
        osVerId="${osVerId}.0"
fi
osArch=`echo $os | cut -d'_' -f1,2 --complement`
os="${osId}_${osVerId}_${osArch}"

case "$os" in
	sle*)
		osEquiv=`echo "$os" | sed "s/^sle[ds]_/sle_/"`	
		;;
	caasp_3.0*)
		osEquiv=`echo "$os" | sed "s/^caasp_3\.0/sle_12\.3/"`
		;;
	suse-microos_5.0*)
		osEquiv=`echo "$os" | sed "s/^suse-microos_5\.0/sle_15\.2/"`
		;;
	opensuse-leap_15.3*)
		osEquiv=`echo "$os" | sed "s/opensuse-leap_15\.3/sle_15\.3/"`
		;;
	*)
		osEquiv=""
		;;
esac	
echo "$osEquiv"

exit 0
