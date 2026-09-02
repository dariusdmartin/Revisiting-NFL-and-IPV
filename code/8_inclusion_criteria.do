* Project: Card and Dahl Replication 
* Name: Darius Martin, coauthor Jason Query
* Packages Needed: -None-
* Uses: From $datanibrs - all annual NIBRS incident files from 1995-2024.
*	    From $rawdata - "CT county correspondence", "missing counties fips", "ICPSR NIBRS Codes", 
*		From $proc - "state FIPS codes", "census counties"
* Creates: "$proc\inclusion - CD", "$proc\inclusion - windows"

* Description: Creates incidents datasets, with one obs per incident reported by each agency, variables included:
* 		[ori FIPS TIME_ZONE ReportDateIndicator ihour idate ihourEST iDateEST]
* "inclusion - CD" is the (ori x iDateEST x ihourEST) level. Has the number of incidents on that hour [nTot nCln GameDay GameTime]
* Has one observation for each agency in each hour when an incident is reported, in a 48 hour window around any NFL game time.
* Although one obs per (ori idate ihour), there may be multiple obs at the (ori iDateEST ihourEST) level, because 1am is repeated at the end of daylight savings. Events on the West coast occuring at 10pm and 11pm the day before DST end both occur at 1am EST.

clear
* Ensure needed rawdata files are present:
foreach f in "CT county correspondence.xlsx" "missing counties fips.xlsx" "ICPSR NIBRS Codes.xlsx" {
	capture confirm file "$rawdata/`f'"
    if _rc {
        di as err "Missing $rawdata/`f' — set build_nibrs to 0 or get replication_data.zip (see README)."
        exit 601
    }
}

* Varibles needed from NIBRS incidents extracts:
global keep_common_inc "ORI V1006 V1007 INCDATE"
* Variables needed from NIBRS incidents and victims extracts, with two different naming conventions:
global keep_bvars  "B1007 B1008 B1012 B2005 B3024"
global keep_bhvars "BH007 BH008 BH012 BH019 BH054"

* Get CT county correspondence to fix counties in CT:
import excel using "$rawdata/CT county correspondence", firstrow clear
tempfile CT_counties
save `CT_counties'

* Get FIPS codes for agencies with missing county codes in the raw NIBRS data.
import excel using "$rawdata/missing counties fips.xlsx", firstrow clear
tempfile missing_fips
save `missing_fips'

*** Inclusion Criteria for the CD and extended samples:
* Create a dataset giving the Date and start time of any Sunday NFL game during the sample period:
use "$proc/Sunday nfl data", clear
drop if missing(starttime)
keep Date starttime
gen starthour = floor(starttime/100)
gen startmin  = mod(starttime,100)
replace starthour = starthour+1 if startmin >=30
bys  Date starthour: keep if _n==1
keep Date starthour

* Create an observation for each hour within a 48 hour window around the starting hour of any NFL game - 24 hours before and after. (These are the incident hours that we keep.)
gen double dt = mdyhms(month(Date), day(Date), year(Date), starthour, 0, 0)
expand 49

bysort Date starthour: gen offset = _n - 25
gen double dt_window = dt + offset * 3600000
gen iDateEST = dofc(dt_window)
gen ihourEST = hh(dt_window)
format %td iDateEST
gen     GameDay  = 0
gen     GameTime = 0
replace GameDay  = 1 if Date==iDateEST 
replace GameTime = 1 if Date==iDateEST & starthour==ihourEST

keep iDateEST ihourEST GameDay GameTime
bys  iDateEST ihourEST: ereplace GameDay  = max(GameDay)
bys  iDateEST ihourEST: ereplace GameTime = max(GameTime)
by   iDateEST ihourEST: keep if _n==1
*** Add one observation for each gameday with a missing value for ihourEST.
* (This is to replicate the CD dataset. CD include any agency that reports crime on 13/17 Sundays. However, they include in this count agencies who file reports on Sundays - whether or not the crime occurred on that day - with missing values for the incident hour.)
preserve
	keep if GameDay == 1
	bys iDateEST: keep if _n==1
	replace ihourEST = .
	replace GameTime = 0
	tempfile gameday_missing
	save `gameday_missing'
restore
append using `gameday_missing'
sort iDateEST ihourEST
tempfile nflhours
save `nflhours'

clear
tempfile reportingdays
save `reportingdays', emptyok
save "$proc/inclusion - CD", emptyok replace

*** Get the incident level files needed to construct the data frame, and calculate the number of incidents that each agency reports on each gameday.
forvalues i = 1995(1)2024 {	
	* Get the name of the NIBRS dataset for the current year:
	import excel using "$rawdata/ICPSR NIBRS Codes.xlsx", clear firstrow
	keep if year == `i'
	assert _N==1
	loc q1 = NIBRS[1]
	
	* Get the incident-level files:
	if `i' < 2017 {
		use "$datanibrs/ICPSR_`q1'/DS0001/`q1'-0001-Data.dta", clear
		tostring INCDATE, gen(datex)
		gen idate = date(datex,"YMD")
		drop datex
	}
    else {
		use "$datanibrs/ICPSR_`q1'/DS0003/`q1'-0003-Data.dta", clear
		gen idate  = date(INCDATE,"DMY")
	}
	format %td idate 
	
	ren (ORI V1007) (ori ihour)
	capture confirm variable B1007
	if _rc == 0 {
		ren (B1008 B3024 B1007 B1012 B2005) (state countyfips city agency pop1)
	} 
	else {
		ren (BH008 BH054 BH007 BH012 BH019) (state countyfips city agency pop1)
	}
	
	keep if inlist(agency,1,2)
	
	* B2005 is set to zero for all obs in the 2000 NIBRS
	if `i' == 2000 {
	 	replace pop1 = B2008 if `i'==2000
	}
	
	drop if inlist(state,"AK","HI")
	ren V1006 ReportDateIndicator
	
	keep ori idate ihour countyfips city state agency pop1 ReportDateIndicator
	
	* drop state agencies in VA incorrectly listed as city agencies, identified by having "S" in the numeric portion of the ori after the first two letters.
	* E.g., for ori == VA040S100, the city is EMPORIA STATE POLICE
	* These are present in VA from 1995-2007.
	drop if strpos(ori,"S")>2 & state=="VA"
	* Recode missing values for county and incident hour, as NIBRS uses negative numbers for these.
	replace countyfips = . if countyfips == -9
	replace ihour = .      if ihour <0

	*** Create County FIPS:
	* This adds the county fips codes for certain counties (mostly VA) where the code is missing in the raw incidents data, but found and added later.
	merge n:1 ori using `missing_fips', update
	drop if _merge==2 // counties that aren't in the incidents data
	drop _merge
	
	* In 2023, CT replaced old counties with planning regions. Replace with old counties, as previous years' NIBRS files, along with "census counties" and "hometeams", are all based on old county boundaries.
	if `i' >= 2023 {
		merge n:1 ori using `CT_counties', keep(master match)
		* Confirm that this year's NIBRS file uses planning regions codes for matched agencies:
		assert countyfips == newfips if _merge==3
		* Confirm that every CT agency in this year's NIBRS appears in the correspondence file.
		assert _merge==3 if state=="CT"
		replace countyfips = oldfips if _merge==3
		drop _merge oldfips newfips CTcity
	}
		
	* Create FIPS:	
	merge n:1 state using "$proc/state FIPS codes", keep(master match) nogen
	gen str5 FIPS = statefips+string(countyfips, "%03.0f")
	
	* Merge with "census counties" to get TIME_ZONE. This drops any observating with missing FIPS, necessary as we assign hometeams based on FIPS.
	merge n:1 FIPS using "$proc/census counties", keepusing(TIME_ZONE) keep(match) nogen
	
	*** Calculate Eastern clock time. This is complicated due to daylight savings
	gen year = year(idate)

	gen     DST_start = mdy(3,8,year)        if year >=2007
	replace DST_start = DST_start + 7-dow(DST_start) if year >=2007 & dow(DST_start)!=0
	replace DST_start = mdy(4,1,year)         if year < 2007
	replace DST_start = DST_start + 7-dow(DST_start) if year < 2007 & dow(DST_start)!=0
	
	gen     DST_end   = mdy(11,1,year)        if year >=2007
	replace DST_end   = DST_end + 7-dow(DST_end)     if year >=2007 & dow(DST_end)!=0
	replace DST_end   = mdy(10,31,year)-dow(mdy(10,31,year)) if year < 2007

	* Deal with counties in Arizona that don't observe daylight time:
	replace TIME_ZONE = "P" if TIME_ZONE == "m" & idate > DST_start & idate < DST_end
	replace TIME_ZONE = "P" if TIME_ZONE == "m" & ((idate == DST_start & ihour > 1) | (idate==DST_end & ihour <=1)) & !missing(ihour)
	replace TIME_ZONE = "M" if TIME_ZONE == "m"

	gen  ihourEST = ihour
	gen  iDateEST = idate  

	replace ihourEST = ihour+1    if ihour<=22 & TIME_ZONE == "C"
	replace ihourEST = ihour+2    if ihour==1  & TIME_ZONE == "C" & idate == DST_start          
	replace ihourEST = 0          if ihour==23 & TIME_ZONE == "C"

	replace ihourEST = ihour+2    if ihour<=21             & TIME_ZONE == "M"
	replace ihourEST = ihour+3    if (ihour==0 | ihour==1) & TIME_ZONE == "M" & idate==DST_start
	replace ihourEST = ihour+1    if (ihour==0 | ihour==1) & TIME_ZONE == "M" & idate==DST_end
	replace ihourEST = 0          if ihour==22             & TIME_ZONE == "M"
	replace ihourEST = 1          if ihour==23             & TIME_ZONE == "M"
	
	replace ihourEST = ihour+3    if ihour<=20             & TIME_ZONE == "P"
	replace ihourEST = ihour+4    if (ihour==0 | ihour==1) & TIME_ZONE == "P" & idate==DST_start
	replace ihourEST = ihour+2    if ihour==0              & TIME_ZONE == "P" & idate==DST_end

	replace ihourEST = 0          if ihour==21 & TIME_ZONE == "P"
	replace ihourEST = 1          if ihour==22 & TIME_ZONE == "P"
	replace ihourEST = 2          if ihour==23 & TIME_ZONE == "P"
	replace ihourEST = 3          if ihour==23 & TIME_ZONE == "P" & idate==DST_start -1
	replace ihourEST = 1          if ihour==23 & TIME_ZONE == "P" & idate==DST_end   -1  

	replace iDateEST = iDateEST+1 if ihour==23              & TIME_ZONE == "C"
	replace iDateEST = iDateEST+1 if inlist(ihour,   22,23) & TIME_ZONE == "M"
	replace iDateEST = iDateEST+1 if inlist(ihour,21,22,23) & TIME_ZONE == "P"

	format %td iDateEST
	
	sort ori iDateEST ihourEST
	by   ori iDateEST ihourEST:  gen nTot   = _N
	by   ori iDateEST ihourEST: egen nCln = total(ReportDateIndicator==0)
	
	keep ori iDateEST ihourEST state TIME_ZONE FIPS nTot nCln
	by   ori iDateEST ihourEST: keep if _n==1
		
	* (a) game-window hours for the CD inclusion critera:
	preserve
		merge n:1 iDateEST ihourEST using `nflhours', keep(match) nogen
		append using "$proc/inclusion - CD"
		save         "$proc/inclusion - CD", replace
	restore
	
	* (b) agency-days with a clean, known-hour report for windows sample inclusion criterion:
	keep if nCln > 0 & !missing(ihourEST)
	by ori iDateEST: keep if _n==1
	keep ori iDateEST state FIPS
	drop if month(iDateEST) >1 & month(iDateEST) < 8
	append using `reportingdays'
	save         `reportingdays', replace
}

**** Inclusion Criteria for the windows samples:
clear
save "$proc/inclusion - windows", emptyok replace

* Agencies are included if they report on a minimum number of days in the season, with no gaps longer than a set maximum (e.g., 14 days).
* Create a dataset at the ori by season level, with the number of reporting days for each ori in each season, and the max gap between reports.
forvalues sn = 1995(1)2023 {
	use "$proc/SeasonDatesNFL", clear
	keep if season == `sn'
	loc regStart = regStart[1]
	loc regEnd   = regEnd[1]+1
		
	* Keep incidents occurring within the season:
	use `reportingdays', clear
	keep if iDateEST >= `regStart' & iDateEST <= `regEnd'
	sort ori iDateEST
	by ori iDateEST: keep if _n==1
	by ori: gen DaysReportedSeason = _N
	by ori: gen gap = iDateEST - cond(_n==1, `regStart', iDateEST[_n-1])
	by ori: egen maxGap = max(gap)
	by ori: replace maxGap = max(maxGap, `regEnd' - iDateEST[_N])
	
	* Create a dataset at the ori x season level:
	by ori: keep if _n==1
	gen season = `sn'
	gen DaysInSeason = `regEnd'-`regStart'+1
	keep ori season DaysReportedSeason maxGap DaysInSeason state FIPS

	append using "$proc/inclusion - windows"
	save 		 "$proc/inclusion - windows", replace
}