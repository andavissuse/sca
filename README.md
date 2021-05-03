# sca-L0
Utility for doing "Level 0" analysis on supportconfigs (top-level executable is sca-L0.sh).  Directly reports some info; for other info, performs nearest-neighbor analysis to find similar supportconfigs from YES certifications, SRs, and bugs.  Reports all info in long-form output (to stdout) and short-form output (to file specified with -o option).

# Structure

## configs directory
config file(s) containing variables (e.g., paths, datatypes) for use by scripts

## bin directory
bash and python scripts to analyze supportconfigs.

## packaging directory
bash scripts to create files for packaging

# Instructions

## Analyzing a supportconfig
Top-level supportconfig analysis script is sca-L0.sh.

To analyze a supportconfig:
* Run `sca-L0.sh <supportconfig-tarball>`
  * Uncompresses the supportconfig, extracts data/features from it, then reports findings.
  * Reports some information (e.g., OS version, support status, etc.) directly.
  * Vectorizes other features/information then performs nearest-neighbor analysis to find similar supportconfigs (with related bugs/SRs/certs).

# sca-L0 results
By default, sca-L0 will output information for the default set of categories: os, system, kernel, kmods, warning-cmds, error-cmds, srs, bugs.

Long-form output (to stdout) and short-form output (to file specified with -o option) provide the same information, just in different formats.  Both outputs also provide an overall "good/bad/no-ranking" result for each category.  The "good/bad/no-ranking" results for each category are determined as follows.

Note: Any situation where sca-L0 does not/cannot determine category info will result in a "no-ranking" result. 

## os
Good (1):	OS version is supported (no LTSS or other custom support contract required)
Bad (-1):	OS version is out-of-support (not covered by general or LTSS support)
No-ranking (0):	OS version is supported with special contract

## system
Good:		YES Certifications exist for system model
Bad:		No YES Certification exist for system model
No-ranking (0):	Any other result

## kernel
Good:		Kernel is an official SUSE kernel and version is current
Bad:		Kernel is not an official SUSE kernel
No-ranking (0):	Kernel is an official SUSE kernel but version is downlevel

## kmods
Good (1):	Only SUSE-supported kernel modules are loaded
Bad (-1):	Non-supported kernel modules are loaded
No-ranking (0):	Only SUSE-supported or SUSE SolidDriver modules are loaded

## warning-cmds
Good (1):	No warning messages found in logs
Bad (-1):	Warning messages found in logs
No-ranking (0):	Any other result	

## error-cmds
Good (1):	No error messages found in logs
Bad (-1):	Error messages found in logs
No-ranking (0):	Any other result

## srs
Good (1):	No SRs found	
Bad (-1):	sca-L0 found one-or-more SRs w/ greater than 80% match 
No-ranking (0):	Any other result

## bugs
Good (1):	No bugs found
Bad (-1):	sca-L0 found one or more bugs w/ greater than 80% match
No-ranking (0):	Any other result

# Packaging
Packages are built in https://build.opensuse.org/project/show/home:andavis:sca-L0
Two source packages:
* sca-L0
  * Binary packages:
    * sca-L0: runtime scripts
    * sca-datasets: datasets containing info from rawdata supportconfigs
    * sca-susedata: lifecycle and rpm package info for SLE versions
"README.md" 36L, 1515C                                                                                                    5,0-1         Top
