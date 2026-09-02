* Project: Card and Dahl Replication
* This File: Produces Figures 1 and 2 in the paper, showing hometeam assignment according to NearbyTeam and shortest driving distance.
* Name: Darius Martin, coauthor Jason Query
* Uses from $proc: $proc\unique_stadiums", $proc\Hometeams.dta"
* Uses from $rawdata: "team color scheme.txt", "shapefiles\c_18mr25.shp", "shapefiles\cb_2024_us_state_20m.shp"
* Creates if not already in $maps: "$maps\StatePolygons", "$maps\StateCoords", "$maps\CountyPolygons", "$maps\CountyCoords", "$maps\StateCoords_Clean". These files are not needed elsewhere, but take time to construct.
* Creates: "$results/Fig1-NearbyTeams.pdf", "$results\Fig2-NearestTeams.png"

* Albers Lat/Lon Projection:
capture program drop albers_projection
program define albers_projection
    local n = (sin(29.5 * _pi/180) + sin(45.5 * _pi/180)) / 2
    local c = cos(29.5 * _pi/180)^2 + 2*`n'*sin(	29.5 * _pi/180)
    local phi0 = 37.5 * _pi / 180
    local lam0 = -96  * _pi / 180

    gen lat_r = _Y * _pi / 180
    gen lon_r = _X * _pi / 180

    gen rho0  = sqrt(`c' - 2*`n'*sin(`phi0')) / `n'
    gen rho   = sqrt(`c' - 2*`n'*sin(lat_r))  / `n'
    gen theta = `n' * (lon_r - `lam0')

    replace _X = rho  * sin(theta)
    replace _Y = rho0 - rho * cos(theta)

    drop lat_r lon_r rho0 rho theta
end

clear
* Get Team Colors:
capture confirm file "$rawdata/team color scheme.txt"
if _rc {
	display as error "Team Color Scheme missing from rawdata directory, download replication_data.zip (see README)."
	exit 601	
}

import delimited "$rawdata/team color scheme.txt", varnames(1) stringcols(1 2) clear
ren team ShortDriveTeam
gen NearbyTeam = ShortDriveTeam
tempfile nfl_colors
save `nfl_colors', replace

*  ────── County Shapefile Processing ──────────────────────────────
capture confirm file "$maps\CountyPolygons.dta"
loc cpolys = _rc
capture confirm file "$maps\CountyCoords.dta"
if `cpolys' | _rc {
	capture confirm file "$rawdata\shapefiles\c_18mr25.shp"
	if _rc {
		display as error "Shapefile c_18mr25.shp missing from $rawdata\shapefiles, set download public 1 or get replication_data.zip (see README)."
		exit 601	
	}
	
	shp2dta using "$rawdata\shapefiles\c_18mr25.shp", database("$maps\CountyPolygons") coordinates("$maps\CountyCoords") genid(id) replace
	use "$maps\CountyPolygons", clear
	ren STATE state
	drop if inlist(state,"AK","HI","AS","FM","GU")
	drop if inlist(state,"MP","MH","PR","PW","VI")
	save "$maps\CountyPolygons", replace

	use "$maps\CountyCoords", clear
	albers_projection
	save "$maps\CountyCoords", replace
}

*  ────── State Shapefile Processing ──────────────────────────────
capture confirm file "$maps\StatePolygons.dta"
loc spolys = _rc
capture confirm file "$maps\StateCoords.dta"
if `spolys' | _rc {
	capture confirm file "$rawdata\shapefiles\cb_2024_us_state_20m.shp"
	if _rc {
		display as error "Shapefile cb_2024_us_state_20m.shp missing from $rawdata\shapefiles. Set download public 1 or get replication_data.zip"
		exit 601	
	}
	shp2dta using "$rawdata\shapefiles\cb_2024_us_state_20m.shp", database("$maps\StatePolygons") coordinates("$maps\StateCoords") genid(id) replace
	
	use "$maps\StatePolygons", clear 
	ren STUSPS state
	save "$maps\StatePolygons", replace
	use "$maps\StateCoords", clear
	albers_projection
	save "$maps\StateCoords", replace
}

* Get State Boundaries:
capture confirm file "$maps\StateCoords_Clean.dta"
if _rc {
	use "$maps\CountyPolygons.dta", clear
	ren id _ID
	mergepoly using "$maps\CountyCoords.dta", by(state) coordinates("$maps\StateCoords_Clean.dta")

	use "$maps\StateCoords_Clean.dta", clear
	drop if _fail == 1
	save "$maps\StateCoords_Clean.dta", replace
}

*  ──────────────────────────────── Get Stadiums Points and Labels ──────────────────────────────
* These can't be replaced with tempfiles, spmap appends .dta to whatever data() is given.
local stadiums_points "$maps\stadiums_points"
local stadiums_labels "$maps\stadiums_labels"    

use "$proc\unique_stadiums", clear
keep if season==2023
gen ShortName = word(team, -1)
replace ShortName = "Rams/Chargers" if team == "Los Angeles Chargers and Los Angeles Rams"
replace ShortName = "Jets/Giants"   if team == "New York Jets and New York Giants"

gen _Y = stadium_LAT
gen _X = stadium_LON
albers_projection

keep if season == 2023
collapse (firstnm) _X _Y ShortName, by(team)

preserve
keep _X _Y team
save "`stadiums_points'", replace
restore

keep _X _Y ShortName
gen labelpos = 3
replace labelpos = 9  if ShortName=="Packers"   | ShortName=="Vikings"    | ShortName == "Saints" | ShortName == "Lions" 
replace labelpos = 9  if ShortName == "Bears"   | ShortName == "Patriots" | ShortName == "Commanders"
replace labelpos = 12 if ShortName == "Raiders" | ShortName == "Colts"    | ShortName == "Cowboys"
save "`stadiums_labels'", replace

*  ──────────────────────────────── Fig 1: Nearby Teams ──────────────────────────────
use "$proc\Hometeams.dta", clear
keep if season == 2023
collapse (firstnm) NearbyTeam, by(state)
merge 1:1 state using "$maps\StatePolygons", keep(master match) nogen
merge n:1 NearbyTeam using `nfl_colors'    , keep(master match) nogen

replace NearbyTeam = "No nearby team" if missing(NearbyTeam)
replace teamrgb = "255 255 255" if missing(teamrgb)

gen     ShortName = word(NearbyTeam, -1)
replace ShortName = "No nearby team" if NearbyTeam == "No nearby team"

encode ShortName, gen(teamcolor)

sort ShortName
local fcolors ""
quietly levelsof teamcolor, local(codes)
foreach c of local codes {
    quietly levelsof teamrgb if teamcolor == `c', local(hex) clean
    local fcolors `"`fcolors' "`hex'""'
}

quietly levelsof teamcolor if ShortName == "No nearby team", local(noteam_code) clean
* Count total legend entries
quietly levelsof teamcolor, local(all_codes) clean
local n_codes : word count `all_codes'

local order_str ""
forvalues i = 1/`n_codes' {
    local code : word `i' of `all_codes'
    if `code' != `noteam_code' {
        local j = `i' + 1
        local order_str "`order_str' `j'"
    }
}
spmap teamcolor using "$maps\StateCoords", id(id) ///
	clmethod(unique) fcolor(`fcolors') ///
    ocolor(gs12) osize(0.05) /// 
    ndfcolor(white) ndocolor(white) ndsize(0.05) ///
    point(data(`stadiums_points') x(_X) y(_Y) fcolor(black) ocolor(black) size(*0.5)) ///
    label(data(`stadiums_labels') x(_X) y(_Y) label(ShortName) by(labelpos) position(3 9 12) size(vsmall vsmall vsmall) color(black) length(20) gap(*0.3 *0.5 *0.5)) ///
    legend(on position(6) rows(2) order(`order_str')) ///
	plotregion(margin(b=8)) graphregion(margin(b=-2))
	graph export "$results/Fig1-NearbyTeams.pdf", as(pdf) replace
	
*  ──────────────────────────────── Figure 2: Nearest Teams ──────────────────────────────

use "$proc\Hometeams", clear
keep if season==2023

merge n:1 ShortDriveTeam using `nfl_colors', keep(master match) nogen
encode ShortDriveTeam, gen(teamcolor)
keep FIPS teamcolor teamrgb 

tempfile tempteams
save `tempteams', replace
use "$maps\CountyPolygons", clear
merge n:1 FIPS using `tempteams', nogen

local fcolors ""
quietly levelsof teamcolor, local(codes)
foreach c of local codes {
    quietly levelsof teamrgb if teamcolor == `c', local(hex) clean
    local fcolors `"`fcolors' "`hex'""'
}
local n : word count `codes'

local ocolors ""
local osizes ""
forvalues i = 1/`n' {
    local ocolors `"`ocolors' "white""'
    local osizes `"`osizes' "vvthin""'
}

spmap teamcolor using "$maps\CountyCoords", id(id) ///
    clmethod(unique) ///
    fcolor(`fcolors') ocolor(`ocolors') osize(`osizes') ///
	polygon(data("$maps\StateCoords_Clean") ///
           fcolor(none) ocolor(white) osize(thin)) ///
    point(data(`stadiums_points') x(_X) y(_Y) ///
          fcolor(black) ocolor(black) size(*0.5)) ///
    label(data(`stadiums_labels') x(_X) y(_Y) ///
          label(ShortName) size(vsmall) color(black) position(3) length(20)) ///
    legend(off) ///

graph export "$results\Fig2-NearestTeams.png", as(png) replace  

capture erase "`stadiums_points'.dta"
capture erase "`stadiums_labels'.dta"