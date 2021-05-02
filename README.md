# sca-L0
Utility for doing "Level 0" analysis on supportconfigs (top-level executable is sca-L0.sh).  Extracts info from a supportconfig.  Directly reports some info; for other info, performs nearest-neighbor analysis to find similar supportconfigs from YES certifications, SRs, and bugs.  Reports all info in long-form output (to stdout) and short-form output (to file specified with -o option).

# Structure

## configs directory
config file(s) containing variables (e.g., paths, datatypes) for use by scripts

## bin directory
bash and python scripts to analyze supportconfigs.

## packaging directory
bash scripts to create files for packaging

# Instructions

# Analyzing a supportconfig
Top-level supportconfig analysis script is sca-L0.sh.

To analyze a supportconfig:
* Run `sca-L0.sh <supportconfig-tarball>`
  * Uncompresses the supportconfig, extracts data/features from it, then reports findings.
  * Reports some information (e.g., OS version, support status, etc.) directly.
  * Vectorizes other features/information then performs nearest-neighbor analysis to find similar supportconfigs (with related bugs/SRs/certs).

# Packaging
Packages are built in https://build.suse.de/project/show/home:andavis:sca-L0
Two source packages:
* sca-L0
  * Binary packages:
    * sca-L0: runtime scripts
    * sca-datasets: datasets containing info from rawdata supportconfigs
    * sca-susedata: lifecycle and rpm package info for SLE versions
"README.md" 36L, 1515C                                                                                                    5,0-1         Top
