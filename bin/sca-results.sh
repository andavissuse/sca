#!/bin/sh

#
# This script analyzes the [1|0|-1] results in an sca-L0 name:value output
# file then returns an overall [1|0|-1] result.  By default, the script will
# analyze all <category-result> values in the file.  One or more  "-c <category>"
# options can be used to only analyze specific categories.
# 
#
# Inputs: 1) sca-L0 name:value output file
#
# Output: [1|0|-1] 
#

#
# functions
#
function usage() {
        echo "Usage: `basename $0` [options] <sca-L0-name:value-output-file>"
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
while getopts 'hdc:' OPTION; do
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
fi
[ $DEBUG ] && echo "*** DEBUG: $0: categories: $categories" >&2
[ $DEBUG ] && echo "*** DEBUG: $0: scaOutFile: $scaOutFile" >&2

for category in $categories; do
	[ $DEBUG ] && echo "*** DEBUG: $0: category: $category" >&2
	categoryResult=`grep "${category}-result" $scaOutFile | cut -d":" -f2 | sed "s/^ *//" | sed "s/ *$//"`
	[ $DEBUG ] && echo "*** DEBUG: $0: categoryResult: $categoryResult" >&2
	categoryResults="$categoryResults $categoryResult"
done
[ $DEBUG ] && echo "*** DEBUG: $0: categoryResults: $categoryResults" >&2
if echo "$categoryResults" | grep -q '\-1'; then 
	result="-1"
elif echo "$categoryResults" | grep -q '0'; then
	result="0"
else
	result="1"
fi
[ $DEBUG ] && echo "*** DEBUG: $0: result: $result" >&2
echo "$result"
