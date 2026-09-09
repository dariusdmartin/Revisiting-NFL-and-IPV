***tables.do: Tables and Figures for the Paper and Online Appendix Tables
*Note: program called by main.do
*Note: use the Stata command "poisson" to get clustered standard errors; however, it takes substantially longer than "xtpoisson"

clear all
set matsize 11000
set memory 2G

global basevars="upsetlossbase closelossbase upsetwinbase predwinbase predclosebase predlossbase"
global smallhh = "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather="hot hiheatindx cold windy anyrain anysnow"

***Create estimation datasets
use "$data/merge/final", clear

*create a sample for estimating the robustness check on how to treat missings as zeros
gen insamp=regularseason & dow==0 & AnyCrimeDate==1 
egen teamseason = group(teama season)
qui tab orinum, gen(oo)
save fullsample, replace

*create an estimation sample which only includes observations in baseline regression
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
keep if e(sample)
drop teamseason
egen teamseason = group(teama season)
drop oo*
qui tab orinum, gen(oo)
save "$data/merge/estsample", replace

***Tables
/*
***Table 1 -- Summary Statistics for Intimate Partner Violence, NIBRS data, 1995-2006
capture log close
log using $out/table1, text replace

use $data/merge/estsample, replace
replace insamp=regularseason & dow==0 & _fillintot==0

gen ipmftot=ipmfhometot+ipmfawaytot
gen ipfmtot=ipfmhometot+ipfmawaytot
gen iptot=ipmftot + ipfmtot

global popvar1 = "ip ipmf ipmfhome spmfhome bgmfhome ipmfaway ipfm ipfmhome ipfmaway"	
global popvar2 = "ipmfalchome ipmfbcNhome ipmfaSMhome ipmf29mhome ipmf30phome"

foreach i in $popvar1 $popvar2 {
  gen `i'pop=(`i'tot/pop1)*100000
}

global popvar3 = "ipmfhome1214 ipmfhome1517 ipmfhome1820 ipmfhome2123"
foreach i in $popvar3 {
  gen `i'pop=(`i'/pop1)*100000
}

sum ippop ipmfpop ipmfhomepop spmfhomepop bgmfhomepop ipmfawaypop ipfmpop ipfmhomepop ipfmawaypop if insamp
sum ipmfalchomepop ipmfbcNhomepop ipmfaSMhomepop ipmf29mhomepop ipmf30phomepop if insamp
sum ipmfhome1214pop ipmfhome1517pop ipmfhome1820pop ipmfhome2123pop if insamp

*To get fraction for the small category cities, take (rate per 100,000 for small)*(obs for small * ave pop for small / 100,000) divided by (rate per 100,000 for small)*(obs for small * ave pop for small / 100,000) + (rate per 100,000 for large)*(obs for large * ave pop for large / 100,000)
sum ipmfhomepop pop1 if insamp & pop1<50000
sum ipmfhomepop pop1 if insamp & pop1>=50000

log close


*Table 2 -- NFL Teams Matched to NIBRS Agencies
capture log close
log using $out/table2, text replace

use "$data/merge/estsample", replace
replace insamp=regularseason & dow==0 & _fillintot==0

gen dummy = 1
keep if teama!=""
sort teama state city mdy
drop if city==city[_n-1] & year==year[_n-1]
gen newpop1=pop1/1000

table teama year if insamp, c(sum dummy sum newpop1) format(%9.0f)

log close


*Table 3, Panel B -- Summary Statistics for NFL Football Games and Nielsen Television Ratings
capture log close
log using $out/table3b, text replace

use $data/misc/nfl-online, replace

gen year=year(mdy)
*limit to sample of NFL team-years in the paper
keep if teama=="car" | (teama=="den" & year>=1997) | (teama=="kan" & year>=2000) | teama=="det" | teama=="nen" | (teama=="ten" & year>=1998)
gen insamp=regularseason & gameday==1 & dow==0

tab win if insamp

gen spreadcat=1*(spread<-7 & spread!=.) + 1*(spread>=-7 & spread<-3.5) + 2*(spread>=-3.5 & spread<=3.5) + 3*(spread>3.5 & spread<=7) + 3*(spread>7 & spread!=.)

gen byte upsetloss=(gameday & loss & spreadcat==1)
gen byte closeloss=(gameday & loss & spreadcat==2)
gen byte upsetwin=(gameday & win & spreadcat==3)
gen byte predwin=spreadcat==1
gen byte predclose=spreadcat==2
gen byte predloss=spreadcat==3

gen halfspread=-halfdiff

gen halfpredwin=halfspread<-3
gen halfpredclose=halfspread>=-3 & halfspread<=3
gen halfpredloss=halfspread>3 & halfspread!=.
gen halfupsetloss=halfpredwin & loss
gen halfcloseloss=halfpredclose & loss
gen halfupsetwin=halfpredloss & win

tab predwin if insamp
tab predclose if insamp
tab predloss if insamp
tab win if predwin & insamp
tab win if predclose & insamp
tab win if predloss & insamp

tab halfpredwin if insamp
tab halfpredclose if insamp
tab halfpredloss if insamp
tab win if halfpredwin & insamp
tab win if halfpredclose & insamp
tab win if halfpredloss & insamp

tab easterntime if insamp

gen orcombo=(riv | s4t4p80) & !lowplayoff

tab lowplayoff if insamp==1
tab s4t4p80 if insamp==1
tab riv if insamp==1
tab orcombo if insamp==1

log close

*/

*Table 4 -- Unexpected Emotional Shocks from Football Games and Male-on-Female Intimate Partner Violence Occurring at Home
*Note: Cannot estimate the last two specifications without Nielsen Media TV viewership data, which is proprietary

capture log close
log using "$out/table4", text replace

use "$data/merge/estsample", replace
replace insamp=regularseason & dow==0 & AnyCrimeDate==1
xtpoisson ipmfhometot $basevars if insamp, fe i(orinum)
test upsetlossbase=-upsetwinbase
replace insamp=e(sample)
poisson ipmfhometot $basevars oo* if insamp, difficult iterate(25) cluster(teamseason)
test upsetlossbase=-upsetwinbase

replace insamp=regularseason & dow==0 & AnyCrimeDate==1
xtpoisson ipmfhometot $basevars ww* yy* $smallhh if insamp, fe i(orinum)
test upsetlossbase=-upsetwinbase
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh oo* if insamp, difficult iterate(25) cluster(teamseason)
test upsetlossbase=-upsetwinbase

*baseline
replace insamp=regularseason & dow==0 & AnyCrimeDate==1
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
test upsetlossbase=-upsetwinbase
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult iterate(25) cluster(teamseason)
test upsetlossbase=-upsetwinbase

/*
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot $basevars rtgowngame ww* yy* $smallhh $weather if insamp, fe i(orinum)
test upsetlossbase=-upsetwinbase
replace insamp=e(sample)
poisson ipmfhometot $basevars rtgowngame ww* yy* $smallhh $weather oo* if insamp, difficult iterate(25) cluster(teamseason)
test upsetlossbase=-upsetwinbase

*Limit sample to data with NMR data available
replace insamp=e(sample)

xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
test upsetlossbase=-upsetwinbase
poisson ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult iterate(25) cluster(teamseason)
test upsetlossbase=-upsetwinbase
*/

log close


*Table 5 -- Timing of Shocks and Violence
*Note: Cannot estimate these regressions as specified below (i.e., including the variables "rtg1315owngame" and "rtg1618owngame") without Nielsen Media TV viewership data, which is proprietary. 
/*
* However, the regressions can be run by excluding the TV viewership variables.

*capture log close
*log using $out/table5, text replace

*use $data/merge/estsample, replace
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhome1214 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhome1214 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)

replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhome1517 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhome1517 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)

replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhome1820 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhome1820 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)

replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhome2123 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhome2123 upsetloss1 closeloss1 upsetwin1 predwin1 predclose1 predloss1 upsetloss4 closeloss4 upsetwin4 predwin4 predclose4 predloss4 rtg1315owngame rtg1618owngame ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
*log close
*/

*Table 6 -- Shocks from Emotionally Salient Games
/*
capture log close
log using $out/table6, text replace

use $data/merge/estsample, replace
replace insamp=regularseason & dow==0 & _fillintot==0

global cat "lowplayoff riv s4t4p80 orcombo"

foreach rhs of varlist $cat {
  qui replace upsetlossbase=upsetloss
  qui replace closelossbase=closeloss
  qui replace upsetwinbase=upsetwin
  qui replace predwinbase=predwin
  qui replace predclosebase=predclose
  qui replace predlossbase=predloss

  qui replace upsetlossbase=0 if `rhs'==1
  qui replace closelossbase=0 if `rhs'==1
  qui replace upsetwinbase=0 if `rhs'==1
  qui replace predwinbase=0 if `rhs'==1
  qui replace predclosebase=0 if `rhs'==1
  qui replace predlossbase=0 if `rhs'==1

  replace insamp=regularseason & dow==0 & _fillintot==0
  xtpoisson ipmfhometot $basevars upsetloss`rhs' closeloss`rhs' upsetwin`rhs' predwin`rhs' predclose`rhs' predloss`rhs' ww* yy* $smallhh $weather if insamp, fe i(orinum)
    test upsetlossbase=upsetloss`rhs'

  replace insamp=e(sample)
  poisson ipmfhometot $basevars upsetloss`rhs' closeloss`rhs' upsetwin`rhs' predwin`rhs' predclose`rhs' predloss`rhs' ww* yy* $smallhh $weather oo* if insamp, difficult iterate(25) cluster(teamseason)
    test upsetlossbase=upsetloss`rhs'
}

log close
*/

*Table 7 -- Updating Based on the Halftime Score Differential
/*
capture log close
log using $out/table7, text replace

use $data/merge/estsample, replace

gen nogameday=1-gameday

replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot upsetlossbase closelossbase upsetwinbase halfupsetloss halfcloseloss halfupsetwin predwinbase predclosebase predlossbase ww* yy* $smallhh $weather if insamp, fe i(orinum)
poisson ipmfhometot upsetlossbase closelossbase upsetwinbase halfupsetloss halfcloseloss halfupsetwin predwinbase predclosebase predlossbase ww* yy* oo* $smallhh $weather if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
testparm half*

replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot upsetlossbase closelossbase upsetwinbase spread nogameday ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot upsetlossbase closelossbase upsetwinbase spread nogameday ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
testparm half*

replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot upsetlossbase closelossbase upsetwinbase halfupsetloss halfcloseloss halfupsetwin spread halfspread nogameday ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot upsetlossbase closelossbase upsetwinbase halfupsetloss halfcloseloss halfupsetwin spread halfspread nogameday ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
testparm half*

log close
*/

*Appendix Table 1 -- Predictive Power of the Pre-Game Point Spread versus the Halftime Point Spread
/*
capture log close
log using $out/apptable1, text replace

clear
use $data/merge/forfigures

probit win spread
dprobit win spread
probit win halfspread
dprobit win halfspread
probit win spread halfspread
dprobit win spread halfspread

probit win predwin predloss
dprobit win predwin predloss
probit win halfpredwin halfpredloss
dprobit win halfpredwin halfpredloss
probit win predwin predloss halfpredwin halfpredloss
dprobit win predwin predloss halfpredwin halfpredloss

log close
*/

*Appendix Table 2 -- Location and Victim-Offender Relationship
/*
capture log close
log using $out/apptable2, text replace

use $data/merge/estsample, replace
replace insamp=regularseason & dow==0 & _fillintot==0

global vars = "ipmfaway ipfmhome spmfhome bgmfhome"

foreach lhs in $vars {
  replace insamp=regularseason & dow==0 & _fillintot==0
  xtpoisson `lhs'tot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
  replace insamp=e(sample)
  poisson `lhs'tot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
}

*note: ipmftot must be done differently, since it has a difficult time converging
*note: the change in the order of the techniques used seems to help
use $data/merge/estsample, replace
gen ipmftot=ipmfhometot+ipmfawaytot
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmftot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
keep if insamp
drop oo*
drop teamseason
egen teamseason = group(teama season)
qui tab orinum, gen(oo)
poisson ipmftot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult technique(bhhh bfgs dfp nr) iterate(100) cluster(teamseason)

*note: the different order of techniques helps with convergence below for knhometot

use $data/merge/estsample, replace
replace insamp=regularseason & dow==0 & _fillintot==0

global vars = "fahome knhome"

foreach lhs in $vars {
  replace insamp=regularseason & dow==0 & _fillintot==0
  xtpoisson `lhs'tot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
  replace insamp=e(sample)
  poisson `lhs'tot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh nr bfgs) iterate(100) cluster(teamseason)
}

log close
*/

*Appendix Table 3 -- Additional Results
/*
capture log close
log using $out/apptable3, text replace

use $data/merge/estsample, replace

global vars = "ipmfalchome ipmfbcNhome ipmfaSMhome ipmf29mhome ipmf30phome"

foreach lhs in $vars {
  replace insamp=regularseason & dow==0 & _fillintot==0
  xtpoisson `lhs'tot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
  replace insamp=e(sample)
  poisson `lhs'tot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
}

*By city population size
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp & pop1<50000, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp & pop1<50000, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp & pop1>=50000, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp & pop1>=50000, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)

log close

*/
*Appendix Table 4 -- Robustness Checks
/*
capture log close
log using $out/apptable4, text replace

use $data/merge/estsample, replace

*negative binomial regression

replace insamp=regularseason & dow==0 & _fillintot==0
nbreg ipmfhometot $basevars ww* yy* $smallhh $weather if insamp, difficult iterate(100) cluster(teamseason)
replace insamp=e(sample)
nbreg ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult iterate(100) cluster(teamseason)

*Note: must use fullsample.dta, not estsample.dta for the treat missings as zeros regression
use $data/merge/fullsample, replace
*Treat missings as zeros
replace insamp=regularseason & dow==0
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
  keep if insamp
  drop oo*
  drop teamseason
  egen teamseason = group(teama season)
  qui tab orinum, gen(oo)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bfgs bhhh nr) iterate(100) cluster(teamseason)

use $data/merge/estsample, replace
*Only use sample with no missing data
replace insamp=regularseason & dow==0 & _fillintot==0 & daysreported==17
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather oo* if insamp, difficult technique(dfp bhhh bfgs nr) iterate(100) cluster(teamseason)

use $data/merge/estsample, replace
gen time=season-1994
gen timeten=time*(teama=="ten")
gen timeden=time*(teama=="den")
gen timecar=time*(teama=="car")
gen timenen=time*(teama=="nen")
gen timedet=time*(teama=="det")
gen timekan=time*(teama=="kan")
*date fixed effect
gen week=week(mdy)
egen weekseason=group(week season)
qui tab weekseason, gen(weekseasondd)
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather weekseasondd* if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather weekseasondd* oo* if insamp, difficult iterate(100) cluster(teamseason)

*team x season controls
replace insamp=regularseason & dow==0 & _fillintot==0
xtpoisson ipmfhometot $basevars ww* yy* $smallhh $weather timeten timeden timecar timenen timedet timekan if insamp, fe i(orinum)
replace insamp=e(sample)
poisson ipmfhometot $basevars ww* yy* $smallhh $weather timeten timeden timecar timenen timedet timekan oo* if insamp, difficult iterate(100) cluster(teamseason)

log close


*Appendix Table 5 -- See Stata output from baseline regression for Table 4
*/

*Figure 1 -- Risk of Violence Following a Loss or Win -- Illustrative graph not based on real data
/*

*Figure 2 -- Final Score Differential versus the pre-Game Point Spread

use $data/merge/forfigures

gen newdiff=scoreb-scorea
reg newdiff spread
predict hat

*Black & white graph
graph twoway (scatter newdiff spread, msize(tiny) color(black)) (line hat spread, lpattern(solid) lcolor(black)), xline(-3.75 3.75, lpattern(shortdash) lcolor(black)) ylabel(-45 -30 -15 0 15 30 45, nogrid) xlabel(-21 -14 -7 -3 0 3 7 14 21) yscale(titlegap(.5)) ytick(-45 -30 -15 0 15 30 45) legend(off) xtitle(Spread) ytitle(Realized Score Differential) plotregion(ifcolor(white)) graphregion(fcolor(white)) graphregion(ilcolor(white)) plotregion(ilcolor(white)) title("            Figure II: Final Score Differential versus the pre-Game Point Spread", color(black) size(medium) position(11) justification(left) span) subtitle(" ") note("Notes: Realized score differential is opponent's minus local team's final score.  The plotted" "regression line has an intercept of -.17 (s.e.=.21) and a slope of 1.01 (s.e.=.03).", span) text(-51 -14 "predicted win", size(small) place(n)) text(-51 0 "predicted" "close", size(small) place(n)) text(-51 14 "predicted loss", size(small) place(n)) xsize(8.5) ysize(6) graphregion(lcolor(white))

graph export $out/fig2.eps, orientation(landscape) logo(off) replace


*Figure 3 -- Probability of Victory as a Function of the Spread

use $data/merge/forfigures

gen spread2=spread^2
gen spread3=spread^3
reg win spread spread2 spread3
predict probhat

sort spread

graph twoway (line probhat spread if abs(spread)<=21, lpattern(solid) lcolor(black)), xline(-3.75 3.75, lpattern(shortdash) lcolor(black)) ylabel(1 .5 0, nogrid) xlabel(-21 -14 -7 -3 0 3 7 14 21) yscale(titlegap(.5)) ytick(1 .5 0) legend(off) xtitle(Spread) ytitle(Probability of Victory) plotregion(ifcolor(white)) graphregion(fcolor(white)) graphregion(ilcolor(white)) plotregion(ilcolor(white)) title("               Figure III: Probability of Victory as a Function of the Spread", color(black) size(medium) position(11) justification(left) span) subtitle(" ") note("Note: Curve is fit from a regression of the probability of victory for the local team on a third order" "polynomial in the spread.", span) text(.01 -14 "predicted win", size(small) place(n)) text(.01 0 "predicted" "close", size(small) place(n)) text(.01 14 "predicted loss", size(small) place(n)) xsize(8.5) ysize(6) graphregion(lcolor(white))

graph export $out/fig3.eps, orientation(landscape) logo(off) replace


*Figure 4 -- Television Audience for Local Games and the Spread
*Note: This figure requires Nielsen Media TV viewership data, which is proprietary


*Figure 5 -- Differential Increase in Violence for a Loss versus a Win, as a Function of the Spread, for Highly Salient Games
use $data/merge/estsample, replace

replace insamp=regularseason & dow==0 & _fillintot==0
gen spread2=spread^2
gen spread3=spread^3
gen spreadloss=spread*loss
gen spreadloss2=spread2*loss
gen spreadloss3=spread3*loss

xtpoisson ipmfhometot spreadloss spreadloss2 loss spread spread2 spreadmiss ww* yy* $smallhh $weather if insamp & orcombo, fe i(orinum)
gen fig5samp=e(sample)
gen hat2=_b[loss] + (_b[spreadloss]*spreadloss) + (_b[spreadloss2]*spreadloss2)

*use delta method to get pointwise se's
matrix V = e(V)
matrix a = V[1..3,1..3]
svmat a
global var1=a1[1]
global var2=a2[2]
global var3=a3[3]
global cov12=a1[2]
global cov13=a1[3]
global cov23=a2[3]
gen varhat2=(spreadloss^2)*$var1 + (spreadloss2^2)*$var2 + (loss^2)*$var3 + (2*spreadloss*spreadloss2*$cov12) + (2*spreadloss*loss*$cov13)  + (2*spreadloss2*loss*$cov23)
gen sehat2=sqrt(varhat2)
gen upper2=hat2+(1.96*sehat2)
gen lower2=hat2-(1.96*sehat2)

sort spreadloss

graph twoway (line hat2 upper2 lower2 spreadloss, lpattern(solid dash dash) lcolor(black black black)) if fig5samp & loss & spread>=-12.5 & spread<=14, xline(-3.75 3.75, lpattern(shortdash) lcolor(black)) yline(0, lcolor(black)) ylabel(-.20 -.10 0 .10 .20 .30 .40 .50, nogrid) xlabel(-12 -7 -3 3 7 12) ytick(-.20 -.10 0 .10 .20 .30 .40 .50) legend(off) xtitle(Spread) ytitle("Increase in IPV (log scale)") yscale(titlegap(.5)) plotregion(ifcolor(white)) graphregion(fcolor(white)) graphregion(ilcolor(white)) plotregion(ilcolor(white)) title("     Figure V: Differential Increase in Violence for a Loss versus a Win, as a" "                      Function of the Spread, For Highly Salient Games", color(black) size(medium) position(11) justification(left) span) subtitle(" ") note("Notes: Dashed lines are pointwise 95% confidence intervals.  Highly salient games include" "games in which the local team is still in playoff contention and also is playing against a traditional" "rival or has an unusually large number of sacks, turnovers, or penalties (see Table 6).", span) text(-.18 -7.75 "predicted win", size(small) place(c)) text(-.18 0 "predicted close", size(small) place(c)) text(-.18 8.5 "predicted loss", size(small) place(c)) xsize(8.5) ysize(6) graphregion(lcolor(white))

graph export $out/fig5.eps, orientation(landscape) logo(off) replace

*/