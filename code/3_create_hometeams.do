* Project: Card and Dahl Replication
* Author: Darius Martin, coauthor Jason Query
* Packages Needed: geodist
* Uses: "$proc\driving distances", "$proc\nfl stadiums", "$proc\census counties"
* Creates: "$proc\Hometeams", "$proc\unique_stadiums"
* Description: creates Hometeams, a county-by-season dataset gives the hometeam for each county using three different assignment rules - NearbyTeam, NearestTeam, and ShortDriveTeam. Also creates unique_stadiums, which is needed to produce the maps in figures 1 and 2.

use "$proc\driving distances", clear
keep FIPS stadiumname drive_km drive_min
bys FIPS stadiumname: keep if _n==1
tempfile drivingdist
save `drivingdist'

* Create $proc\unique_stadiums - list of all unique stadium location per season.
tempfile build_unique_stadiums
clear
save `build_unique_stadiums', emptyok replace

use "$proc\nfl stadiums", clear
quietly levelsof season, local(years)

foreach s in `years' {
	use "$proc\nfl stadiums", clear
	keep if season==`s'
	
	* This code solves the NY Giants/Jets problem. Any two teams that play in the same stadium are combined into a single stadium-location observation. 
	gen obs_id = _n
	gen TeamsInStadium = 1
	gen byte drop_obs = 0
	gen byte match = 0

    loc N = _N

    * Loop through observations within this season
    forvalues k = 1(1)`N' {
        * Skip if we already marked this row to be merged into another
        if drop_obs[`k'] == 1 continue

        local latk = stadium_LAT[`k']
        local lonk = stadium_LON[`k']

        * Check distance of this stadiums against all previously processed stadiums in the same season
        * We only check rows from 'start' to 'end' to keep it local
        geodist `latk' `lonk' stadium_LAT stadium_LON if _n < `k' & drop_obs == 0, gen(dist_prior)	
        
        qui sum dist_prior if  _n < `k'
        if r(min) < 2 {
            * Find which observation it matched
            quietly replace match = (dist_prior < 2) if _n < `k'
            qui sum obs_id if match == 1
            local target = r(min)
            
            * Update the first occurrence
            qui replace team = team[`target'] + " and " + team[`k'] in `target'
            qui replace TeamsInStadium = TeamsInStadium[`target'] + 1 in `target'
            qui replace drop_obs = 1 in `k'
            qui replace match = 0 if match==1
        }
        drop dist_prior 
    }
	drop if drop_obs==1
	drop drop_obs match obs_id
	
	append using `build_unique_stadiums'
	save `build_unique_stadiums', replace
}
save "$proc\unique_stadiums", replace emptyok

clear
save "$proc\Hometeams", replace emptyok

use "$proc\census counties", clear
gen key = 1
tempfile census_counties
save `census_counties'

foreach s in `years' {
	use "$proc\unique_stadiums", clear
	keep if season == `s'
	
	gen key = 1
	* Create one observation for each county-stadium pair in the current season.
	joinby key using `census_counties'
	bys FIPS: egen TeamsInState = total(TeamsInStadium*(state==team_state))
	geodist lat_pop long_pop stadium_LAT stadium_LON, generate(distance_km)

	sort FIPS distance_km

	gen NearbyTeam      = team        if TeamsInState==1 & state==team_state
	gen dist_NearbyTeam = distance_km if TeamsInState==1 & state==team_state
	bysort FIPS (NearbyTeam): replace NearbyTeam = NearbyTeam[_N] 
	bysort FIPS (NearbyTeam): replace dist_NearbyTeam = dist_NearbyTeam[_N]

	ren distance_km dist_Nearest
	sort FIPS dist_Nearest
	by FIPS: gen NearestTeam   = team[1]
	by FIPS: gen SecondNearest = team[2]
	by FIPS: gen dist_2ndNearest    = dist_Nearest[2]
	merge n:1 FIPS stadiumname using `drivingdist', keep(master match) nogen
	sort FIPS drive_km
	ren drive_km drivedist_Shortest
	by FIPS: gen ShortDriveTeam = team[1]
	by FIPS: gen SecondDriveTeam = team[2]
	by FIPS: gen drivedist_2ndShortest = drivedist_Shortest[2]
	
	by FIPS: keep if _n==1
	
	drop team team_state homeTeamAbbr stadiumname stadium_LAT stadium_LON TeamsInStadium key drive_min
	order season FIPS state TIME_ZONE lat_pop long_pop TeamsInState NearbyTeam dist_NearbyTeam NearestTeam dist_Nearest SecondNearest dist_2ndNearest ShortDriveTeam drivedist_Shortest SecondDriveTeam drivedist_2nd
	*gen diff = abs(SecondDist-distance_km)
	
	sort state NearestTeam
	by state: gen nCounties = _N
	
	by state NearestTeam: gen     ShareCounties = _N
	by state NearestTeam: replace ShareCounties = ShareCounties/nCounties
	gsort state -ShareCounties
	by state: replace NearbyTeam =  NearestTeam[1] if ShareCounties[1] > .7 & missing(NearbyTeam) & TeamsInState==0
	replace dist_NearbyTeam = dist_Nearest if !missing(NearbyTeam) & missing(dist_NearbyTeam)
	*keep season state FIPS TIME_ZONE lat_pop long_pop TeamsInState NearbyTeam NearestTeam SecondNearest ShortDriveTeam SecondDriveTeam dist* drive*
	
	label var nCounties "Number of Counties in the state"
	label var ShareCounties "Share of Counties in the state with the same nearest team as this county's nearest team."
	
	append using "$proc/Hometeams"
	save "$proc/Hometeams", replace
}