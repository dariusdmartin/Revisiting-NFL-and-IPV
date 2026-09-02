* Project: Card and Dahl Replication 
* Name: Darius Martin, coauthor Jason Query
* Packages: -None-
* Uses: $proc\inclusion - windows, $proc\IPV_hour, "$proc\NFLData_All", $proc\SeasonDatesNFL", "$proc\Hometeams",
* Creates: "$proc\Game Times", "$proc\sample - windows"
* Description: 

* Revised inclusion criterion: Agencies that report on at least half of all days of the season, without any gaps longer than 14 days.
* One observation for each agency on each gameday of the home team.
* Dependent variable is number of IPV incidents within x-hours of kickoff, regressed against whether the game is an upset loss.
* This allows us to include non-Sunday games. 

global basevars "upsetloss closeloss upsetwin predwin predclose predloss"
global holidays "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather  "hot hiheatindx cold windy anyrain anysnow"

***** Create ___temp_nfl, a dataset at the team by date level, with one observation on each date when the team has a game. 
use "$proc\NFLData_All", clear
gen Date = date(date,"MDY")
format %td Date
drop date

ren upsetlosspredictedwin upsetloss
ren losspredictedclose closeloss
ren winpredictedloss upsetwin

gen     spreadX = spreadvalue
replace spreadX = -spreadX if team==underdog
assert !missing(spreadX)

gen predwin   = spreadX <= -4
gen predloss  = spreadX >= 4
gen predclose = spreadX > -4 & spreadX < 4

assert upsetloss == (loss & predwin)
assert closeloss == (loss & predclose)
assert upsetwin  == (win  & predloss)

ren year season
merge n:1 season using "$proc\SeasonDatesNFL", keep(master match) nogen
keep if season <= 2023
gen week = floor((Date-regStart)/7) + 1
keep team season Date win loss spreadX starttime upsetloss closeloss upsetwin predwin predclose predloss regStart regEnd week
sort team season Date 

gen starthour = floor(starttime/100)
gen startmin  = mod(starttime,100)
replace starthour = starthour+1 if startmin >=30
tempfile temp_nfl
save `temp_nfl', replace

bys season Date starthour: keep if _n==1
keep season Date starthour

local n = _N
save "$proc\Game Times", replace

***** Create the windows sample:
* Start with inclusion criterion:
use "$proc\inclusion - windows", clear

* Merge in Hometeams:
merge n:1 season FIPS using "$proc\Hometeams",  keep(match) nogen
drop NearbyTeam dist_NearbyTeam NearestTeam dist_Nearest SecondNearest dist_2ndNearest nCounties ShareCounties SecondDriveTeam drivedist_2ndShortest
save "$proc\sample - windows", replace

* Now create one observation for each game of the hometeam. For this, we'll use the nearest team by driving distance for as the hometeam.
* Perhaps limit it to counties with a team at least 250, 500, etc. miles away?
ren ShortDriveTeam team

* Note: "___temp_nfl" has one observation for each game of each time [team Date starttime]. 
* The joinby command creates one observation on each date that an ori's hometeam has game, for any ori that reports at least one incident during the season
joinby team season using `temp_nfl'
order season ori Date starttime
ren (team drivedist_Shortest) (hometeam team_distance) 
save "$proc\sample - windows", replace

****** Calculate the dependent variable - count of IPV incidents within a window around the game time:
clear
tempfile IPVcount IPVdata CD_IPV
save `IPVcount', emptyok

use "$proc\IPV_hour", clear
drop if ipmfcleanhour==0
sort ori iDateEST ihourEST
save `IPVdata', replace

use `IPVdata', clear
by ori iDateEST: egen nIPVcleanCD = total(ipmfcleanhour*(ihourEST>=12 & !missing(ihourEST)))
keep ori iDateEST nIPVcleanCD
bys ori iDateEST: keep if _n==1
ren iDateEST Date
format %td Date
save `CD_IPV', replace

* Loop through each NFL kickoff time and get total IPV incidents reported by each agency that occur within 3-12 hours of the (rounded) kickoff hour
forvalues g = 1/`n' {
	use "$proc\Game Times", clear
	loc date = Date[`g']
	loc hour = starthour[`g']
	loc season = season[`g']

	disp "Processing Game `g' of `n'"

	* IPV count:
	quietly {
		use `IPVdata', clear		
		*Get IPV counts hourly from 4 hours before to 12 hours after the starting hour of the game:
		gen timediff = (iDateEST-`date')*24 + (ihourEST-`hour')	
		keep if timediff >=-4 & timediff <= 15
			
		if _N > 0 {
			forvalues t = -4(1)15 {
				local suffix = cond(`t' < 0, "m" + string(abs(`t')), "`t'")
				by ori: egen nIPV`suffix' = total(ipmfcleanhour*(timediff==`t'))
			}
				
			bys ori: keep if _n==1
			keep ori nIPV*

			gen season    = `season'
			gen starthour = `hour'
			gen Date      = `date'
					
			append using `IPVcount'
			save `IPVcount', replace
		}
	}
}

use `IPVcount', clear
format %td Date
order season ori Date
sort season ori Date

tempfile temp_IPV
save `temp_IPV', replace

*start with the frame - currently 
use "$proc\sample - windows", clear
sort season ori Date
merge 1:1 ori Date starthour using `temp_IPV', keep(master match) nogen
* Note: for _merge==2, these are incidents of IPV associated with time windows when the agency doesn't have a game.
save "$proc\sample - windows", replace

forvalues t = -4(1)15 {
	local suffix = cond(`t' < 0, "m" + string(abs(`t')), "`t'")
	replace nIPV`suffix' = 0 if missing(nIPV`suffix')
}

gen nIPVclean2 = nIPV0 + nIPV1
forvalues t = 3/12 {
	loc v = `t'-1
	gen nIPVclean`t' = nIPVclean`v' + nIPV`v'
}

merge 1:1 ori Date using `CD_IPV', keep(master match) nogen
replace nIPVcleanCD = 0 if missing(nIPVcleanCD)
save "$proc\sample - windows", replace

* Merge in weather
use "$proc\sample - windows", clear
ren hometeam team
merge n:1 team Date using "$proc\weather",  keep(master match) keepusing($weather)  nogen
merge n:1 	   Date using "$proc\holidays", keep(master match) keepusing($holidays) nogen
ren team hometeam

egen TeamSeason = group(hometeam season)
gen dow = dow(Date)

gen ShareReported = DaysReportedSeason/DaysInSeason

gen upsetXdistance = upsetloss*team_distance/100
save "$proc\sample - windows", replace