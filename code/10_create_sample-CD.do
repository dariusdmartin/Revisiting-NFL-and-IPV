* Project: Card and Dahl Replication 
* Name: Darius Martin, coauthor Jason Query
* Packages: -None-
* Uses: From $proc: "inclusion - CD", "SundayGameDaysNFL", "IPV", "Hometeams", "weather" "Sundays nfl data", "holidays"
* Creates: "$proc\sample - CD approach"
* Description: Creates the estimation sample used to replicate and extend the CD study.

use "$proc\inclusion - CD", clear
sort ori iDateEST ihourEST

* Shift observations before 5am to the previous day
gen CD_date = iDateEST - (ihourEST <= 4)
sort ori CD_date

* KH = Known Hour:
gen nTotKH  = nTot if !missing(ihourEST)
gen nClnKH  = nCln if !missing(ihourEST)

* If the county associated with an agency changes in different years, the same agency might be associated with different FIPS on the same CD_date
* (check: "VA1110000", 12/31/2016). 
by ori CD_date: replace FIPS = FIPS[1]
collapse (sum) nTot_day=nTot nCln_day=nCln nTotKH_day=nTotKH nClnKH_day=nClnKH, by(ori CD_date state FIPS)

format %td CD_date
keep if dow(CD_date)==0
ren CD_date Date
* Games in January occur in the season of the prior year:
gen     season = year(Date) - (month(Date)==1)
tempfile CDframe
save `CDframe'

* CDframe now contains one observation for each agency on any Sunday of the season when the agency reports an incident.
* Now, we need to add observations for all Sundays of the season (including those where the agency has no incidents.)
keep season ori state FIPS
bys  season ori: keep if _n==1
joinby season using "$proc\SundayGameDaysNFL"

* Merge in incident counts on each gameday and zero-fill unmatched gamedays
merge 1:1 ori Date using `CDframe'
foreach v in nTot_day nCln_day nTotKH_day nClnKH_day {
    replace `v' = 0 if _merge==1
}
* Ensure that only Sunday gamedays are in incidents_hour
assert _merge != 2
drop _merge

* For each season x ori, count Sundays each report type (total incidents, clean, total with known hour, and clean incidents with known hour):
foreach v in Tot Cln TotKH ClnKH {
    bys season ori: egen nSundays_`v' = total(n`v'_day > 0 & !missing(n`v'_day))
}

merge 1:1 ori Date using "$proc\IPV", keep(master match)
foreach hr in 1214 1517 1820 2123 {
	replace ipmfhome`hr'      = 0 if _merge==1
	replace ipmfclean`hr'     = 0 if _merge==1
}
drop _merge

foreach vr in home clean {
	gen ipmf`vr'tot     = ipmf`vr'1214     + ipmf`vr'1517     + ipmf`vr'1820     + ipmf`vr'2123
}

*merge n:1 state using "$proc\state FIPS codes", keep(match) nogen
*** Hometeams uses the old FIPS codes:
*gen FIPS = statefips + string(countyfips_old, "%03.0f")
merge n:1 season FIPS using "$proc\Hometeams",  keep(match) nogen

* Drop jurisdictions near NY and LA that have multiple teams:
drop if inlist(ShortDriveTeam,  "Los Angeles Chargers and Los Angeles Rams", "New York Jets and New York Giants")
drop if inlist(NearestTeam,     "Los Angeles Chargers and Los Angeles Rams", "New York Jets and New York Giants")

*** Get the nfl predicted and actual outcomes (upsetloss, etc.) and weather:
global basevars "upsetloss closeloss upsetwin predwin predclose predloss"
global holidays "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather  "hot hiheatindx cold windy anyrain anysnow"

ren ShortDriveTeam team
merge n:1 team Date using "$proc\weather",         keep(master match) keepusing($weather) nogen
merge n:1 team Date using "$proc\Sunday nfl data", keep(master match) keepusing($basevars) nogen
ren team ShortDriveTeam
foreach vr in $weather $basevars {
    ren `vr' `vr'_SD
}

ren NearestTeam team
merge n:1 team Date using "$proc\weather",         keep(master match) keepusing($weather)  nogen
merge n:1 team Date using "$proc\Sunday nfl data", keep(master match) keepusing($basevars) nogen
ren team NearestTeam
foreach vr in $weather $basevars {
    ren `vr' `vr'_NR
}

ren NearbyTeam team
merge n:1 team Date using "$proc\weather",         keep(master match) keepusing($weather)  nogen
merge n:1 team Date using "$proc\Sunday nfl data", keep(master match) keepusing($basevars) nogen
ren team NearbyTeam
foreach vr in $weather $basevars {
    ren `vr' `vr'_NB
}
merge n:1 Date using "$proc\holidays", keep(master match) keepusing($holidays) nogen

global basevars_Nearby   = "upsetloss_NB closeloss_NB upsetwin_NB predwin_NB predclose_NB predloss_NB"
global basevars_Nearest  = "upsetloss_NR closeloss_NR upsetwin_NR predwin_NR predclose_NR predloss_NR"
global basevars_Shortest = "upsetloss_SD closeloss_SD upsetwin_SD predwin_SD predclose_SD predloss_SD"

egen NearbyTeamSeason   = group(NearbyTeam season)
egen NearestTeamSeason  = group(NearestTeam season)
egen ShortestTeamSeason = group(ShortDriveTeam season)

sort season ori Date
gen CDsample      = season<=2006 & inlist(state,"CO","KS","MA","MI","NH","SC","TN","VT") & nSundays_Tot  >=13 & nTotKH_day>0
gen cleanCDsample = season<=2006 & inlist(state,"CO","KS","MA","MI","NH","SC","TN","VT") & nSundays_ClnKH>=13 & nClnKH_day>0
*gen CDextended    = nSundays_ClnKH>=13 & nClnKH_day>0 & !missing(NearbyTeam)
gen EXTsample     = nSundays_ClnKH>=13 & nClnKH_day>0

save "$proc\sample - CD approach", replace