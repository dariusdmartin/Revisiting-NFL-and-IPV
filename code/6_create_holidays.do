* Project: Card and Dahl Replication 
* Name: Darius Martin, coauthor Jason Query
* Packages needed: -None-
* Uses: "$proc\NFLData_All"
* Creates: "$proc\holidays"
* Description: "$proc\holidays" has one observation for each date of an NFL game, with indicators for holidays that fall on those dates.

* Get a list of all dates of NFL games:
use "$proc\NFLData_All", clear
gen Date = date(date,"MDY")
format %td Date
drop date
keep Date
gen season = year(Date)
replace season = season-1 if month(Date)==1
bys Date: keep if _n==1

gen christeve  = month(Date)==12 & day(Date)==24
gen christday  = month(Date)==12 & day(Date)==25
gen newyeareve = month(Date)==12 & day(Date)==31
gen newyearday = month(Date)==1  & day(Date)==1
gen halloween  = month(Date)==10 & day(Date)==31

* ── Thanksgiving Weekend:  ──────────────────────────────
* Thanksgiving is the 4th Thursday in Nov.
* days to 1st Th. in Nov:
gen year = year(Date)
gen     daystoTh1 = 4 - dow(mdy(11,1,year))
replace daystoTh1 = daystoTh1 + 7 if daystoTh1 < 0
gen thanksday     = mdy(11,1,year) + daystoTh1 + 21
assert dow(thanksday)==4 & inrange(day(thanksday),22,28)

* thankswkd indicates the Thursday-Sunday surrounding Thanksgiving day
gen thankswkd = Date-thanksday >= 0 & Date-thanksday <=3
drop daystoTh1 thanksday

* ── Labor Day Weekend:  ──────────────────────────────
* Labor Day is the 1st Monday in September
gen     daystoM1 = 1 - dow(mdy(9,1,year))
replace daystoM1 = daystoM1 + 7 if daystoM1 < 0
gen laborday = mdy(9,1,year)+daystoM1
assert dow(laborday)==1 & inrange(day(laborday),1,7)

gen laborwkd = Date-laborday >= -3 & Date-laborday<=0
drop daystoM1 laborday

* ── Columbus Day Weekend:  ──────────────────────────────
* 2nd Monday in October:
gen daystoM1 = 1-dow(mdy(10,1,year))
replace daystoM1 = daystoM1 + 7 if daystoM1 <0
gen columday = mdy(10,1,year)+daystoM1 + 7 
gen columwkd = Date-columday >= -3 & Date-columday <=0
assert dow(columday)==1 & inrange(day(columday),8,14)
drop daystoM1 columday

* ── Veterans Day Weekend:  ──────────────────────────────
* An indicator for veterans day weekend. This indicator is always set to zero in years when Veterans day falls on Tuesday or Wednesday.
* If 11/11 is Sun or Mon, the weekend runs Friday through Monday.
* If 11/11 is Fri or Sat, the weekend runs Friday through Sunday.
* If 11/11 is Thu, the weekend runs Thursday through Sunday.
gen vetday = mdy(11,11,year)
gen dowVet = dow(vetday)
gen vetst     = 0 if inlist(dowVet,4,5)
replace vetst =  -1 if dowVet==6
replace vetst = -2 if dowVet==0
replace vetst = -3 if dowVet==1
gen vetEnd = 3 if dowVet==4 
replace vetEnd = 2 if dowVet==5
replace vetEnd = 1 if inlist(dowVet,0,6)
replace vetEnd = 0  if dowVet==1
gen vetwkd = inrange(Date-vetday,vetst,vetEnd)
drop vetday dowVet vetst vetEnd year

save "$proc\holidays", replace