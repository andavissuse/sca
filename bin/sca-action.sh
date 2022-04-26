#!/bin/sh

#
# This script determines an sca-L0 result then outputs recommended actions
# in accordance with config settings.  One or more "-c <category>" options
# can be used to restrict the recommendation to specific categories.
#
# Inputs: 1) sca-L0 name:value output file
#
# Output: List of recommended actions
#

#
# functions
#
function usage() {
        echo "Usage: `basename $0` [options] <sca-L0-name-value-output>"
        echo "Options:"
        echo "    -d        debug"
	echo "    -c        category (default is all categories)"
        echo "                     categories: $1"
}

#
# Main routine
#

# conf files
curPath=`dirname "$(realpath "$0")"`
mainConfFile="/usr/etc/sca-L0.conf"
parserConfFile="/usr/etc/sca-L0-parser.conf"
extraConfFiles=`find /usr/etc -maxdepth 1 -name "sca-L0?.conf"`
extraParserConfFiles=`find /usr/etc -maxdepth 1 -name "sca-L0?-parser.conf"`
if [ ! -r "$mainConfFile" ]; then
        mainConfFile="/etc/sca-L0.conf"
        extraConfFiles=`find /etc -maxdepth 1 -name "sca-L0?.conf"`
        if [ ! -r "$mainConfFile" ]; then
                mainConfFile="$curPath/../sca-L0.conf"
                extraConfFiles=`find $curPath/.. -maxdepth 1 -name "sca-L0?.conf"`
                if [ ! -r "$mainConfFile" ]; then
                        exitError "No sca-L0 conf file info; exiting..."
                fi
        fi
fi
source $mainConfFile
for extraConfFile in $extraConfFiles; do
        source ${extraConfFile}
done
scaHome="$SCA_HOME"
allCategories="$SCA_CATEGORIES"
binPath="$SCA_BIN_PATH"

# arguments
if [ "$1" = "--help" ]; then
        usage "$allCategories"
fi
while getopts 'hdc:o:' OPTION; do
        case $OPTION in
                h)
                        usage $allCategories
			exit 0
                        ;;
                d)
                        DEBUG=1
                        ;;
		c)
			categories="$categories $OPTARG"
			;;
        esac
done
shift $((OPTIND - 1))
if [ ! "$1" ]; then
        usage $allCategories
	exit 1
fi
scaOutFile="$1"
if [ ! -r "$scaOutFile" ]; then
	echo "sca-L0 output file $scaOutFile does not exist or is not readable, exiting..."
	exit 1
fi
if [ -z "$categories" ]; then
        categories="$allCategories"
else
	for category in $categories; do
		categoryOptions="$categoryOptions -c $category"
	done
fi
[ $DEBUG ] && echo "*** DEBUG: $0: categoryOptions: $categoryOptions" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: scaOutFile: $scaOutFile" >&2

scaResult=`$SCA_BIN_PATH/sca-results.sh $categoryOptions $scaOutFile`
[ $DEBUG ] && scaResult=`$SCA_BIN_PATH/sca-results.sh -d $categoryOptions $scaOutFile`
[ $DEBUG ] && echo "*** DEBUG: $0: scaResult: $scaResult" >&2
case scaResult in
	1)
		actionVar="SCA_ACTION_GOOD"
		;;
	0)
		actionVar="SCA_ACTION_UNKNOWN"
		;;
	-1)
		actionVar="SCA_ACTION_BAD"
		;;
esac
[ $DEBUG ] && echo "*** DEBUG: $0: actionVar: $actionVar" >&2
echo $actionVar

