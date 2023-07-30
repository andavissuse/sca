# sca
Utility for analyzing SUSE supportconfig data.  Reports all info in long-form output (to stdout) and short-form output (to file specified with -o option).

# Structure

## sca.conf, sca+.conf
Config file containing environment variables (e.g., paths, datatypes) for use by scripts.  sca.conf is for L0 analysis, sca+.conf is for L1 analysis.

## bin directory
Scripts to analyze supportconfigs

# Instructions

## Analyzing a supportconfig
Prerequisites:
* susedata files in the directories specified in sca.conf
* Optional, only required for analyzing srs and bugs:  datasets in the directories specified in sca+.conf

To analyze a supportconfig:
* Run `sca.sh <supportconfig-tarball>`.  This will:
  * uncompress the supportconfig
  * extract data/features
  * report information (e.g., OS version, support status, etc.)

# sca results
By default (if invoked w/o -c option), sca outputs information for all categories to stdout.  Default categories are os, system, kernel, kmods, warning-cmds, error-cmds.  Optional (sca+) categories are SRs and bugs.

The "-c" option can be used to restrict checks to specific categories.

The "-o" option writes short-form output (name-value pairs) to the file specified, along with an overall "1 (good)/-1 (bad)/0 (need-more-info)" result for each category.  Results are determined as follows:

Note: Any error situation will give a "0 (need-more-info)" result. 
## os
* good (1):		OS version is supported (no LTSS or other custom support contract required)
* bad (-1):		OS version is out-of-support (not covered by general or LTSS support)
* need-more-info (0):	OS version is supported with special contract

## system
* good (1):		YES Certifications exist for system model
* bad (-1):		No YES Certifications exist for system model
* need-more-info (0):	Any other result

## kernel
* good (1):		Kernel is an official SUSE kernel and version is current
* bad (-1):		Kernel is not an official SUSE kernel
* need-more-info (0):	Kernel is an official SUSE kernel but version is downlevel

## kmods
* good (1):		Only SUSE-supported kernel modules are loaded
* bad (-1):		Non-supported kernel modules are loaded
* need-more-info (0):	Only SUSE-supported or SUSE SolidDriver modules are loaded

## warning-cmds
* good (1):		No warning messages found in logs
* bad (-1):		Warning messages found in logs
* need-more-info (0):	Any other result	

## error-cmds
* good (1):		No error messages found in logs
* bad (-1):		Error messages found in logs
* need-more-info (0):	Any other result
