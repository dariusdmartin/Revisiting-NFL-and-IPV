***crimedata-step2.do: Combine all NIBRS datasets together
*Note: program called by main.do

*(1) Restrict dataset to Sundays during regular season
*(2) Make everything Eastern time and make the day run from 6 am to 6 am
*(3) Calculate number of nonmissing days by agency

clear all
set memory 6G

import excel using "$data\misc\SeasonDatesNFL.xlsx", firstrow clear
save "$data\misc\SeasonDatesNFL", replace

clear
*load the data and create the Date variable
save "$data\nibrs\out\allyears2a", replace emptyok
forvalues i = 1995(1)2006 {
	use "$data\nibrs\out\year`i'\out`i'all", clear
	capture confirm numeric variable idate
	if _rc == 0 {
		tostring idate, gen(datex)
		gen Date = date(datex,"YMD")
		drop datex idate
	}
	else{
		gen Date = date(idate,"DMY")
		drop idate
	}
	format %td Date
	gen dow = dow(Date)
	* CD keep Mondays, perhaps for incidents after midnight.
	keep if inlist(dow,0,1)
	append using "$data\nibrs\out\allyears2a"
	save "$data\nibrs\out\allyears2a", replace
}

gen year=year(Date)
gen month=month(Date)
gen day=day(Date)

***Code to make all states on eastern time
gen state=substr(ori,1,2)
gen timezone=""
*gen timezone="pacific" if state==??
replace timezone="mountain" if state=="CO"
replace timezone="central"  if inlist(state, "KS", "TN")
replace timezone="eastern"  if inlist(state, "MI", "SC", "VT", "NH", "MA")

gen tempihour=ihour

*make everything eastern time
replace tempihour=ihour+1 if ihour<=22 & timezone=="central"
replace Date=Date+1 if ihour==23 & timezone=="central"
replace tempihour=0 if ihour==23 & timezone=="central"

replace tempihour=ihour+2 if ihour<=21 & timezone=="mountain"
replace Date=Date+1 if (ihour==22 | ihour==23) & timezone=="mountain"
replace tempihour=0 if ihour==22 & timezone=="mountain"
replace tempihour=1 if ihour==23 & timezone=="mountain"

replace tempihour=ihour+3 if ihour<=20 & timezone=="pacific"
replace Date=Date+1 if inlist(ihour,21,22,23) & timezone=="pacific"
replace tempihour=0 if ihour==21 & timezone=="pacific"
replace tempihour=1 if ihour==22 & timezone=="pacific"
replace tempihour=2 if ihour==23 & timezone=="pacific"

replace ihour=tempihour

*assign early morning hours to previous day
replace Date=Date-1 if ihour>=0 & ihour<=4

*replace date variables to reflect 24 hour day which starts at 6 am
* MQ comment: I think this is actually 4am EST. (Look at the previous line)
gen doy=doy(Date)
replace dow=dow(Date)
replace year=year(Date)
replace month=month(Date)
replace day=day(Date)

gen season=year
replace season=season-1 if inlist(month(Date),1,2)

*keep only regular season for Sunday sample
merge n:1 season using "$data\misc\SeasonDatesNFL", keep(match) nogen
keep if Date >= regStart & Date <= regEnd
keep if dow==0
drop dow
*drop Sunday after 9/11/2001 since no games
drop if Date==mdy(9,16,2001)

save "$data/nibrs/out/allyears2a", replace

***Calculate daysreported***
*use "$data/nibrs/out/allyears2a", clear
bysort ori Date: gen qq = _n==1
bysort ori season: egen daysreported  = total(qq)

*Must report for at least 13 out of 17 Sundays during the regular season
drop if daysreported<13
sort Date
save "$data/nibrs/out/allyears2", replace