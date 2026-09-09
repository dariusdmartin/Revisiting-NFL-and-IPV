***crimedata-step3.do: Collapse NIBRS data to hourly crime rates by agency
*Note: program called by main.do

clear all
set memory 6G

*****Create mdytodoy and oritofips datasets*****
use "$data/nibrs/out/allyears2", replace
*Create and merge a correspondence between ori and statefips agency city
*Also keep track of pop1
* MQ comment: This is used later to drop filled-in observations from before the ori started reporting.
* MQ: Corrected two mistakes from CD. First, they sorted by year ori, rather than season. This incorrectly created observations in Jan for agencies that were reporting for the Fall NFL season later in the year.
* MQ: e.g., ori=="CO0010200" enters the data in Sep. 2005.
* MQ second, they didn't drop agencies that don't report the incident hour here. These are dropped later, but when this is merged back in get dates when the agency reported to NIBRS (and drop dates when the agency wasn't reporting that are 
* created by the fill-in command), the agency is incorrectly included as reporting zero crime on those dates.
drop if missing(ihour) | ihour < 0

keep season ori statefips agency city pop1
bysort season ori: keep if _n==1
save "$data/misc/oriseason", replace

*****Collapse to daily crime rates*****
use "$data/nibrs/out/allyears2", replace

gen byte assault=inlist(offensecode,131,132,133)
gen byte assaultmf=assault & ofemale==0 & vfemale==1

gen byte home=location==20
gen byte away=location!=20

gen byte ip=intpartner & assault
gen byte sp=anyspouse & assault
gen byte bg=bgfriend & assault
gen byte fa=extfamily & assault
gen byte ch=child & assault
gen byte kn=known & assault

gen byte alcohol=(offusing1==1 | offusing2==2 | offusing3==3)
gen byte drugs=(offusing1==1 | offusing2==2 | offusing3==3)
replace alcohol=alcohol | drugs

gen byte ipmf=ip & ofemale==0 & vfemale==1
gen byte ipfm=ip & ofemale==1 & vfemale==0
gen byte bgmf=bg & ofemale==0 & vfemale==1
gen byte spmf=sp & ofemale==0 & vfemale==1

gen byte ipmfalc=ipmf & alcohol

gen byte ipmfa=ipmf & offensecode==131
gen byte ipmfb=ipmf & offensecode==132
gen byte ipmfc=ipmf & offensecode==133

gen byte ipmfN=ipmf & injuryN
gen byte ipmfS=ipmf & injuryS
gen byte ipmfM=ipmf & injuryM

gen byte ipmfaSM=ipmfa|ipmfM|ipmfS
gen byte ipmfbcN=(ipmfb|ipmfc) & !ipmfM & !ipmfS

gen ipmf29m=ipmf & oage<30
gen ipmf30p=ipmf & oage>=30 & oage!=.

gen byte ipmfaway=ipmf & away
gen byte ipfmaway=ipfm & away

global home = "ipmf ipfm spmf bgmf fa kn ipmfalc ipmfaSM ipmfbcN ipmf29m ipmf30p"

foreach var of varlist $home {
  gen byte `var'home=`var' & home
}

global vars1 = "ipmfhome"
global vars2 = "ipmfaway ipfmhome ipfmaway spmfhome bgmfhome fahome knhome"
global vars3 = "ipmfalchome ipmfaSMhome ipmfbcNhome ipmf29mhome ipmf30phome"

drop if missing(ihour)
drop if ihour < 0
gen iblock=ihour

* MQ comment: This collapse command creates a new dataset with the total amount of incidents of IPV (ipmfhome - intimiate partner male-on-female violence occuring at home)
* At the (ori Date and hour) level. Since doy and daysreported is constant within (ori Date iblock), the (mean) in collapse just retains those values.
* Note that if no crime is reported in the ori during a particular hour, there will be no observation for that hour. 
collapse (sum) $vars1 $vars2 $vars3 (mean) doy daysreported , by(ori Date iblock) fast

*Fill in missings
*i.e., if no crime reported for a given hour interval, fill in a value of 0 for that interval
*baseline regressions use observations with a filled-in value of 0 for ip assaults if any crime was reported during the 24 hour day (which runs from 6 am to 6am)
*baseline regressions do not use observations which have no crime reported for the entire 24 hour period
*in a robustness check these filled-in observations with no crime reported for the entire 24 hour period are used
*Need to create a single yeardoy variable (note leap years in 1994, 2000, 2004)
gen year=year(Date)
gen yeardoy=1000*year + doy
drop if year==1994
compress
* MQ comment: This command creates a dataset with an observation for every possible combination of (ori yeardoy iblock). 
* MQ comment: When they "fill in a value of 0" for missing hour intervals, then fill in zeros in years when the ORI is not reporting to NIBRS.
* MQ comment: They solve this problem in the next section: merge in oritofips.dta by year and ori, which has an obs for year ori in each year when the ori reports to NIBRS, and drop unmatched observations in allyears3.
fillin ori yeardoy iblock
replace year=int(yeardoy/1000) if year==.
replace doy=yeardoy-(year*1000) if doy==.
sort year ori
* Alternative to the CD merge:
replace Date = mdy(1,1,year) + doy-1 if _fillin == 1
gen season = year
replace season = year-1 if inlist(month(Date),1,2)
save "$data\nibrs\out\allyears3a", replace

***************
*Merge in ori stuff
use "$data/misc/oriseason", clear
merge 1:n season ori using "$data/nibrs/out/allyears3a"
*drop ori's with no observations for that year (created by fillin command)
drop if _merge==2
drop if _merge==1
drop _merge
*sort statefips countyfips city agency year
save "$data\nibrs\out\allyears3c", replace
 
***************
***Clean up and add fips codes
use "$data\nibrs\out\allyears3c", clear
sort ori Date iblock

*Create orinum as a numeric variable.
encode ori, gen(orinum)
/*
gen orinum=ori

*note: denver has "DPD" in the 2-4 positions, I changed to "999", which doesn't conflict with any other assigned number for Colorado
replace orinum=subinstr(orinum,"DPD","999",.)
*note: memphis, TN has a "MPD" in the 3-5 positions, I change to a "999" which doesn't conflict
replace orinum=subinstr(orinum,"MPD","999",.)
replace orinum="TN9950000" if orinum=="TNTBI0000"

replace orinum=subinstr(orinum,"CO","8",.)
replace orinum=subinstr(orinum,"KS","20",.)
replace orinum=subinstr(orinum,"MA","25",.)
replace orinum=subinstr(orinum,"MI","26",.)
replace orinum=subinstr(orinum,"SC","45",.)
replace orinum=subinstr(orinum,"TN","47",.)
replace orinum=subinstr(orinum,"NH","33",.)
replace orinum=subinstr(orinum,"VT","50",.)

destring orinum, replace
*/
* MQ: Create an indicator for any crime reported on a given day: (Alternative to _fillintot in the CD code.)
gen AnyCrimeDate = _fillin == 0
by ori Date: replace AnyCrimeDate = AnyCrimeDate[_n-1] if _fillin==1 & _n>1
by ori Date: replace AnyCrimeDate = AnyCrimeDate[_N] 
label variable AnyCrimeDate "Indicates whether any crime was reported on that day"
* MQ: Replace missing values of the variable daysreported created by the fillin command. (Alternative to the capture gen command after reshape in the CD code.)
* MQ note: In CD's alternative "capture gen daysreported" command, daysreported will be missing for any day when no crime is reported.
egen meandays = mean(daysreported), by(ori season)
drop daysreported _fillin
ren meandays daysreported

*Reshape data so that all collapsed hourly measures appear in one observation (not a separate obs for each hour) 
reshape wide $vars1 $vars2 $vars3, i(orinum Date) j(iblock)
*MQ comment: the data currently is at the (ori yeardoy iblock) level, where there's one obs for every hour of every Sunday of the season.
*CD command: reshape wide $vars1 $vars2 $vars3 _fillin daysreported, i(orinum Date) j(iblock)

gen teama=""
replace teama="den" if statefips==8
replace teama="kan" if statefips==20
replace teama="nen" if statefips==25
replace teama="det" if statefips==26
replace teama="car" if statefips==45
replace teama="ten" if statefips==47
replace teama="nen" if statefips==33
replace teama="nen" if statefips==50
sort teama Date

/*create a dummy for whether any crime was reported on that day
capture gen _fillintot=min(_fillin0,_fillin1,_fillin2,_fillin3,_fillin4,_fillin5,_fillin6,_fillin7,_fillin8,_fillin9,_fillin10,_fillin11,_fillin12,_fillin13,_fillin14,_fillin15,_fillin16,_fillin17,_fillin18,_fillin19,_fillin20,_fillin21,_fillin22,_fillin23)
drop _fillin0 _fillin1 _fillin2 _fillin3 _fillin4 _fillin5 _fillin6 _fillin7 _fillin8 _fillin9 _fillin10 _fillin11 _fillin12 _fillin13 _fillin14 _fillin15 _fillin16 _fillin17 _fillin18 _fillin19 _fillin20 _fillin21 _fillin22 _fillin23

capture gen daysreported=min(daysreported0,daysreported1,daysreported2,daysreported3,daysreported4,daysreported5,daysreported6,daysreported7,daysreported8,daysreported9,daysreported10,daysreported11,daysreported12,daysreported13,daysreported14,daysreported15,daysreported16,daysreported17,daysreported18,daysreported19,daysreported20,daysreported21,daysreported22,daysreported23)

drop daysreported0 daysreported1 daysreported2 daysreported3 daysreported4 daysreported5 daysreported6 daysreported7 daysreported8 daysreported9 daysreported10 daysreported11 daysreported12 daysreported13 daysreported14 daysreported15 daysreported16 daysreported17 daysreported18 daysreported19 daysreported20 daysreported21 daysreported22 daysreported23
*/
*create assault variables for the twelve hour period between noon and midnight
global vars1 = "ipmfhome*"
global vars2 = "ipmfaway* ipfmhome* ipfmaway* spmfhome* bgmfhome* fahome* knhome*"
global vars3 = "ipmfalchome* ipmfaSMhome* ipmfbcNhome* ipmf29mhome* ipmf30phome*"

local vars $vars1 $vars2 $vars3
    foreach var of varlist `vars' {
    qui replace `var' = 0 if missing(`var')
  }

gen ipmfhome1214=ipmfhome12+ipmfhome13+ipmfhome14
gen ipmfhome1517=ipmfhome15+ipmfhome16+ipmfhome17
gen ipmfhome1820=ipmfhome18+ipmfhome19+ipmfhome20
gen ipmfhome2123=ipmfhome21+ipmfhome22+ipmfhome23

global vars1 = "ipmfhome"
global vars2 = "ipmfaway ipfmhome ipfmaway spmfhome bgmfhome fahome knhome"
global vars3 = "ipmfalchome ipmfaSMhome ipmfbcNhome ipmf29mhome ipmf30phome"

local vars "$vars1 $vars2 $vars3"
    foreach var in `vars' {
  *  di "`var'"
    gen `var'tot = `var'12+`var'13+`var'14+`var'15+`var'16+`var'17+`var'18+`var'19+`var'20+`var'21+`var'22+`var'23
    drop `var'0 `var'1 `var'2 `var'3 `var'4 `var'5 `var'6 `var'7 `var'8 `var'9 `var'10 `var'11 `var'12 `var'13 `var'14 `var'15 `var'16 `var'17 `var'18 `var'19 `var'20 `var'21 `var'22 `var'23
}

compress

*create main nibrs dataset by hour
save "$data/misc/nibrsihour", replace
