*-------------------------------------------------------------------------------
* Filename:     config/paths.do
* Purpose:      Define every directory used by the package as a global macro,
*               relative to the package root. Included by 00_master.do and by
*               each numbered do-file so they can also be run standalone.
* Inputs:       none
* Outputs:      globals ROOT, RAW, DERIVED, ESTIMATES, TABLES, FIGURES, LOGS
* Requires:     Stata 17 or later
* Author:       Replication package build, 2026
*
* WHY a global instead of `cd`: the do-files write .ster and .dta by absolute
* reference, and `cd` would break if a user runs one file from another folder.
*-------------------------------------------------------------------------------

*==============================================================================*
* Setup
*==============================================================================*
version 17
set more off

*------------------------------------------------------------------------------
* ROOT resolution.
* Set the environment variable REPLICATION_ROOT, or edit the fallback below to
* the absolute path of the folder that contains this config/ directory.
*------------------------------------------------------------------------------
global ROOT : environment REPLICATION_ROOT
if "$ROOT" == "" {
    * Fallback: assume Stata's working directory is the package root.
    global ROOT "`c(pwd)'"
}

*==============================================================================*
* Derived paths
*==============================================================================*
global RAW       "$ROOT/data/raw"
global DERIVED   "$ROOT/data/derived"
global ESTIMATES "$ROOT/output/estimates"
global TABLES    "$ROOT/output/tables"
global FIGURES   "$ROOT/output/figures"
global LOGS      "$ROOT/logs"
global CODE      "$ROOT/code"

*==============================================================================*
* Checks
*==============================================================================*
* Fail loudly and early rather than producing a half-built dataset.
capture confirm file "$RAW/akfish-data-CFECpermits.csv"
if _rc {
    display as error "Cannot find $RAW/akfish-data-CFECpermits.csv"
    display as error "ROOT resolved to: $ROOT"
    display as error "Set REPLICATION_ROOT, or cd to the package root before running."
    exit 601
}

foreach d in "$DERIVED" "$ESTIMATES" "$TABLES" "$FIGURES" "$LOGS" {
    capture mkdir "`d'"
}

*------------------------------------------------------------------------------
* Bundled user-written packages.
* WHY: a replicator without SSC access (or on a locked-down machine) still needs
* sfcross, parmest, mat2txt and estout. Putting code/ado first means the bundled
* copies win over whatever happens to be installed, so the run is reproducible
* rather than dependent on the local Stata installation.
*------------------------------------------------------------------------------
capture adopath - "$CODE/ado"
adopath ++ "$CODE/ado"

display as text "paths.do: ROOT = $ROOT"
