* ── Table 8: South/Midwest versus NE/West ──────────────────────────────
use "$proc\sample - windows", clear
global otherbase = "closeloss upsetwin predwin predloss"
global holidays = "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather  = "hot hiheatindx cold windy anyrain anysnow"

* Rows 1-3 for full, local, and non-local, preferred sample and extended.
* E.g., BUPSET[1,1] is the upset loss for the full preferred sample.
matrix BUPSET = J(6,2,.)
matrix STDERR = J(6,2,.)
matrix PVAL   = J(6,2,.)
matrix NOBS   = J(6,2,.)

****** Preferred Sample *********
use "$proc\sample - windows", clear
gen local = 0
replace local =1 if team_distance <=100

gen InSample = 0 
replace InSample = 1 if ShareReported >= .7 & maxGap <=14 & dow(Date)==0

* Note: NIBRS does use "NB" as an abbreviation for Nebraska, rather than the correct postal abbreviation NE.
gen     region = "West"      if inlist(state,"WA","OR","CA")                | inlist(state,"MT","ID","WY","CO","UT","NV","AZ","NM")
replace region = "Midwest"   if inlist(state,"WI","MI","IL","IN","OH")      | inlist(state,"ND","SD","NE","KS","MN","IA","MO","NB")
replace region = "Northeast" if inlist(state,"VT","NH","ME","MA","RI","CT") | inlist(state,"PA","NY","NJ")
replace region = "South"     if inlist(state,"TX","OK","AR","LA")           | inlist(state,"MS","AL","TN","KY") | inlist(state,"FL","GA","SC","NC","VA","WV","DC","MD","DE")
assert !mi(region)

loc i = 1

* Full sample:
ppmlhdfe nIPVclean4 upsetloss $otherbase i.season i.starthour i.week $holidays $weather if InSample==1, absorb(ori) cluster(TeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',1] =  _b[upsetloss]
matrix STDERR[`i',1] = _se[upsetloss]
matrix   PVAL[`i',1] = tbl["pvalue","upsetloss"]
matrix   NOBS[`i',1] = e(N) 

* Local 
local ++i
ppmlhdfe nIPVclean4 upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1, absorb(ori) cluster(TeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',1] =  _b[upsetloss]
matrix STDERR[`i',1] = _se[upsetloss]
matrix   PVAL[`i',1] = tbl["pvalue","upsetloss"]
matrix   NOBS[`i',1] = e(N) 

* Non-local
local ++i
ppmlhdfe nIPVclean4 upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==0 & InSample==1, absorb(ori) cluster(TeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',1] =  _b[upsetloss]
matrix STDERR[`i',1] = _se[upsetloss]
matrix   PVAL[`i',1] = tbl["pvalue","upsetloss"]
matrix   NOBS[`i',1] = e(N)

* Regional Heterogeneity:
local ++i
gen SouthMid = inlist(region, "South","Midwest")
gen upsetxSM = upsetloss*SouthMid

global otherbasexSM ""
foreach vr in $otherbase {
	gen `vr'xSM = `vr'*SouthMid
	global otherbasexSM "$otherbasexSM `vr'xSM"
}

ppmlhdfe nIPVclean4 upsetloss upsetxSM $otherbase $otherbasexSM i.season i.starthour i.week $holidays $weather if local==1 & InSample==1, absorb(ori) cluster(TeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',1] = _b[upsetloss] + _b[upsetxSM]
matrix BUPSET[`i'+1,1] = _b[upsetloss]
matrix BUPSET[`i'+2,1] = _b[upsetxSM]
matrix NOBS[`i',1]   = e(N)
matrix NOBS[`i'+1,1] = e(N)
matrix NOBS[`i'+2,1] = e(N)

matrix STDERR[`i'+1,1] = _se[upsetloss]
matrix STDERR[`i'+2,1] = _se[upsetxSM]

matrix PVAL[`i'+1,1]   = tbl["pvalue","upsetloss"]
matrix PVAL[`i'+2,1]   = tbl["pvalue","upsetxSM"]

lincom upsetloss + upsetxSM
matrix STDERR[`i',1] = r(se)
matrix PVAL[`i',1]   = r(p)

****** Extended Sample *********
use "$proc\sample - CD approach", clear
global basevars = "upsetloss closeloss upsetwin predwin predclose predloss"
global weather  = "hot hiheatindx cold windy anyrain anysnow"

foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
gen local = 0
replace local =1 if dist_NearbyTeam <=100

gen     region = "West"      if inlist(state,"WA","OR","CA")                | inlist(state,"MT","ID","WY","CO","UT","NV","AZ","NM")
replace region = "Midwest"   if inlist(state,"WI","MI","IL","IN","OH")      | inlist(state,"ND","SD","NE","KS","MN","IA","MO","NB")
replace region = "Northeast" if inlist(state,"VT","NH","ME","MA","RI","CT") | inlist(state,"PA","NY","NJ")
replace region = "South"     if inlist(state,"TX","OK","AR","LA")           | inlist(state,"MS","AL","TN","KY") | inlist(state,"FL","GA","SC","NC","VA","WV","DC","MD","DE")
assert !mi(region)

loc i = 1
* Full sample:
ppmlhdfe ipmfcleantot  $basevars i.season i.Sunday $holidays $weather if EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',2] =  _b[upsetloss]
matrix STDERR[`i',2] = _se[upsetloss]
matrix   PVAL[`i',2] = tbl["pvalue","upsetloss"]
matrix   NOBS[`i',2] = e(N) 

* Local 
local ++i
ppmlhdfe ipmfcleantot  $basevars i.season i.Sunday $holidays $weather if local==1 & EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',2] =  _b[upsetloss]
matrix STDERR[`i',2] = _se[upsetloss]
matrix   PVAL[`i',2] = tbl["pvalue","upsetloss"]
matrix   NOBS[`i',2] = e(N) 

* Non-local
local ++i
ppmlhdfe ipmfcleantot  $basevars i.season i.Sunday $holidays $weather if local==0 & EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',2] =  _b[upsetloss]
matrix STDERR[`i',2] = _se[upsetloss]
matrix   PVAL[`i',2] = tbl["pvalue","upsetloss"]
matrix   NOBS[`i',2] = e(N)

* Regional Heterogeneity:
local ++i
gen SouthMid = inlist(region, "South","Midwest")
gen upsetxSM = upsetloss*SouthMid

global basexSM ""
foreach vr in $basevars {
	gen `vr'xSM = `vr'*SouthMid
	global basexSM "$basexSM `vr'xSM"
}

ppmlhdfe ipmfcleantot $basevars $basexSM i.season i.Sunday $holidays $weather if local==1 & EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
matrix tbl = r(table)
matrix BUPSET[`i',2] = _b[upsetloss] + _b[upsetlossxSM]
matrix BUPSET[`i'+1,2] = _b[upsetloss]
matrix BUPSET[`i'+2,2] = _b[upsetlossxSM]
matrix NOBS[`i',2] = e(N)
matrix NOBS[`i'+1,2] = e(N)
matrix NOBS[`i'+2,2] = e(N)

matrix STDERR[`i'+1,2] = _se[upsetloss]
matrix STDERR[`i'+2,2] = _se[upsetlossxSM]

matrix PVAL[`i'+1,2]   = tbl["pvalue","upsetloss"]
matrix PVAL[`i'+2,2]   = tbl["pvalue","upsetlossxSM"]

lincom upsetloss + upsetlossxSM
matrix STDERR[`i',2] = r(se)
matrix PVAL[`i',2]   = r(p)

clear
svmat BUPSET
svmat STDERR
svmat PVAL
svmat NOBS

gen spec = ""
replace spec = "Full Sample" in 1
replace spec = "Local"       in 2
replace spec = "Non-local"   in 3
replace spec = "South and Midwest"  in 4
replace spec = "Northeast and West" in 5
replace spec = "Difference" in 6
order spec

gen coef1 = ""
gen coef2 = ""
gen str20 nstr1 = string(NOBS1,"%9.0fc")
gen str20 nstr2 = string(NOBS2,"%9.0fc")

forvalues k = 1(1)6 {
	forvalues c = 1/2 {
		loc p = PVAL`c'[`k']
		loc stars`c' = ""
		if 		`p' < 0.01 local stars`c' = "***"
		else if `p' < 0.05 local stars`c' = "**"
		else if `p' < 0.10 local stars`c' = "*"
		loc cf : display %5.3f BUPSET`c'[`k']
		loc se : display %5.3f STDERR`c'[`k']
		quietly replace coef`c' = "\shortstack{`cf'`stars`c'' \\ {\scriptsize (`se')}}" in `k'
	}
}

listtab spec coef1 nstr1 coef2 nstr2 using "$results\Table8-SouthMW.tex", rstyle(tabular) replace ///
    head("\renewcommand{\arraystretch}{1.4} \begin{tabular}{l*{4}{c}}" "\toprule" ///
		"& \multicolumn{2}{c}{Preferred Sample} & \multicolumn{2}{c}{Extended Sample} \\" ///
		"& upset loss & N & upset loss & N \\" ///
		"\cmidrule(lr){2-3} \cmidrule(lr){4-5}") ///
    foot("\bottomrule" "\end{tabular}")	

* ── Table 9: Individual Regions ──────────────────────────────
use "$proc\sample - windows", clear
global otherbase = "closeloss upsetwin predwin predloss"
global holidays = "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather  = "hot hiheatindx cold windy anyrain anysnow"

****** Regional Heterogeneity using Preferred Sample *********
use "$proc\sample - windows", clear
gen local = 0
replace local =1 if team_distance <=100

gen InSample = 0 
replace InSample = 1 if ShareReported >= .7 & maxGap <=14 & dow(Date)==0

gen     region = "West"      if inlist(state,"WA","OR","CA")                | inlist(state,"MT","ID","WY","CO","UT","NV","AZ","NM")
replace region = "Midwest"   if inlist(state,"WI","MI","IL","IN","OH")      | inlist(state,"ND","SD","NE","KS","MN","IA","MO","NB")
replace region = "Northeast" if inlist(state,"VT","NH","ME","MA","RI","CT") | inlist(state,"PA","NY","NJ")
replace region = "South"     if inlist(state,"TX","OK","AR","LA")           | inlist(state,"MS","AL","TN","KY") | inlist(state,"FL","GA","SC","NC","VA","WV","DC","MD","DE")
assert !mi(region)

*** Preferred Sample ***
matrix results_pref = J(9,3,.)
loc i = 1

* Local,
ppmlhdfe nIPVclean4 upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1, absorb(ori) cluster(TeamSeason)
matrix tbl = r(table)
matrix results_pref[`i',1] = _b[upsetloss]
matrix results_pref[`i',2] = tbl["pvalue","upsetloss"]
matrix results_pref[`i',3] = _se[upsetloss]

* Local,  Regional level
foreach r in South Northeast Midwest West {
	local ++i
	ppmlhdfe nIPVclean4 upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1 & region=="`r'", absorb(ori) cluster(TeamSeason)
	matrix tbl = r(table)
	matrix results_pref[`i',1] = _b[upsetloss]
	matrix results_pref[`i',2] = tbl["pvalue","upsetloss"]
	matrix results_pref[`i',3] = _se[upsetloss]
}

* Local, Drop Regions
foreach r in South Northeast Midwest West {
	local ++i
	ppmlhdfe nIPVclean4 upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1 & region!="`r'", absorb(ori) cluster(TeamSeason)
	matrix tbl = r(table)
	matrix results_pref[`i',1] = _b[upsetloss]
	matrix results_pref[`i',2] = tbl["pvalue","upsetloss"]
	matrix results_pref[`i',3] = _se[upsetloss]
}

*** Preferred Sample with CD dependent variable***
matrix results_CD = J(9,3,.)
loc i = 1

* Local:
ppmlhdfe nIPVcleanCD upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1, absorb(ori) cluster(TeamSeason)
matrix tbl = r(table)
matrix results_CD[`i',1] = _b[upsetloss]
matrix results_CD[`i',2] = tbl["pvalue","upsetloss"]
matrix results_CD[`i',3] = _se[upsetloss]

* Local,  Regional level
foreach r in South Northeast Midwest West {
	local ++i
	ppmlhdfe nIPVcleanCD upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1 & region=="`r'", absorb(ori) cluster(TeamSeason)
	matrix tbl = r(table)
	matrix results_CD[`i',1] = _b[upsetloss]
	matrix results_CD[`i',2] = tbl["pvalue","upsetloss"]
	matrix results_CD[`i',3] = _se[upsetloss]
}

* Local, Drop Regions
foreach r in South Northeast Midwest West {
	local ++i
	ppmlhdfe nIPVcleanCD upsetloss $otherbase i.season i.starthour i.week $holidays $weather if local==1 & InSample==1 & region!="`r'", absorb(ori) cluster(TeamSeason)
	matrix tbl = r(table)
	matrix results_CD[`i',1] = _b[upsetloss]
	matrix results_CD[`i',2] = tbl["pvalue","upsetloss"]
	matrix results_CD[`i',3] = _se[upsetloss]
}

****** Extended Sample *********
use "$proc\sample - CD approach", clear
global basevars = "upsetloss closeloss upsetwin predwin predclose predloss"
global weather  = "hot hiheatindx cold windy anyrain anysnow"

foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
gen local = 0
replace local =1 if dist_NearbyTeam <=100

gen     region = "West"      if inlist(state,"WA","OR","CA")                | inlist(state,"MT","ID","WY","CO","UT","NV","AZ","NM")
replace region = "Midwest"   if inlist(state,"WI","MI","IL","IN","OH")      | inlist(state,"ND","SD","NE","KS","MN","IA","MO","NB")
replace region = "Northeast" if inlist(state,"VT","NH","ME","MA","RI","CT") | inlist(state,"PA","NY","NJ")
replace region = "South"     if inlist(state,"TX","OK","AR","LA")           | inlist(state,"MS","AL","TN","KY") | inlist(state,"FL","GA","SC","NC","VA","WV","DC","MD","DE")
assert !mi(region)

matrix results_ext = J(9,3,.)
loc j = 1

* Local:
ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather if local ==1 & EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)
matrix tbl = r(table)
matrix results_ext[`j',1] = _b[upsetloss]
matrix results_ext[`j',2] = tbl["pvalue","upsetloss"]
matrix results_ext[`j',3] = _se[upsetloss]

* Local,  Regional level
foreach r in South Northeast Midwest West {
	local ++j
	ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather if local==1 & EXTsample==1 & region=="`r'", absorb(ori) cluster(NearbyTeamSeason)
	matrix tbl = r(table)
	matrix results_ext[`j',1] = _b[upsetloss]
	matrix results_ext[`j',2] = tbl["pvalue","upsetloss"]
	matrix results_ext[`j',3] = _se[upsetloss]
}

* Local, Drop Regions
foreach r in South Northeast Midwest West {
	local ++j
	ppmlhdfe  ipmfcleantot $basevars i.season i.Sunday $holidays $weather if local==1 & EXTsample==1 & region!="`r'", absorb(ori) cluster(NearbyTeamSeason)
	matrix tbl = r(table)
	matrix results_ext[`j',1] = _b[upsetloss]
	matrix results_ext[`j',2] = tbl["pvalue","upsetloss"]
	matrix results_ext[`j',3] = _se[upsetloss]
}

clear
svmat results_pref
svmat results_CD
svmat results_ext

ren (results_pref1 results_pref2 results_pref3) (b_pref p_pref se_pref)
ren (results_CD1 results_CD2 results_CD3) (b_CD p_CD se_CD)
ren (results_ext1 results_ext2 results_ext3) (b_ext p_ext se_ext)

gen spec = ""
replace spec = "Local" in 1
replace spec = "South" in 2
replace spec = "Northeast" in 3
replace spec = "Midwest" in 4
replace spec = "West" in 5
replace spec = "Drop South" in 6
replace spec = "Drop Northeast" in 7
replace spec = "Drop Midwest" in 8
replace spec = "Drop West" in 9

foreach sample in pref CD ext {
	gen cell`sample' = ""
	forvalues i = 1/9 {
		loc p = p_`sample'[`i']
		loc stars = ""
		if 		`p' < 0.01 local stars = "***"
		else if `p' < 0.05 local stars = "**"
		else if `p' < 0.10 local stars = "*"
		
		loc cellstr : display %5.3f b_`sample'[`i']
		loc sestr   : display %5.3f se_`sample'[`i']
		quietly replace cell`sample' = "\shortstack{`cellstr'`stars' \\ {\scriptsize (`sestr')}}" in `i'
	}
}

listtab spec cellpref cellext cellCD using "$results\Table9-Regions.tex", rstyle(tabular) replace ///
    head("\renewcommand{\arraystretch}{1.4} \begin{tabular}{l*{3}{c}}" "\toprule" ///
		"& Preferred Sample & Extended Sample & 12pm-12am Window \\"  "\midrule") ///
    foot("\bottomrule" "\end{tabular}")
	