* Project: Card and Dahl Replication 
* Name: 	   Darius Martin and Jason Query
* Packages:    ppmlhdfe, ftools, reghdfe, listtab
* Uses:		   "$rawdata\estsample", "$proc\sample - CD approach", "$proc\sample - windows"
* Creates: 	   In $results: Table1.dta, Table2.dta
* Description: Creates summary stats tables. To produce column 1 of Table 1, reproducing summary stats from Card and Dahl (2011), the Card and Dahl dataset estsample.dta must be present in the $rawdata directory, with the corresponding $haveCDfiles switch set to one. 
*	This code produces the numbers in Table 1 in two separate tex files: means and totals. The paper's version combines them and adds formatting by hand.

if "$haveCDfiles" == "" global haveCDfiles 0
if $haveCDfiles == 0 {
	disp "Note: Script 12 will not replicate column 1 of Table 1, as the CD dataset is needed. See readme file for instructions on how to obtain it."
}

global basevars = "upsetloss closeloss upsetwin predwin predclose predloss"
global holidays = "christeve christday newyeareve newyearday halloween thankswkd laborwkd columwkd vetwkd"
global weather  = "hot hiheatindx cold windy anyrain anysnow"

global basevars_NB = "upsetloss_NB closeloss_NB upsetwin_NB predwin_NB predclose_NB predloss_NB"
global basevars_NR = "upsetloss_NR closeloss_NR upsetwin_NR predwin_NR predclose_NR predloss_NR"
global basevars_SD = "upsetloss_SD closeloss_SD upsetwin_SD predwin_SD predclose_SD predloss_SD"

* --- Table 1: Summary Stats ---------------------------------------------------------------
* Summary stats for CD sample (Tbl 4 col 1), CD reconstructed (Table 4 col 3), CD clean (Table 4 col 4), CD extended (Table 5 col 1), Preferred specification (Table 6 col 2)
capture program drop append_sumstats
program define append_sumstats
    args team_var ipv_var dataset_label outfile

    keep if e(sample)==1
    ren (`team_var' `ipv_var') (team IPV)
    gen obs = 1
	
	foreach vr in ori state season team {
		bys `vr': gen q = _n==1
		replace q = sum(q)
		gen n_`vr' = q[_N]
		drop q
	}
	ren (n_ori n_state n_season n_team) (n_agencies n_states n_seasons n_teams)
	
    collapse (mean) IPV $basevars (sum) IPVcases = IPV ///
             (mean) n_agencies n_states n_seasons n_teams (sum) obs
    gen dataset = "`dataset_label'"
    append using "`outfile'"
    save "`outfile'", replace
end

clear
tempfile sumstats
save `sumstats', emptyok replace

*** CD sample:
if $haveCDfiles {
	use "$rawdata\estsample", clear
	ppmlhdfe ipmfhometot $basevars i.season i.cumweek $holidays $weather, absorb(ori) cluster(teamseason)
	append_sumstats teama ipmfhometot "CD" "`sumstats'"
}

*** CD reconstructed 
use "$proc\sample - CD approach", clear
foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
ppmlhdfe ipmfhometot  $basevars i.season i.Sunday $holidays $weather if CDsample==1, absorb(ori) cluster(NearbyTeamSeason)
append_sumstats NearbyTeam ipmfhometot "Reconstructed" "`sumstats'"

*** CD clean:
use "$proc\sample - CD approach", clear
foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather if cleanCDsample==1, absorb(ori) cluster(NearbyTeamSeason)
append_sumstats NearbyTeam ipmfcleantot "Clean" "`sumstats'"
		
*** CD extended
use "$proc\sample - CD approach", clear
foreach vr in $basevars $weather {
	ren `vr'_NB `vr'
}
ppmlhdfe ipmfcleantot $basevars i.season i.Sunday $holidays $weather  if EXTsample==1, absorb(ori) cluster(NearbyTeamSeason)	
append_sumstats NearbyTeam ipmfcleantot "Extended" "`sumstats'"

*** Preferred:
use "$proc\sample - windows", clear
ppmlhdfe nIPVclean4 $basevars upsetXdistance i.season i.dow i.starthour i.week $holidays $weather if ShareReported >= .7 & maxGap <=14 & dow==0, absorb(ori) cluster(TeamSeason)
append_sumstats hometeam nIPVclean4 "Preferred" "`sumstats'"

* Produce Table 1:
use "`sumstats'", clear
gen order = 1 if dataset=="CD"
replace order = 2 if dataset=="Reconstructed"
replace order = 3 if dataset=="Clean"
replace order = 4 if dataset=="Extended"
replace order = 5 if dataset=="Preferred"
sort order

mkmat IPV $basevars, matrix(Means) rownames(dataset)
matrix Means = Means'
mkmat IPVcases n_agencies n_states n_seasons n_teams obs, matrix(Totals) rownames(dataset)
matrix Totals = Totals'
esttab matrix(Means, fmt(3)) using "$results\Table1-means.tex",  replace booktabs collabels(none)
esttab matrix(Totals)		 using "$results\Table1-totals.tex", replace booktabs collabels(none)

* --- Table 2: Team Summary Stats ---------------------------------------------------------------
use "$proc\sample - windows", clear
ppmlhdfe nIPVclean4 $basevars upsetXdistance i.season i.dow i.starthour i.week $holidays $weather if ShareReported >= .7 & maxGap <=14 & dow==0, absorb(ori) cluster(TeamSeason)
keep if e(sample)==1

sort season hometeam ori
egen group1=group(season hometeam ori)
by season hometeam: egen group1min=min(group1)
by season hometeam: egen group1max=max(group1)
gen agencies=group1max-group1min+1
sort season hometeam Date
by season hometeam Date: drop if _n>1
sort season hometeam
by season hometeam: egen upsetlossescount=sum(upsetloss)
sort hometeam season
by hometeam season: drop if _n>1
keep season hometeam upsetlossescount agencies
* Number of agencies in the first and last years of the sample:
sort hometeam season
by hometeam: gen agenciesfirst = agencies if _n==1
by hometeam: gen agencieslast  = agencies if _n==_N

collapse (min) yrfirst=season (max) yrlast=season (min) ulmin=upsetlossescount (max) ulmax=upsetlossescount (mean) ulmean=upsetlossescount ///
         (mean) agenciesfirst agencieslast (mean) agmean=agencies, by(hometeam)
		 
gen str12 c1 = string(yrfirst,"%4.0f")
gen str12 c2 = string(yrlast, "%4.0f")
gen str12 c3 = string(ulmin,  "%2.0f")
gen str12 c4 = string(ulmax,  "%2.0f")
gen str12 c5 = string(ulmean,"%4.2f")
replace c5 = string(ulmean,"%2.0f") if ulmean==int(ulmean)
gen str12 c6 = string(agenciesfirst,"%3.0f")
gen str12 c7 = string(agencieslast, "%3.0f")
gen str12 c8 = string(round(agmean,.01))

listtab hometeam c1-c8 using "$results\Table2-Teams.tex", replace rstyle(tabular) ///
    head("\begin{tabular}{lcccccccc}" "\toprule" ///
         "& \multicolumn{2}{c}{Years in Sample} & \multicolumn{3}{c}{Upset Losses} & \multicolumn{3}{c}{Reporting Agencies} \\" ///
         "\cmidrule(lr){2-3}\cmidrule(lr){4-6}\cmidrule(lr){7-9}" ///
         "& First & Last & Min & Max & Mean & First & Last & Mean \\" "\midrule") ///
    foot("\bottomrule" "\end{tabular}")