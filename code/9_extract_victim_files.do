* Project: Card and Dahl Replication 
* Name: Darius Martin, coauthor Jason Query
* Packages: -None-
* Uses: From $datanibrs: all victim files. 
*		From $rawdata: "missing counties fips", "ICPSR NIBRS Codes", CT county correspondence"
*       From $proc: "state FIPS codes", "census counties"
* Creates: "$proc\IPV", "$proc\IPV_hour"
* Description: Creates a dataset of all victim-offender pairs in incidents of aggravated assault, simple assult, or intimidation 
* 		For each [ori ino vseqno], there's one observation for each offender associated with the victim, with indicators with the age, sex, and 			*		relationship of both offender and victim. We drop cases where the offender associated with the victim is the victim.

clear
* Ensure needed rawdata files are present:
foreach f in "CT county correspondence.xlsx" "missing counties fips.xlsx" "ICPSR NIBRS Codes.xlsx" {
	capture confirm file "$rawdata/`f'"
    if _rc {
        di as err "Missing $rawdata/`f' — set build_nibrs to 0 or get replication_data.zip (see README)."
        exit 601
    }
}

save "$proc/IPV_hour", replace emptyok

* Get FIPS codes for agencies with missing county codes in the raw NIBRS data.
import excel using "$rawdata/missing counties fips.xlsx", firstrow clear
tempfile missing_fips
save `missing_fips'

* Get CT county correspondence to fix counties in CT. Needed because we use FIPS codes to merge in "$proc\census counties", which has TIME_ZONE at the county level. CT changed their counties in 2023. Post-2023 NIBRS files use new CT counties, "census counties" uses the old ones.
import excel using "$rawdata/CT county correspondence", firstrow clear
tempfile CT_counties
save `CT_counties'

* Variables needed from the NIBRS victims extracts:
global keep_common_vic "INCNUM INCDATE   V1006 	V1007  V4006 V4018 V4019 V4007 V4008 V4009 V4010 V4011 V4012 V4013 V4014 V4015 V4016"
global keep_common_vic "$keep_common_vic V4031 	V4032  V4033 V4034 V4035 V4036 V4037 V4038 V4039 V4040 V4041 V4042 V4043 V4044 V4045"
global keep_common_vic "$keep_common_vic V4046 	V4047  V4048 V4049 V4050 V20061 V20062 V20063 V20111 V20112 V20113"
global keep_common_vic "$keep_common_vic V50061 V50062 V50063 V50071 V50072 V50073 V50081 V50082 V50083"

* Variables needed from NIBRS incidents and victims extracts, with two different naming conventions:
global keep_bvars  "B1007 B1008 B1012 B2005 B3024"
global keep_bhvars "BH007 BH008 BH012 BH019 BH054"

forvalues i = 1995(1)2024 {
	import excel using "$rawdata/ICPSR NIBRS Codes.xlsx", clear firstrow
	keep if year == `i'
	loc q1 = NIBRS[1]
	
	*** Load victims extract: (One observation per [ori ino vseqno] - one for each victim in an incident).
	if `i' < 2017 {
		use "$datanibrs/ICPSR_`q1'/DS0002/`q1'-0002-Data.dta", clear
    }
    else {
		use "$datanibrs/ICPSR_`q1'/DS0004/`q1'-0004-Data.dta", clear
	}
	capture confirm variable ORI
	if _rc != 0 {
		ren BH003 ORI
	}
	capture confirm variable B1007
	if _rc != 0{
		ren (BH008 BH007 BH012 BH019 BH054) (B1008 B1007 B1012 B2005 B3024 )
	}
  
    ren (ORI B1008 INCNUM V1007 B1012 B3024) (ori state ino ihour agency countyfips)
	ren (V4006 V4018 V4019) (vseqno vage vsex)
	
	* keep city or county agencies
	keep if inlist(agency,1,2)
	
	capture confirm numeric variable INCDATE
	if _rc == 0 {
		tostring INCDATE, gen(datex)
		gen idate = date(datex,"YMD")
		drop datex
	}
	else{
		gen idate  = date(INCDATE,"DMY")
	}
	format %td idate
	
	* keep incidents occurring during the football season: (Aug-Jan.)
	keep if inlist(month(idate),1,8,9,10,11,12)
	drop if month(idate) ==1 & year(idate)==1995
 
	gen vfemale = vsex==0
	sort ori ino vseqno

	* Create assault variable - the most serious assault suffered by the victim (131 - aggravated assault, 132 - simple assault, 133 - intimidation)
	gen assault     = .
	forvalues v= 1(1)10 {
		loc q = 4006+`v'
		replace assault = min(assault, V`q') if inlist(V`q',131,132,133)
	}
	* Only keep assaults:
	keep if !missing(assault)
	label values assault V4007
	
	* Determine the location of the assault:
	* V20061, V20062 and V20063 are the three most serious offenses in the incident, and V20111, V20112 and V20113 give the locations of those offenses.
	gen     location = V20111 if assault == V20061
	replace location = V20112 if assault == V20062
	replace location = V20113 if assault == V20063
	* location is missing if the assault was not one of the three most serious in the incident. 
	drop if missing(location)
	label values location V20111
	label var location "Location of Assault" 

	* Indicate whether the assault occurred at home:
	gen byte home = 0
	replace  home = 1 if location==20
	
	* Drop if there's an unknown number of offenders:
	drop if V50061==0
	
	* V4031 is sequence number of the first offender associated with the victim, V4032 is the second offender associated with the victim, etc. 
	rename (V4031 V4033 V4035 V4037 V4039 V4041 V4043 V4045 V4047 V4049) (offender1 offender2 offender3 offender4 offender5 offender6 offender7 offender8 offender9 offender10)
	rename (V4032 V4034 V4036 V4038 V4040 V4042 V4044 V4046 V4048 V4050) (vrelate1  vrelate2  vrelate3  vrelate4  vrelate5  vrelate6  vrelate7  vrelate8  vrelate9  vrelate10)
	* Get the report date indicator:
	rename V1006 ReportDateIndicator
	* The data is currently at the (ori x ino x vseqno) level. One obs for each victim in each incident recorded by each agency.
	keep ori ino vseqno ihour idate countyfips state agency assault location home vfemale vage offender* vrelate* V5006* V5007* V5008* ReportDateIndicator

	* Create one observation for each victim-offender pair.
	* Not using reshape because, with 10 possible offenders per victim, this would expand the dataset by 10.
	* The approach below is needed because offenders may not be listed in sequence, e.g., V4033 (offender2) is missing, but there's an offender listed in V4035 (offender 3). Found one such gap in 1996. 
	* Find the last populated, non-missing offender number:
	gen offender_populated = .
	forvalues v = 10(-1)1 {
		replace offender_populated = `v' if missing(offender_populated) & offender`v' > 0 & !missing(offender`v')
	}
	replace offender_populated = 0 if missing(offender_populated)
	expand offender_populated
	sort ori ino vseqno
	gen offender = .
	gen vrelate = .
	forvalues v = 1(1)10 {
		by ori ino vseqno: replace offender = offender`v' if _n==`v'
		by ori ino vseqno: replace vrelate  = vrelate`v'   if _n==`v'
	}
	qui count if missing(offender) | offender <= 0
	di "`i': `r(N)' rows dropped for gapped offender slots"
	drop if missing(offender) | offender <= 0
	label values vrelate V4032
	
	* vrelate gives relationship between victim and offender.
	sort ori ino vseqno offender
	order ori ino vseqno offender vrelate
	drop offender?* vrelate?*
	
	* Drop if the victim is offender. (Happens when the same person is both a victim and an offender within the same incident, e.g., two people each assault the other.)
	drop if vrelate==13

	gen     oage = V50071 if offender==V50061 
	replace oage = V50072 if offender==V50062
	replace oage = V50073 if offender==V50063 
	
	gen     osex = V50081 if offender==V50061
	replace osex = V50082 if offender==V50062
	replace osex = V50083 if offender==V50063
 
	keep ori ino ihour idate countyfips state agency assault location home vseqno vfemale vage offender vrelate oage osex ReportDateIndicator

	gen byte spouse       = vrelate==1
	gen byte commonspouse = vrelate==2
	gen byte exspouse     = vrelate==21
	gen byte bgfriend     = vrelate == 18
	
	* child indicates the victim is the child, grandchild, stepchild, or child of boyfriend/girlfriend of the offender.
	* Otherfam indicates the victim is the parent, sibling, grandparent, inlaw, stepparent, step-sibling, other family of the offender.

	gen byte child    = inlist(vrelate,5,7,10,19)
	gen byte otherfam = inlist(vrelate,3,4,6,8,9,11,12)
	gen byte known    = inlist(vrelate,14,15,16,17,20,22,23,24)
	gen byte stranger = vrelate==25

	gen intpartner =spouse | commonspouse | exspouse | bgfriend
	gen anyspouse  =spouse | commonspouse | exspouse
	gen extfamily  =child  | otherfam
	gen relmissing =missing(vrelate) | (!intpartner & !extfamily & !known & !stranger)
	
	* Drop if same offender commits the same offense against the same relative (This is taken from CD code.)
	* For example, if an offender hits two friends, count that as one friend-assault incident, not two incidents.  However, if an offender hits both a spouse and a child, then record that as a spouse assault and also a child assault
	bysort ori ino offender assault vrelate (vseqno): keep if _n==1
	
	sort ori ino vseqno offender	
	
	drop if strpos(ori,"S")>2 & state=="VA"
	* Make undetermined counties missing:
	replace countyfips = . if countyfips == -9
	replace ihour      = . if ihour < 0

	*** Get TIME_ZONE from census counties to calculate Eastern clock time.
	* Update missing FIPS codes.
	merge n:1 ori using `missing_fips', update keepusing(countyfips)
	drop if _merge==2
	drop _merge
	merge n:1 state using "$proc/state FIPS codes", keep(master match) nogen
	if `i' >= 2023 {
		merge n:1 ori using `CT_counties', keep(master match)
		* Replace the new post 2023 CT county codes with old ones (used by census_counties.)
		replace countyfips = oldfips if _merge==3
		drop _merge oldfips newfips CTcity
	}
	
	gen str5 FIPS = statefips+string(countyfips, "%03.0f")
	merge n:1 FIPS using "$proc/census counties", keepusing(TIME_ZONE) keep(match) nogen
	
	* Calculate Eastern clock time. This is complicated due to daylight savings
	gen year = year(idate)

	gen     DST_start = mdy(3,8,year)                if year >=2007
	replace DST_start = DST_start + 7-dow(DST_start) if year >=2007 & dow(DST_start)!=0
	replace DST_start = mdy(4,1,year)                if year < 2007
	replace DST_start = DST_start + 7-dow(DST_start) if year < 2007 & dow(DST_start)!=0
	
	gen     DST_end   = mdy(11,1,year)               if year >=2007
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
	drop DST_start DST_end
	drop if missing(ihour)
	
	* osex is 1 for male offenders
	gen byte ipmf=intpartner & osex==1 & vfemale==1
	
	keep ori iDateEST state ihourEST ipmf home ReportDateIndicator
	bys  ori iDateEST ihourEST: egen ipmfhomehour  = total(ipmf==1 & home==1)
	by   ori iDateEST ihourEST: egen ipmfcleanhour = total(ipmf==1 & home==1 & ReportDateIndicator==0 )     
	by   ori iDateEST ihourEST: keep if _n==1
	
	drop ReportDateIndicator ipmf home
	append using  "$proc/IPV_hour"
	save          "$proc/IPV_hour", replace
}
drop if inlist(state,"AK","HI")
save   "$proc/IPV_hour", replace

/* Don't use the CD date here as it's not needed for replication. CD's dependent variable is IPV occuring between 12pm-12am Eastern time. They never use violence occurring after midnight.
* The 24 hour day running from 5:00 - 4:59 is only relevant for the inclusion criteria.
* replace date variables to reflect 24 hour day running from 5AM EST - 4:59AM EST next day. (In PST, the 24-hour day starts at 2AM and ends at 1:59AM next day.)
* This ensures that assults that happen at 10pm PST = 1am EST are correctly assigned to the Sunday with the NFL game.
* Similarly, events at 1am in NYC are linked with the previous Sunday/NFL game day.
*replace iDateEST=iDateEST-1 if ihourEST>=0 & ihourEST<=4  
* Note: CD say their 24 hour day starts at 6 am, but their code implies the day starts at 5am. (See crimedata_step2 line 54)
*/

sort ori iDateEST ihourEST

foreach vr in home clean {
	by ori iDateEST: egen ipmf`vr'1214 = total(ipmf`vr'hour * inlist(ihourEST,12,13,14))
	by ori iDateEST: egen ipmf`vr'1517 = total(ipmf`vr'hour * inlist(ihourEST,15,16,17))
	by ori iDateEST: egen ipmf`vr'1820 = total(ipmf`vr'hour * inlist(ihourEST,18,19,20))
	by ori iDateEST: egen ipmf`vr'2123 = total(ipmf`vr'hour * inlist(ihourEST,21,22,23))
}
by ori iDateEST: keep if _n==1
ren iDateEST Date
drop ipmfhomehour ipmfcleanhour ihourEST

* Keep incidents occuring on Sundays:
keep if dow(Date) == 0
drop state
sort ori Date
save "$proc/IPV", replace

use  "$proc/IPV_hour", clear
* Only keep hours when IPV is reported:
drop if ipmfhomehour == 0 & ipmfcleanhour==0
save  "$proc/IPV_hour", replace 