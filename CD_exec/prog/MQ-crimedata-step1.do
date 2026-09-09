***crimedata-step1.do: Read in NIBRS Stata data for all years
*Note: program called by main.do

clear all

*read in NIBRS data year-by-year
forvalues i = 1995(1)2006 {
  di "year: `i'"
  *** Ensure the needed directories exist, create them if not:
  capture mkdir "$data\nibrs"
  capture mkdir "$data\nibrs\out"
  capture mkdir "$data\nibrs\out\year`i'"

  *** Get the NIBRS Data:
  import excel using "$data\misc\ICPSR NIBRS Codes.xlsx", clear firstrow
  keep if year == `i'
  loc q1 = NIBRS[1]
  
  use "$datanibrs\ICPSR_`q1'\DS0001\\`q1'-0001-Data.dta", clear
  capture confirm variable ORI
  if _rc != 0 {
  	ren BH003 ORI
  }
  capture confirm variable B1007
  if _rc != 0{
  	ren (BH007 BH012 BH019 BH054) (B1007 B1012 B2005 B3024)
  }
  capture confirm variable STATE
  if _rc != 0 {
  	ren BH002 STATE 
  }
  rename (ORI B1007 B1012 B2005 STATE) (ori city agency pop1 statenibrs)
  
  *must be a city or county agency
  *cannot be a college, state police, or special agency
  keep if inlist(agency,1,2)
  *drop if no population number
  drop if missing(pop1)
  
  *statefips codes for the NFL teams in our sample
  *8=colorado, 20=kansas, 25=massachussetts, 26=michigan, 45=south carolina, 47=tennessee, 33=new hampshire (new england patriots), 50=vermont (new england patriots)
  quietly gen statefips=8 if statenibrs==5
  quietly replace statefips=20 if statenibrs==15
  quietly replace statefips=25 if statenibrs==20
  quietly replace statefips=26 if statenibrs==21
  quietly replace statefips=45 if statenibrs==39
  quietly replace statefips=47 if statenibrs==41
  quietly replace statefips=33 if statenibrs==28
  quietly replace statefips=50 if statenibrs==44
  *only keep states in our estimation sample
  keep if inlist(statefips, 8,20,25,26,45,47,33,50)

  quietly replace B3024=. if B3024==-9 | B3024==900
  ren B3024 countyfips1
  
  keep ori city agency pop1 statefips countyfips1
  bysort ori: keep if _n==1
 
  save "$data\nibrs\out\year`i'\out`i'b3", replace

  **************** INCIDENTS ****************
  use "$datanibrs\ICPSR_`q1'\DS0001\\`q1'-0001-Data.dta", clear
  rename (ORI INCNUM INCDATE V1007) (ori ino idate ihour)
 
  keep ori ino idate ihour
  sort ori ino
  save "$data\nibrs\out\year`i'\out`i'b4", replace

  **************** CREATE AN OFFENSE FILE ****************
  use "$datanibrs\ICPSR_`q1'\DS0001\\`q1'-0001-Data.dta", clear
  capture confirm variable B1012
  if _rc != 0 {
  	ren BH012 B1012
  }
  capture confirm variable ORI
  if _rc != 0 {
  	ren (BH003 BH004) (ORI INCNUM)
  }
  rename (ORI INCNUM B1012) (ori ino agency)

  keep if inlist(agency,1,2)
  keep ori ino V2006* V2008* V2009* V2010* V2011*
  reshape long V2006 V2008 V2009 V2010 V2011, i(ori ino)
  drop if inlist(V2006,-8,-5)
  drop if missing(V2006)
  ren (V2006 V2008 V2009 V2010 V2011) (offensecode offusing1 offusing2 offusing3 location)

  sort ori ino
  keep ori ino offensecode offusing* location
  save "$data\nibrs\out\year`i'\out`i'b5", replace

  **************** VICTIMS ****************
  clear
  use "$datanibrs\ICPSR_`q1'\DS0002\\`q1'-0002-Data.dta", clear
  capture confirm variable ORI
  if _rc != 0 {
  	ren BH003 ORI
  }
  
  ren (ORI INCNUM V4018 V4019) (ori ino vage vsex)
  replace vage = . if vage == -7
  gen vfemale = vsex==0
  quietly replace vfemale = . if vsex==-7
  drop vsex
  rename (V4026 V4027 V4028 V4029 V4030) (vinjury1 vinjury2 vinjury3 vinjury4 vinjury5)
  rename (V4032 V4034 V4036 V4038 V4040 V4042 V4044 V4046 V4048 V4050) (vrelate1 vrelate2 vrelate3 vrelate4 vrelate5 vrelate6 vrelate7 vrelate8 vrelate9 vrelate10)
  
  *Note: vrelateX can also equal "RU" which is "relationship unknown" -- we treat these as missing
  quietly gen byte spouse=.
  quietly replace spouse=vrelate1==1 | vrelate2==1 | vrelate3==1 | vrelate4==1 | vrelate5==1 | vrelate6==1 | vrelate7==1 | vrelate8==1 | vrelate9==1 | vrelate10==1
  quietly gen byte commonspouse=.
  quietly replace commonspouse=vrelate1==2 | vrelate2==2 | vrelate3==2 | vrelate4==2 | vrelate5==2 | vrelate6==2 | vrelate7==2 | vrelate8==2 | vrelate9==2 | vrelate10==2
  quietly gen byte exspouse=.
  quietly replace exspouse=vrelate1==21 | vrelate2==21 | vrelate3==21 | vrelate4==21 | vrelate5==21 | vrelate6==21 | vrelate7==21 | vrelate8==21 | vrelate9==21 | vrelate10==21
  quietly gen byte bgfriend=.
  quietly replace bgfriend=(vrelate1==18 | vrelate2==18 | vrelate3==18 | vrelate4==18 | vrelate5==18 | vrelate6==18 | vrelate7==18 | vrelate8==18 | vrelate9==18 | vrelate10==18)
  quietly gen byte child=.
   * MQ interpretation: child "CH", grandchild "GC", stepchild "SC", or child of boyfriend/girldfriend "CF"
  quietly replace child = inlist(vrelate1,5,7,10,19) | inlist(vrelate2,5,7,10,19) | inlist(vrelate3,5,7,10,19) | inlist(vrelate4,5,7,10,19) ///
          | inlist(vrelate5,5,7,10,19) | inlist(vrelate6,5,7,10,19) | inlist(vrelate7,5,7,10,19) | inlist(vrelate8,5,7,10,19) ///
          | inlist(vrelate9,5,7,10,19) | inlist(vrelate10,5,7,10,19)
  quietly gen byte otherfam=.
  * MQ interpretation: parent "PA", sibling "SB", grandparent "GP", inlaw "IL", stepparent "SP", step-sibling "SS", other family "OF", offender "VO"
  quietly replace otherfam=inlist(vrelate1,3,4,6,8,9,11,12,13) | inlist(vrelate2,3,4,6,8,9,11,12,13) | inlist(vrelate3,3,4,6,8,9,11,12,13)
  quietly replace otherfam = 1 if inlist(vrelate4,3,4,6,8,9,11,12,13) | inlist(vrelate5,3,4,6,8,9,11,12,13) | inlist(vrelate6,3,4,6,8,9,11,12,13)
  quietly replace otherfam = 1 if inlist(vrelate7,3,4,6,8,9,11,12,13) | inlist(vrelate8,3,4,6,8,9,11,12,13) | inlist(vrelate9,3,4,6,8,9,11,12,13) | inlist(vrelate10,3,4,6,8,9,11,12,13) 
  quietly gen byte known=.
  quietly replace known=inlist(vrelate1,14,15,16,17,20,22,23,24) | inlist(vrelate2,14,15,16,17,20,22,23,24) ///
          | inlist(vrelate3,14,15,16,17,20,22,23,24) | inlist(vrelate4,14,15,16,17,20,22,23,24) | inlist(vrelate5,14,15,16,17,20,22,23,24) ///
          | inlist(vrelate6,14,15,16,17,20,22,23,24) | inlist(vrelate7,14,15,16,17,20,22,23,24) | inlist(vrelate8,14,15,16,17,20,22,23,24) ///
		  | inlist(vrelate9,14,15,16,17,20,22,23,24) | inlist(vrelate10,14,15,16,17,20,22,23,24) 
  quietly gen byte stranger=.
  quietly replace stranger=vrelate1==25 | vrelate2==25 | vrelate3==25 | vrelate4==25 | vrelate5==25 | vrelate6==25 | vrelate7==25 | vrelate8==25 | vrelate9==25 | vrelate10==25
  
  gen byte injuryN = vinjury1==1
  gen byte injuryS = inlist(vinjury1,3,4,5,6,7,8) | inlist(vinjury2,3,4,5,6,7,8) | inlist(vinjury3,3,4,5,6,7,8) | inlist(vinjury4,3,4,5,6,7,8) | inlist(vinjury5,3,4,5,6,7,8)
  gen byte injuryM = vinjury1==2 | vinjury2==2 | vinjury3 == 2 | vinjury4==2 | vinjury5==2
  
  keep ori ino vage vfemale injuryN injuryM injuryS vrelate* spouse commonspouse exspouse bgfriend child otherfam known stranger
  sort ori ino
  save "$data\nibrs\out\year`i'\out`i'b7", replace

  **************** OFFENDER FILE ****************
  clear
  use "$datanibrs\ICPSR_`q1'\DS0003\\`q1'-0003-Data.dta", clear
  ren (ORI INCNUM V5006 V5007 V5008) (ori ino oseqno oage osex)
  quietly replace oage=. if oage<=0
  gen ofemale=osex==0
  quietly replace ofemale=. if osex==-7
  drop osex
  keep ori ino oseqno oage ofemale
  sort ori ino
  save "$data\nibrs\out\year`i'\out`i'b8", replace

*merge different reporting segments together
  cd "$data\nibrs\out\year`i'"
  use out`i'b4
  merge ori ino using out`i'b5
  tab _merge
  drop _merge
  sort ori ino
  merge ori ino using out`i'b8
  tab _merge
  drop _merge
  sort ori ino
  merge ori ino using out`i'b7
  tab _merge
  drop _merge
  sort ori
  merge ori using out`i'b3
  tab _merge
  *drop states not in our sample
  *drop if no crime information
  drop if _merge!=3
  drop _merge
  
  *sort ori  
  *merge ori using out`i'b1
  *tab _merge
  *drop states not in our sample
  *drop if no information on agency type
  *drop if _merge!=3
  *drop _merge

*Code to account for multiple victims per offender
*do not double count if same offender committing the same offense against the same category of individual
*For example, if an offender hits two friends, count that as one friend-assault incident, not two incidents.  However, if an offender hits both a spouse and a child, then record that as a spouse assault and also a child assault
  quietly gen flagdrop=.
  gen intpartner=spouse|commonspouse|exspouse|bgfriend
  gen anyspouse=spouse|commonspouse|exspouse
  gen extfamily=child|otherfam
  gen missing=missing(vrelate1) | (!intpartner & !extfamily & !known & !stranger)

  sort ori ino oseqno offensecode
  replace flagdrop=1 if ori==ori[_n-1] & ino==ino[_n-1] & oseqno==oseqn[_n-1] & offensecode==offensecode[_n-1]
  sort ori ino oseqno offensecode flagdrop

  replace intpartner=1 if intpartner[_n-1]==1 & flagdrop[_n-1]==1
  replace anyspouse=1 if anyspouse[_n-1]==1 & flagdrop[_n-1]==1
  replace bgfriend=1 if bgfriend[_n-1]==1 & flagdrop[_n-1]==1
  replace extfamily=1 if extfamily[_n-1]==1 & flagdrop[_n-1]==1
  replace child=1 if child[_n-1]==1 & flagdrop[_n-1]==1
  replace known=1 if known[_n-1]==1 & flagdrop[_n-1]==1
  replace stranger=1 if stranger[_n-1]==1 & flagdrop[_n-1]==1
  replace missing=1 if missing[_n-1]==1 & flagdrop[_n-1]==1

  drop if flagdrop==1
  drop flagdrop

  compress

  save out`i'all, replace
}
**# Bookmark #1

use "$data/nibrs/out/year1995/out1995all", replace
forvalues i = 1996(1)2006 {
  di "year: `i'"
  append using "$data/nibrs/out/year`i'/out`i'all"
}

save "$data/nibrs/out/allyears1", replace

