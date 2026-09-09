* Packages: ppmlhdfe, ftools, reghdfe, estout, listtab
* Uses:	   From $rawdata: "estsample", "estsample - CD exec" 
*		   From $proc:    "sample - CD approach", "sample - windows"
* Creates: In $results: "Table3-Replication.tex, "Table4-Geography.tex", "Fig3-InclusionNearby.pdf", "Fig4-InclusionNearest.pdf", "Fig5-SundayVsAlldays.pdf"
*						"Fig6-WeekdayVsWeekend.pdf", "$results\AppendixTable.tex"
* Note: ppmlhdfe requires ftools and reghdfe. (Also Table 7 needs to be fixed, post-processing...)

clear
global basevars = "upsetloss closeloss upsetwin predwin predclose predloss"
global holidays = "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather  = "hot hiheatindx cold windy anyrain anysnow"

global basevars_NB = "upsetloss_NB closeloss_NB upsetwin_NB predwin_NB predclose_NB predloss_NB"
global basevars_NR = "upsetloss_NR closeloss_NR upsetwin_NR predwin_NR predclose_NR predloss_NR"
global basevars_SD = "upsetloss_SD closeloss_SD upsetwin_SD predwin_SD predclose_SD predloss_SD"

* ── Table 3: CD Replication ──────────────────────────────
**** Start with CD Sample:
if "$haveCDfiles" == "" global haveCDfiles 0
if $haveCDfiles == 0 {
	disp "Note: Script 13 will not replicate columns 1 and 5 of Table 3, as the CD dataset is needed. See readme file for instructions on how to obtain it."
}
else {
	use "$rawdata\estsample", clear
	eststo cd:    ppmlhdfe ipmfhometot $basevars i.season i.cumweek $holidays $weather, absorb(ori) cluster(teamseason)
	estadd scalar n_ori =  e(df_a_initial)
	eststo cdxSC: ppmlhdfe ipmfhometot $basevars i.season i.cumweek $holidays $weather if statefips!=45, absorb(ori) cluster(teamseason)
	estadd scalar n_ori =  e(df_a_initial)
	local m1 "cd"
    local m5 "cdxSC"
    local t1 `""CD data""'
    local t5 `""CD ex-SC""'
}

*** Results from CD executable
use "$rawdata\estsample - CDexec", clear
eststo CDexec: ppmlhdfe ipmfhometot $basevars i.season i.cumweek $holidays $weather, absorb(ori) cluster(teamseason)
estadd scalar n_ori =  e(df_a_initial)

*** CD Replication:
use "$proc\sample - CD approach", clear
* Need this for the table to work:
foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
label var upsetloss "upset loss"
label var closeloss "close loss"
label var upsetwin  "upset win"
label var predwin   "predicted win"
label var predclose "predicted close"
label var predloss  "predicted loss"

eststo ExtCD:    ppmlhdfe ipmfhometot  $basevars i.season i.Sunday $holidays $weather if CDsample==1     , absorb(ori) cluster(NearbyTeamSeason)
estadd scalar n_ori = e(df_a_initial)
eststo ExtClean: ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather if cleanCDsample==1, absorb(ori) cluster(NearbyTeamSeason)
estadd scalar n_ori = e(df_a_initial)
eststo ExtClnSC: ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather if cleanCDsample==1 & state!="SC", absorb(ori) cluster(NearbyTeamSeason)
estadd scalar n_ori =  e(df_a_initial)

esttab `m1' CDexec ExtCD ExtClean `m5' ExtClnSC using "$results\Table3-Replication.tex", replace ///
	mtitles(`t1' "CD exec" "Reconstructed" "Clean" `t5' "Clean ex-SC") ///
	keep($basevars) ///
	stats(N n_ori, label("Observations" "Number of Agencies" ) fmt(%12.0fc %12.0g)) ///
	b(3) se(3)  ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	booktabs label
	
egen team_year_tag = tag(NearbyTeam season) if season <= 2006
bys state: egen YearsPre2006 = total(team_year_tag)
drop team_year_tag

* ── Table 4: Different Hometeam Matching Geography ──────────────────────────────
use "$proc\sample - CD approach", clear
gen upsetdist_NB  = upsetloss_NB*dist_Nearby/100
gen upsetdist_NR  = upsetloss_NR*dist_Nearest/100
gen upsetdist_SD  = upsetloss_SD*drivedist_Shortest/100

global otherbase = "closeloss upsetwin predwin predclose predloss"

foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
ren upsetdist_NB upsetXdistance
label var upsetloss "upset loss"
label var closeloss "close loss"
label var upsetwin  "upset win"
label var predwin   "predicted win"
label var predclose "predicted close"
label var predloss  "predicted loss"
label var upsetXdistance "upset loss $\times$ distance"

eststo Nearby: ppmlhdfe ipmfcleantot upsetloss $otherbase i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
estadd scalar n_ori = e(df_a_initial)

eststo Nearby_Interact: ppmlhdfe ipmfcleantot upsetloss upsetXdistance $otherbase i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
estadd scalar n_ori = e(df_a_initial)

ren upsetXdistance upsetdist_NB 
foreach vr in $basevars $weather {
	ren `vr' `vr'_NB
	ren `vr'_NR `vr'
}
ren upsetdist_NR  upsetXdistance
label var upsetloss "upset loss"
label var closeloss "close loss"
label var upsetwin  "upset win"
label var predwin   "predicted win"
label var predclose "predicted close"
label var predloss  "predicted loss"
label var upsetXdistance "upset loss $\times$ distance"

eststo Nearest: ppmlhdfe ipmfcleantot upsetloss $otherbase i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(NearestTeamSeason)
estadd scalar n_ori = e(df_a_initial)

eststo Nearest_Interact: ppmlhdfe ipmfcleantot upsetloss upsetXdistance $otherbase i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(NearestTeamSeason)
estadd scalar n_ori = e(df_a_initial)

ren upsetXdistance upsetdist_NR
foreach vr in $basevars $weather {
	ren `vr' `vr'_NR
	ren `vr'_SD `vr'
}
ren upsetdist_SD upsetXdistance
label var upsetloss "upset loss"
label var closeloss "close loss"
label var upsetwin  "upset win"
label var predwin   "predicted win"
label var predclose "predicted close"
label var predloss  "predicted loss"
label var upsetXdistance "upset loss $\times$ distance"

eststo Shortest: ppmlhdfe ipmfcleantot upsetloss $otherbase i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(ShortestTeamSeason)
estadd scalar n_ori = e(df_a_initial)

eststo Shortest_Interact: ppmlhdfe ipmfcleantot upsetloss upsetXdistance $otherbase i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(ShortestTeamSeason)
estadd scalar n_ori = e(df_a_initial)

ren upsetXdistance upsetdist_SD
foreach vr in $basevars $weather{
	ren `vr' `vr'_SD
}

esttab Nearby Nearby_Interact Nearest Nearest_Interact Shortest Shortest_Interact using "$results\Table4-Geography.tex", replace ///
	mgroups("Nearby Team" "Nearest Team" "Shortest Driving Distance", ///
	pattern(1 0 1 0 1 0) span prefix(\multicolumn{@span}{c}{) suffix(})) ///
	nomtitles ///
	keep(upsetloss upsetXdistance $otherbase) ///
	order(upsetloss upsetXdistance $otherbase) ///
	   varlabels(upsetloss "\addlinespace upset loss" upsetXdistance "\addlinespace  upset loss \$\times\$ distance" closeloss "\addlinespace  close loss" upsetwin "\addlinespace  upset win" predwin "\addlinespace  predicted win" predclose  	"\addlinespace predicted close" predloss "\addlinespace predicted loss") ///
	stats(N n_ori, labels("Observations" "Number of Agencies" ) fmt(%12.0fc %12.0g)) ///
	b(3) se(3)  ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	booktabs label

* ── Figures 3 and 4: Robustness to Inclusion Criteria ──────────────────────────────
use "$proc/sample - CD approach", clear
matrix define UPSETLOSS = J(17,1,.)
matrix define STDERR    = J(17,1,.)
matrix define NOBS      = J(17,1,.)

matrix define UPSETSHORT  = J(17,1,.)
matrix define STDERRSHORT = J(17,1,.)
matrix define NOBSSHORT   = J(17,1,.)

gen upsetdist_NB = upsetloss_NB*dist_Nearby/100
gen upsetdist_SD = upsetloss_SD*drivedist_Shortest/100

global weather_SD "hot_SD hiheatindx_SD cold_SD windy_SD anyrain_SD anysnow_SD"
global weather_NB "hot_NB hiheatindx_NB cold_NB windy_NB anyrain_NB anysnow_NB"

forvalues j = 1(1)17 {
	ppmlhdfe ipmfcleantot $basevars_NB upsetdist_NB i.season i.Sunday $holidays $weather_NB if nSundays_ClnKH>=`j' & nClnKH_day>0, absorb(ori) cluster(NearbyTeamSeason)
	matrix define coef = e(b)
	matrix define V    = e(V)
	matrix define UPSETLOSS[`j',1] = coef[1,1]
	matrix define STDERR[`j',1] = 1.96*(V[1,1])^(0.5) 
	matrix define NOBS[`j',1] = e(N)
	
	ppmlhdfe ipmfcleantot $basevars_SD upsetdist_SD i.season i.Sunday $holidays $weather_SD if nSundays_ClnKH>=`j' & nClnKH_day>0, absorb(ori) cluster(ShortestTeamSeason)
	matrix define coef = e(b)
	matrix define V    = e(V)
	matrix define UPSETSHORT[`j',1] = coef[1,1]
	matrix define STDERRSHORT[`j',1] = 1.96*(V[1,1])^(0.5) 
	matrix define NOBSSHORT[`j',1] = e(N)
}

svmat UPSETLOSS, names(coef)
svmat STDERR,    names(se)
svmat NOBS,      names(nobs)
svmat UPSETSHORT, names(coefshort)
svmat STDERRSHORT, names(seshort)
svmat NOBSSHORT, names(nobsshort)
keep coef1 se1 nobs1 coefshort1 seshort1 nobsshort1
gen j = _n if coef1 != .

gen upper = coef1 + se1
gen lower = coef1 - se1
gen uppershort = coefshort1 + seshort1
gen lowershort = coefshort1 - seshort1

gen nobs_thousands = nobs1 / 1000
gen nobs_thoushort = nobsshort1/1000

twoway ///
    (rcap lower upper j, lcolor(navy)) ///
    (connected coef1 j, mcolor(navy) lcolor(navy) msymbol(circle)) ///
    , xlabel(1(1)17) ///
      yscale(range(0 .)) ///
      xtitle("") ///
      ytitle("Coefficient on Upset Loss") ///
      legend(off) ///
	  name(coefplot, replace)
	  
twoway ///
    (bar nobs_thousands j, barwidth(0.6) color(maroon)) ///
    , xlabel(1(1)17) ///
      yscale(range(0 .)) ///
	  ylabel(100(100)600, angle(horizontal) labsize(small)) ///
      xtitle("Minimum Sundays Threshold") ///
      ytitle("Sample Size (thousands)") ///
      legend(off) ///
      name(nobs, replace)
graph combine coefplot nobs, cols(1)
graph export "$results\Fig3-InclusionNearby.pdf", as(pdf) replace

twoway ///
    (rcap lowershort uppershort j, lcolor(navy)) ///
    (connected coefshort1 j, mcolor(navy) lcolor(navy) msymbol(circle)) ///
    , xlabel(1(1)17) ///
      yscale(range(0 .)) ///
      xtitle("") ///
      ytitle("Coefficient on Upset Loss") ///
      legend(off) ///
	  name(coefplotshort, replace)
	  
twoway ///
    (bar nobs_thoushort j, barwidth(0.6) color(maroon)) ///
    , xlabel(1(1)17) ///
      yscale(range(0 .)) ///
	  ylabel(100(100)900, angle(horizontal) labsize(small)) ///
      xtitle("Minimum Sundays Threshold") ///
      ytitle("Sample Size (thousands)") ///
      legend(off) ///
      name(nobsshort, replace)
graph combine coefplotshort nobsshort, cols(1)
graph export "$results\Fig4-InclusionNearest.pdf", as(pdf) replace

* ── Tables 5 and 6 and Figures 5 and 6: Time Windows ──────────────────────────────
use "$proc\sample - windows", clear
global newbase = "upsetloss closeloss upsetwin predwin predloss"

matrix define UPSETLOSS = J(12,1,.)
matrix define STDERR    = J(12,1,.)
matrix define NOBS      = J(12,1,.)

matrix define UPSET_SUN  = J(12,1,.)
matrix define STD_SUN = J(12,1,.)

matrix define UPSET_WKND  = J(12,1,.)
matrix define STD_WKND = J(12,1,.)

forvalues j = 2(1)12 {
	eststo time`j': ppmlhdfe nIPVclean`j' $newbase upsetXdistance i.season i.dow i.starthour i.week $holidays $weather if ShareReported >= .7 & maxGap <=14, absorb(ori) cluster(TeamSeason)
	estadd scalar n_ori = e(df_a_initial)
	matrix define coef = e(b)
	matrix define V    = e(V)
	matrix define UPSETLOSS[`j',1] = coef[1,1]
	matrix define STDERR[`j',1] = 1.96*(V[1,1])^(0.5) 
	
	eststo suntime`j': ppmlhdfe nIPVclean`j' $newbase upsetXdistance i.season i.dow i.starthour i.week $holidays $weather if ShareReported >= .7 & maxGap <=14 & dow==0, absorb(ori) cluster(TeamSeason)
	estadd scalar n_ori_Sun = e(df_a_initial)
	matrix define coef_Sun = e(b)
	matrix define V_Sun    = e(V)
	matrix define UPSET_SUN[`j',1] = coef_Sun[1,1]
	matrix define STD_SUN[`j',1] = 1.96*(V_Sun[1,1])^(0.5) 	
}

esttab time2 time4 time6 time8 time10 time12 using "$results\Table6-TimeWindows.tex", replace ///
	keep($newbase upsetXdistance *.dow) ///
	order(upsetloss upsetXdistance $otherbase) ///
	stats(N n_ori, labels("Observations" "Number of Agencies" ) fmt(%12.0fc %12.0g)) ///
	b(3) se(3)  ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	booktabs
	
esttab suntime2 suntime4 suntime6 suntime8 suntime10 suntime12 using "$results\Table5-SundayWindows.tex", replace ///
	keep($newbase upsetXdistance) ///
	order(upsetloss upsetXdistance $otherbase) ///
	stats(N n_ori_Sun, labels("Observations" "Number of Agencies" ) fmt(%12.0fc %12.0g)) ///
	b(3) se(3)  ///
	star(* 0.10 ** 0.05 *** 0.01) ///
	booktabs

svmat UPSETLOSS, names(upset_coef)
svmat UPSET_SUN, names(upset_sun)
svmat STDERR,    names(se)
svmat STD_SUN,   names(se_sun)
keep upset_coef1 se1 upset_sun1 se_sun1
gen j = _n if upset_coef1 != .

gen upper = upset_coef1 + se1
gen lower = upset_coef1 - se1

gen upper_sun = upset_sun1 + se_sun1
gen lower_sun = upset_sun1 - se_sun1

twoway ///
    (rcap lower upper j, lcolor(navy)) ///
    (connected upset_coef1 j, mcolor(navy) lcolor(navy) msymbol(circle)) ///
    (rcap lower_sun upper_sun j, lcolor(maroon)) ///
    (connected upset_sun1 j, mcolor(maroon) lcolor(maroon) msymbol(square)) ///
    , xlabel(1(1)12) ///
      yscale(range(0 .)) ///
      xtitle("Hours After Kickoff") ///
      ytitle("Impact of Upset Loss on IPV") ///
      legend(order(2 "All Games" 4 "Sundays") pos(6)) ///
      name(coefplot_combined, replace)
	  
graph export "$results\Fig5-SundayVsAlldays.pdf", as(pdf) replace  

*** Figure 6 - Weekday vs. Weekend
use "$proc\sample - windows", clear
gen weekend = inlist(dow,6,5,0)
matrix define UPSET_WKND  = J(12,1,.)
matrix define STD_WKND = J(12,1,.)
matrix define UPSET_WEEK  = J(12,1,.)
matrix define STD_WEEK = J(12,1,.)

forvalues j = 2(1)12 {
	eststo wkndtime`j': ppmlhdfe nIPVclean`j' $newbase upsetXdistance i.season i.dow i.starthour i.week $holidays $weather if ShareReported >= .7 & maxGap <=14 & weekend==1, absorb(ori) cluster(TeamSeason)
	estadd scalar n_ori_wknd = e(df_a_initial)
	matrix define coef_wknd = e(b)
	matrix define V_wknd    = e(V)
	matrix define UPSET_WKND[`j',1] = coef_wknd[1,1]
	matrix define STD_WKND[`j',1] = 1.96*(V_wknd[1,1])^(0.5) 
	
	eststo weektime`j': ppmlhdfe nIPVclean`j' $newbase upsetXdistance i.season i.dow i.starthour i.week $holidays $weather if ShareReported >= .7 & maxGap <=14 & weekend==0, absorb(ori) cluster(TeamSeason)
	estadd scalar n_ori_week = e(df_a_initial)
	matrix define coef_week = e(b)
	matrix define V_week    = e(V)
	matrix define UPSET_WEEK[`j',1] = coef_week[1,1]
	matrix define STD_WEEK[`j',1] = 1.96*(V_week[1,1])^(0.5) 	
}

svmat UPSET_WKND, names(upset_wknd)
svmat UPSET_WEEK, names(upset_week)
svmat STD_WKND,   names(se_wknd)
svmat STD_WEEK,   names(se_week)
keep upset_wknd1 se_wknd1 upset_week1 se_week1
gen j = _n if upset_wknd1 != .

gen upper_wknd = upset_wknd1 + se_wknd1
gen lower_wknd = upset_wknd1 - se_wknd1

gen upper_week = upset_week1 + se_week1
gen lower_week = upset_week1 - se_week1

twoway ///
    (rcap lower_wknd upper_wknd j, lcolor(navy)) ///
    (connected upset_wknd1 j, mcolor(navy) lcolor(navy) msymbol(circle)) ///
    (rcap lower_week upper_week j, lcolor(dkgreen)) ///
    (connected upset_week1 j, mcolor(dkgreen) lcolor(dkgreen) msymbol(dkgreen)) ///
    , xlabel(1(1)12) ///
      yscale(range(0 .)) ///
      xtitle("Hours After Kickoff") ///
      ytitle("Impact of Upset Loss on IPV") ///
      legend(order(2 "Weekend Games" 4 "Weekday Games") pos(6)) ///
      name(coefplot_combined, replace)
	  
graph export "$results\Fig6-WeekdayVsWeekend.pdf", as(pdf) replace  
*/

* ── Table 7: Expanded Time Windows ──────────────────────────────
use "$proc\sample - windows", clear
global newbase = "upsetloss closeloss upsetwin predwin predloss"
global weather  = "hot    hiheatindx    cold    windy    anyrain    anysnow"
global holidays = "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"

matrix define BCOEF = J(8,20,.)
matrix define PVAL  = J(8,20,.)

gen     InSample = 0 
replace InSample = 1 if ShareReported >= .7 & maxGap <=14 & dow(Date)==0

forvalues st = -4(1)3 {
	gen yIPV = 0
	forvalues l = 0(1)11 {
		disp("Window Start is `st', Hours is `l'")
		loc t = `st'+`l'
		local suffix = cond(`t' < 0, "m" + string(abs(`t')), "`t'")
		quietly replace yIPV = yIPV + nIPV`suffix'
		ppmlhdfe yIPV $newbase upsetXdistance i.season i.starthour i.week $holidays $weather if InSample==1, absorb(ori) cluster(TeamSeason)
	
		loc r = `st'+ 5
		loc c = `r' + `l' 
		matrix tbl = r(table)
		matrix BCOEF[`r',`c'] =  _b[upsetloss]
		matrix  PVAL[`r',`c'] = tbl["pvalue","upsetloss"]
	}
	drop yIPV
}

clear
svmat BCOEF
svmat PVAL

gen windowstart = .
forvalues i = 1/8 {
	replace windowstart = `i'-5 in `i'
}
tostring windowstart, replace

forvalues WinEnd = -3(1)15 {
	local k = cond(`WinEnd' < 0, "m" + string(abs(`WinEnd')), "`WinEnd'")
	gen cell`k' = ""
	forvalues i = 1/8 {
		loc WinStart = `i'-5
		if `WinStart' <= `WinEnd' {
			loc j = `WinEnd' + 4
			loc C = BCOEF`j'[`i']
			loc p = PVAL`j'[`i']
			if !missing(`C') {
				loc stars = ""
				if 		`p' < 0.01 local stars = "***"
				else if `p' < 0.05 local stars = "**"
				else if `p' < 0.10 local stars = "*"
				loc cellstr : display %5.3f `C'
				loc pstr : display %5.3f `p'
				quietly replace cell`k' = "\shortstack{`cellstr'`stars' \\ {\scriptsize (`pstr')}}" in `i'
			}
		}
	}
}
* Note: in the paper, we combined these two panels of Table 7 by hand.
listtab windowstart cellm3-cell5 using "$results\expanded_windowsA.tex", rstyle(tabular) replace ///
    head("\begin{tabular}{l*{10}{c}}" "\toprule" ///
		"& \multicolumn{9}{c}{Window End (hours after kickoff)} \\" ///
		"\cmidrule(lr){2-10}" ///
         "Window Start & -3 & -2 & -1 & 0 & 1 & 2 & 3 & 4 & 5\\" "\midrule") ///
    foot("\bottomrule" "\end{tabular}")
	
listtab windowstart cell6-cell15 using "$results\expanded_windowsB.tex", rstyle(tabular) replace ///
    head("\begin{tabular}{l*{10}{c}}" "\toprule" ///
	"& \multicolumn{9}{c}{Window End (hours after kickoff)} \\" ///
	"\cmidrule(lr){2-10}" ///
         "Window Start & 6 & 7 & 8 & 9 & 10 & 11 & 12 & 13 & 14 & 15\\" "\midrule") ///
    foot("\bottomrule" "\end{tabular}")

* ── Appendix Table: Clean Sample without each state ──────────────────────────────
local states CO KS MA MI NH SC TN VT
matrix R = J(8,8,.)

* Clean reconstructed (columns 1-4)
use "$proc\sample - CD approach", clear
eststo clear

foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}

loc i = 0
foreach st of local states {
	loc ++i
	ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather if cleanCDsample==1 & state!="`st'", absorb(ori) cluster(NearbyTeamSeason)
	matrix t = r(table)
	matrix R[`i',1] = _b[upsetloss]
    matrix R[`i',2] = t["pvalue","upsetloss"]
    matrix R[`i',3] = e(N)
    matrix R[`i',4] = e(df_a_initial)
}

* CD's data (columns 5-8)
if $haveCDfiles {
	use "$rawdata\estsample", clear
	gen     state = "SC" if statefips == 45
	replace state = "MI" if statefips == 26
	replace state = "MA" if statefips == 25
	replace state = "KS" if statefips == 20
	replace state = "CO" if statefips == 8
	replace state = "NH" if statefips == 33
	replace state = "TN" if statefips == 47
	replace state = "VT" if statefips == 50
	assert !missing(state)  

	loc i = 0
	foreach st in CO KS MA MI NH SC TN VT {
		loc ++i
		ppmlhdfe ipmfhometot $basevars i.season i.cumweek $holidays $weather if state!="`st'", absorb(ori) cluster(teamseason)
		matrix t = r(table)
		matrix R[`i',5] = _b[upsetloss]
		matrix R[`i',6] = t["pvalue","upsetloss"]
		matrix R[`i',7] = e(N)
		matrix R[`i',8] = e(df_a_initial)
	}
}

clear
svmat R
gen str3 st = ""
local i = 0
foreach s of local states {
    local ++i
    replace st = "`s'" in `i'
}

gen str40 bCln = ""
gen str40 bCD  = ""
gen str20 nCln = ""
gen str20 nCD  = ""
gen str20 aCln = ""
gen str20 aCD  = ""

local bases "1"
if $haveCDfiles local bases "1 5"
forvalues k = 1/8 {
    foreach b0 of local bases {
        local c = cond(`b0'==1, "Cln", "CD")
        local b  : display %5.3f R`b0'[`k']
        local p  = R`=`b0'+1'[`k']
        local star = ""
        if `p' < 0.10 local star = "\sym{*}"
        if `p' < 0.05 local star = "\sym{**}"
        if `p' < 0.01 local star = "\sym{***}"
        quietly replace b`c' = "`b'`star'" in `k'
        quietly replace n`c' = string(R`=`b0'+2'[`k'], "%9.0fc") in `k'
        quietly replace a`c' = string(R`=`b0'+3'[`k'], "%9.0f")  in `k'
    }
}

if $haveCDfiles {
    local cdvars   "bCD nCD aCD"
    local tabspec  "lcccccc"
    local grouphdr "& \multicolumn{3}{c}{Clean Sample} & \multicolumn{3}{c}{CD Sample} \\"
    local midrules "\cmidrule(lr){2-4} \cmidrule(lr){5-7}"
    local colhdr   "Excluded state & upset loss & N & Agencies & upset loss & N & Agencies \\"
}
else {
    local cdvars   ""
    local tabspec  "lccc"
    local grouphdr "& \multicolumn{3}{c}{Clean Sample} \\"
    local midrules "\cmidrule(lr){2-4}"
    local colhdr   "Excluded state & upset loss & N & Agencies \\"
}

listtab st bCln nCln aCln `cdvars' using "$results\AppendixTable.tex", ///
    rstyle(tabular) replace ///
    head("\providecommand{\sym}[1]{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
         "\begin{tabular}{`tabspec'}" "\toprule" ///
            "`grouphdr'" "`midrules'" "`colhdr'" "\midrule") ///
    foot("\bottomrule" "\end{tabular}")