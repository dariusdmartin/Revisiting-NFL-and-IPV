* Project: Card and Dahl Replication
* Author: Darius Martin, coauthor Jason Query
* Uses: "$proc\NFLData_All.dta", "$rawdata\SeasonDatesNFL.xlsx"
* Packages Needed: -None-
* Creates: "$proc\SeasonDatesNFL", "$proc\SundayGameDaysNFL", "$proc\Sunday nfl data"
* Description: Creates a dataset with one observation for each NFL team on each Sunday of the season, with indicators for whether the team had a game (gameday), whether the game was a win or loss, the spread, and the CD basevars upsetloss, closeloss, etc.
* Date: August 18, 2026

import excel using "$rawdata\SeasonDatesNFL.xlsx", firstrow clear
save "$proc\SeasonDatesNFL", replace

*** Load the NFL data, fix the Date and create variable names. 
use "$proc\NFLData_All", clear
* year is actually season, as games in January are assigned the previous year.
ren year season 
gen Date = date(date,"MDY")
format %td Date
drop date
keep if dow(Date)==0
* The last season of the sample is 2023, since the 2024 season extends to January 2025, and 2025 NIBRS data isn't available as of the date this code was written.
keep if season <= 2023

*Get all the NFL gamedays so we can create predicted and actual outcome variables for every NFL gameday (including those where the team doesn't have a game.)
preserve
	keep season Date
	bys season Date: keep if _n==1
	by season: gen Sunday = _n
	save "$proc\SundayGameDaysNFL", replace
restore
	
* Get season start and end dates. Note that nothing is dropped in keep(match)
merge n:1 season using "$proc\SeasonDatesNFL", keep(match) nogen
* Drop games in the postseason
drop if Date > regEnd

* Give variables the same names as Card and Dahl:
ren upsetlosspredictedwin upsetloss
ren losspredictedclose closeloss
ren winpredictedloss upsetwin

gen     spreadX = spreadvalue
replace spreadX = -spreadX if team==underdog

gen predwin   = spreadX <= -4
gen predloss  = spreadX >= 4
gen predclose = spreadX > -4 & spreadX < 4

assert upsetloss == (loss & predwin)
assert closeloss == (loss & predclose)
assert upsetwin  == (win  & predloss)

keep Date team win loss spreadX starttime upsetloss closeloss upsetwin predwin predclose predloss 
ren spreadX spread
tempfile temp_nfl
save `temp_nfl', replace

* Create all team-gameday combinations - one obs for each team on each Sunday with a game during the regular NFL season from 1995-2024.
use "$proc\NFLData_All.dta", clear
ren year season
keep team season
bysort team season: keep if _n==1
joinby season using "$proc\SundayGameDaysNFL"
sort season team Date

* Set the outcome indicators to zero on Sundays with no games.
merge 1:1 Date team using `temp_nfl'
* Unmatched values are on non-gamedays.
gen gameday = _merge==3
local vars ="upsetloss closeloss upsetwin predwin predclose predloss"
foreach vr in `vars'{
	replace `vr' = 0 if gameday==0
}
drop _merge
save "$proc\Sunday nfl data", replace