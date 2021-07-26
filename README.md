# sca-L0
Utility for doing "Level 0" analysis on supportconfigs (top-level executable is sca-L0.sh).  Directly reports some info; for other info, performs nearest-neighbor analysis to find similar supportconfigs from YES certifications, SRs, and bugs.  Reports all info in long-form output (to stdout) and short-form output (to file specified with -o option).

# Structure

## sca-L0.conf 
Config file containing variables (e.g., paths, datatypes) for use by scripts

## bin directory
bash and python scripts to analyze supportconfigs

## datasets directory
Link to datasets used for supportconfig analysis.  Datasets are built and provided in the sca-databuild project.

## susedata directory
Link to susedata info (product lifecycles, rpm versions, rpm files) used for supportconfig analysis.  susedata files are built and provided in the sca-databuild project.

## packaging directory
spec file to be used in packagin

# Instructions

## Analyzing a supportconfig
Top-level supportconfig analysis script is sca-L0.sh.

To analyze a supportconfig:
* Run `sca-L0.sh <supportconfig-tarball>`.  This will:
  * uncompress the supportconfig
  * extract data/features
  * report some information (e.g., OS version, support status, etc.) directly
  * Vectorize other features then perform nearest-neighbor analysis to find similar supportconfigs and related SRs/bugs/certs)

# sca-L0 results
By default (if invoked w/o options), sca-L0 outputs information for all categories (os, system, kernel, kmods, warning-cmds, error-cmds, srs, bugs) to stdout.

The "-c" option can be used to restrict checks/output to specific categories.

The "-o" option writes short-form output (name-value pairs) to the file specified, along with an overall "good/bad/need-more-info" result for each category.  Results are determined as follows:

Note: Any situation where sca-L0 does not/cannot determine category info will cause an "undetermined (0)" result. 

## os
* good (1):		OS version is supported (no LTSS or other custom support contract required)
* bad (-1):		OS version is out-of-support (not covered by general or LTSS support)
* need-more-info (0):	OS version is supported with special contract or any other result

## system
* good (1):		YES Certifications exist for system model
* bad (-1):		No YES Certification exist for system model
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

## srs
* good (1):		No SRs found	
* bad (-1):		sca-L0 found one-or-more SRs w/ greater than 80% match 
* need-more-info (0):	Any other result

## bugs
* good (1):		No bugs found
* bad (-1):		sca-L0 found one or more bugs w/ greater than 80% match
* need-more-info (0):	Any other result

# Packaging
sca-L0 package is built in https://build.opensuse.org/project/show/home:andavis:sca.  Note that the sca-L0 package depends on sca-datasets and sca-susedata package (from github sca-databuild project).
