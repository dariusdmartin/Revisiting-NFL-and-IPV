* Project: Card and Dahl Replication
* Author: Darius Martin, coauthor Jason Query
* Packages needed: shp2dta
* Uses: From $rawdata: "county_pop_center_fixes.csv", "CountyPopCenters.dta", "shapefiles\c_18mr25.shp", "Stadiums.xlsx, SeasonDatesNFL.xlsx"
* Creates: "$proc\census counties", "$proc\nfl stadiums", "$proc\state FIPS codes", 
* Description: Creates files giving geographic characteristics of NFL stadiums, and characteristics and time zone of counties.

* Check that required rawdata files are present:
foreach f in "county_pop_center_fixes.csv" "CountyPopCenters.dta" "shapefiles\c_18mr25.shp" "Stadiums.xlsx" "SeasonDatesNFL.xlsx" {
	capture confirm file "$rawdata/`f'"
    if _rc {
        di as err "Missing needed file $rawdata/`f'. Download ipv-nfl-replication-data.zip (see README)"
        exit 601
    }
}

*  ────── County Centers from Census──────────────────────────────
* Change county pop centers to location of county seat for particular counties where the pop center is far from a road.
import delimited "$rawdata\county_pop_center_fixes.csv", varnames(1) case(preserve) stringcols(1) clear
ren (lat_pop long_pop) (lat_fix long_fix)
tempfile fix_counties
save `fix_counties', replace

use "$rawdata\CountyPopCenters", clear
drop if inlist(stname,"Alaska","Hawaii","Puerto Rico")
ren (latitude longitude) (lat_pop long_pop)
ren couname countyname
gen FIPS = string(statefp, "%02.0f") + string(countyfp, "%03.0f")
tab FIPS if stname=="Connecticut"

drop statefp countyfp stname

merge 1:1 FIPS using `fix_counties', nogen
replace  lat_pop =  lat_fix if !missing(lat_fix)
replace long_pop = long_fix if !missing(long_fix)
drop lat_fix long_fix note
save "$proc\census counties", replace

*  ────── Get TIME_ZONE at the county level from Census shapefiles for adjusting NIBRS data to eastern time ──────────────────────────────
tempfile CountyCoords CountyPolys CountyTZ
shp2dta using "$rawdata\shapefiles\c_18mr25.shp", database(`CountyPolys') coordinates(`CountyCoords') genid(id) replace
* CountyPolys is at id-level with one obs per polygon. Some counties consist of multiple polygons (e.g., Florida Keys.) Reduce to county-level.
use `CountyPolys', clear
keep FIPS STATE TIME_ZONE
tab FIPS if STATE=="CT"

ren STATE state
bysort FIPS: keep if _n==1
save `CountyTZ'

use "$proc\census counties", clear
merge 1:1 FIPS using `CountyTZ', keep(master match) nogen

* Assign time zones for the nine counties that split a time-zone boundary, based on the time-zone of the largest city.
* Note: Most counties in AZ are in timezone m, mountain but doesn't observe daylight time. 
* Mm counties are partly in MST, meaning they do observe daylight time, Indian reservations in AZ do observe daylight time. 
* Note: This might be done instead based on timezone of the population center.
replace TIME_ZONE = "E" if TIME_ZONE=="CE"
replace TIME_ZONE = "C" if TIME_ZONE=="CM" | TIME_ZONE=="MC"
replace TIME_ZONE = "M" if TIME_ZONE=="MP" & state == "OR"
replace TIME_ZONE = "P" if TIME_ZONE=="MP" & state == "ID"
replace TIME_ZONE = "m" if TIME_ZONE=="Mm"
* Create a "key" variable for the joinby command used later:
save "$proc\census counties", replace

*  ────── NFL Stadium Locations ──────────────────────────────
import excel using "$rawdata\Stadiums.xlsx", firstrow clear
ren (lat F) (stadium_LAT stadium_LON)

* State of each team. Note: this is the state that the team's stadium is within,
* except for the NY Giants and Jets. (Although their stadium is in NJ, the home state is set to NY. Otherwise, the Buffalo Bills are the sole team in NY.)
gen team_state = ""
replace team_state = "AZ" if team == "Arizona Cardinals"
replace team_state = "GA" if team == "Atlanta Falcons"
replace team_state = "MD" if team == "Baltimore Ravens"
replace team_state = "NY" if team == "Buffalo Bills"
replace team_state = "NC" if team == "Carolina Panthers"
replace team_state = "IL" if team == "Chicago Bears"
replace team_state = "OH" if team == "Cincinnati Bengals"
replace team_state = "OH" if team == "Cleveland Browns"
replace team_state = "TX" if team == "Dallas Cowboys"
replace team_state = "CO" if team == "Denver Broncos"
replace team_state = "MI" if team == "Detroit Lions"
replace team_state = "WI" if team == "Green Bay Packers"
replace team_state = "TX" if team == "Houston Oilers"
replace team_state = "TX" if team == "Houston Texans"
replace team_state = "IN" if team == "Indianapolis Colts"
replace team_state = "FL" if team == "Jacksonville Jaguars"
replace team_state = "MO" if team == "Kansas City Chiefs"
replace team_state = "NV" if team == "Las Vegas Raiders"
replace team_state = "CA" if team == "Los Angeles Chargers"
replace team_state = "CA" if team == "Los Angeles Rams"
replace team_state = "FL" if team == "Miami Dolphins"
replace team_state = "MN" if team == "Minnesota Vikings"
replace team_state = "MA" if team == "New England Patriots"
replace team_state = "LA" if team == "New Orleans Saints"
replace team_state = "NY" if team == "New York Giants"
replace team_state = "NY" if team == "New York Jets"
replace team_state = "CA" if team == "Oakland Raiders"
replace team_state = "PA" if team == "Philadelphia Eagles"
replace team_state = "PA" if team == "Pittsburgh Steelers"
replace team_state = "CA" if team == "San Diego Chargers"
replace team_state = "CA" if team == "San Francisco 49ers"
replace team_state = "WA" if team == "Seattle Seahawks"
replace team_state = "MO" if team == "St. Louis Rams"
replace team_state = "FL" if team == "Tampa Bay Buccaneers"
replace team_state = "TN" if team == "Tennessee Titans"
replace team_state = "VA" if team == "Washington Commanders"
save "$proc\nfl stadiums", replace

*  ────── State FIPS codes ──────────────────────────────
* Correspondence between NIBRS state abbreviations and standard Census FIPS state codes 
* This is used in scripts 8 and 9, inclusion criteria and dependent variable construction.
* Note: the NIBRS state abbreviations correspond to postal abbreviations with the exception of Nebraska, which in NIBRS is "NB" rather than "NE"
clear
input str2 state str2 statefips
#delimit ;
"AL" "01"; "AZ" "04"; "AR" "05"; "CA" "06"; "CO" "08"; "CT" "09"; "DE" "10"; "DC" "11"; "FL" "12"; "GA" "13"; 
"ID" "16"; "IL" "17"; "IN" "18"; "IA" "19"; "KS" "20"; "KY" "21"; "LA" "22"; "ME" "23"; "MD" "24"; "MA" "25"; 
"MI" "26"; "MN" "27"; "MS" "28"; "MO" "29"; "MT" "30"; "NB" "31"; "NV" "32"; "NH" "33"; "NJ" "34"; "NM" "35"; 
"NY" "36"; "NC" "37"; "ND" "38"; "OH" "39"; "OK" "40"; "OR" "41"; "PA" "42"; "RI" "44"; "SC" "45"; "SD" "46"; 
"TN" "47"; "TX" "48"; "UT" "49"; "VT" "50"; "VA" "51"; "WA" "53"; "WV" "54"; "WI" "55"; "WY" "56"; "AK" "02"; "HI" "15";
#delimit cr
end
save "$proc\state FIPS codes", replace

*  ────── NFL Season begin and end dates ──────────────────────────────
* Needed by scripts 5, 7, and 11.
import excel using "$rawdata\SeasonDatesNFL.xlsx", firstrow clear
save "$proc\SeasonDatesNFL", replace

