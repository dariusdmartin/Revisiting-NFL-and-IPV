clear all
capture log close
* Note: This setup file contains switch values, defines globals, creates and names directories, installs needed packages, and runs the programs which generate published results.

*** Globals and switches:
* Assign the location of the home directory to homed (e.g., "C:\Users\...")
global homed ""

* Switches with default settings.
global download_public     0    // script 0
global build_drivedistance 0    // script 2 — needs Google Maps API key
global build_weather       0    // script 7 — weather data, long NOAA downloads
global build_nibrs         0    // scripts 8-9 — uses NIBRS extracts from ICPSR
global build_maps          0    // shapefile processing + Figures 1-2s
global haveCDfiles         0    // script 12-13 - dataset provided by Gordon Dahl to reproduce numbers from CD (2011).

* If build_nibrs 1 - put location of NIBRS Data here:
global datanibrs ""

* If build_drivedistance 1 - place Google Maps API key here 
global MapsAPIKey ""

*** 
* Local overrides (not distributed):
capture confirm file "local_settings.do"
if !_rc {
    do "local_settings.do"
    di as txt "Local settings loaded from `c(pwd)'"
}
else {
    di as txt "No local settings found in `c(pwd)' — using defaults"
}

* Directory globals:
global rawdata "$homed\raw_data" 
global proc    "$homed\proc"
global results "$homed\results"
global code    "$homed\code"
global maps    "$homed\maps"
global prov    "$homed\provided_data"

log using "$homed\ipv_nfl_repo_run.log", replace text

capture mkdir "$proc"
capture mkdir "$results"

* Check that data archive has been unpacked:
capture confirm file "$prov\driving distances.dta"
if _rc {
    di as err "Data archive not found. Download Revisiting-NFL-and-IPV-data.zip and unzip at $homed (see README)"
    exit 601
}
* Copy provided datasets for any stage not being rebuilt:
if !$build_drivedistance copy "$prov\driving distances.dta" "$proc\driving distances.dta", replace
if !$build_weather       copy "$prov\weather.dta"           "$proc\weather.dta", replace
if !$build_nibrs {
	copy "$prov\inclusion - CD.dta" 	 "$proc\inclusion - CD.dta", replace
	copy "$prov\inclusion - windows.dta" "$proc\inclusion - windows.dta", replace
	copy "$prov\IPV.dta" 				 "$proc\IPV.dta", replace
	copy "$prov\IPV_hour.dta" 			 "$proc\IPV_hour.dta", replace
}

* Install needed packages:
foreach package in shp2dta geodist ftools reghdfe ppmlhdfe listtab {
	capture which `package'
	if _rc {
		ssc install `package', replace
	}
}
* esttab command from esttout package 
capture which esttab
if _rc {
	ssc install estout, replace
}

* Run programs:
if $download_public {
	do "$code\0_download_public_data"
}

do "$code\1_county_and_stadium_geog"

if $build_drivedistance {
	do "$code\2_calculate driving distances" 
}

do "$code\3_create hometeams"
do "$code\4_format nfl data"
do "$code\5_load nfl data"
do "$code\6_create holidays"

* Weather data:
if $build_weather {
	do "$code\7_create weather data" 
}

* Inclusion criteria and dependent variables:
if $build_nibrs {
	do "$code\8_inclusion criteria"
	do "$code\9_extract_victim_files"
} 

do "$code\10_create_sample-CD"
do "$code\11_create_sample-windows"
do "$code\12_summary_stats"
do "$code\13_regressions"
do "$code\14_regional_heterogeneity"

* Hometeam maps: 
if $build_maps {
	capture mkdir "$maps"
    capture which spmap
    if _rc ssc install spmap, replace
    do "$code\15_draw_hometeam_maps"
}
log close