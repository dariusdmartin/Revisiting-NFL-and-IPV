* Project: Card and Dahl Replication
* Name: Darius Martin, coauthor Jason Query
* Packages needed: geodist
* Uses: "$proc\nfl stadiums"
* Creates: "$proc\driving distances"
* Description: Creates a dataset at the county-by-NFL stadium level giving the driving distance between the county population center and the NFL stadium, limted to all stadiums that are among the four geographically nearest according to the straight-line formula in any season. Requires a Google Maps API key.

* Check that Google Maps API key provided:
if "$MapsAPIKey" == "" {
    di as err "Required Google Maps API key not provided in global $MapsAPIKey for script 2. Set build_drivedistance 0 or provide key (See README)."
    exit 198
}

clear
save "$proc\driving distances", replace emptyok
forvalues season = 1995(1)2024 {
	use "$proc\nfl stadiums", clear
	keep if season==`season'
	gen key = 1
	* Create one observation for each county-stadium pair in each NFL season. 
	joinby key using "$proc\census counties"
	bys FIPS: egen TeamsInState = total(state==team_state)
	geodist lat_pop long_pop stadium_LAT stadium_LON, generate(distance_km)

	sort FIPS distance_km
	by FIPS: keep if _n<4
	
	keep FIPS stadiumname lat_pop long_pop stadium_LAT stadium_LON
	
	append using "$proc\driving distances"
	save "$proc\driving distances", replace
}

bys FIPS stadiumname: keep if _n==1

* Create variables to store results
gen drive_km = .
gen drive_min = .

save "$proc\driving distances", replace

*****
use "$proc\driving distances", clear
forvalues i = 1/`=_N' {
	if missing(drive_km[`i']) {
		local lat1 = lat_pop[`i']
		local lon1 = long_pop[`i']
		local lat2 = stadium_LAT[`i']
		local lon2 = stadium_LON[`i']
    
		* Call Google Distance Matrix API
		shell curl -s "https://maps.googleapis.com/maps/api/distancematrix/json?origins=`lat1',`lon1'&destinations=`lat2',`lon2'&mode=driving&key=$MapsAPIKey" > google_temp.json
    
		* Read response
		local json ""
		tempname fh
		file open `fh' using google_temp.json, read
		file read `fh' line
		while r(eof)==0 {
			local json "`json'`line'"
			file read `fh' line
		}
		file close `fh'
    
		if regexm(`"`json'"', `""value" : ([0-9]+).*"value" : ([0-9]+)"') {
			quietly replace drive_km  = real(regexs(1)) / 1000 in `i'
			quietly replace drive_min = real(regexs(2)) / 60   in `i'
		}    
	}
    
    * Progress update every 500 obs
    if mod(`i', 100) == 0 {
        save "$proc\driving distances", replace
        di "Completed `i' of `=_N'"
    }
}
save "$proc\driving distances", replace