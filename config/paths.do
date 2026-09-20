*-------------------------------------------------------------------------------
* paths.do: project directories as global macros, resolved from the package root.
* Included by 00_master.do.
*-------------------------------------------------------------------------------
version 17
set more off

global ROOT : environment REPLICATION_ROOT
if "$ROOT" == "" global ROOT "`c(pwd)'"

global RAW       "$ROOT/data/raw"
global DERIVED   "$ROOT/data/derived"
global ESTIMATES "$ROOT/output/estimates"
global TABLES    "$ROOT/output/tables"
global FIGURES   "$ROOT/output/figures"
global LOGS      "$ROOT/logs"
global CODE      "$ROOT/code"

capture confirm file "$RAW/akfish-data-CFECpermits.csv"
if _rc {
    display as error "Cannot find $RAW/akfish-data-CFECpermits.csv (ROOT = $ROOT)"
    display as error "Set REPLICATION_ROOT or cd to the package root before running."
    exit 601
}

foreach d in "$DERIVED" "$ESTIMATES" "$TABLES" "$FIGURES" "$LOGS" {
    capture mkdir "`d'"
}

* Bundled user-written packages take precedence over any installed copies
capture adopath - "$CODE/ado"
adopath ++ "$CODE/ado"
