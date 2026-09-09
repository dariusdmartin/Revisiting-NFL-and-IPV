***merge.do: Merge datasets together and create variables used in analysis
*Note: program called by main.do
clear

* MQ edit: drop observations where teama is missing in CD's nfl-online
*use "$data\misc\nfl-online", clear
*drop if missing(teama)
*save "$data\misc\nfl-online-MQ", replace

capture mkdir "$data\merge"

***Merge nfl and nibrs data together
*Note: Must first create nibrsihour dataset using crimedata-step1.do, crimedata-step2.do, and crimedata-step3.do
use "$data\misc\nibrsihour", replace
ren Date mdy
merge teama mdy using "$data\misc\nfl-online"
replace dow=dow(mdy)
drop _merge
sort statefips mdy
save "$data\misc\nibrsnfl", replace

***Merge in holidays & weather for online appendix
merge n:1 statefips mdy using "$data\misc\holidaysweather", keep(match) nogen
save "$data\misc\all", replace

***create cumweek (week of season) for non-gameday Sundays in our sample
* MQ: In nfl-online, cumweek is (usually) missing for non-gameday Sundays. Here, CD create a new dataset matching each date of the season with the week of the season, and then merge that back in to the original dataset. 
use "$data\misc\all", replace 
*Note, due to Christmas falling on a Sunday in 2005, no Sunday games (for the teams in our sample, although a few NFL games were played) in the 16th week of the season
replace cumweek=16 if mdy==mdy(12,25,2005) 
keep if cumweek!=.
*MQ: Note: The sample doesn't contain any obs on 12/25/2005. None of the 6 teams included had a game on that day, so the date was dropped entirely above (line 19, drop if _merge==1)
*MQ: The collapse command here creates one row per mdy with the corresponding cumweek value. Ie, same as (1) keep mdy cumweek (2) bys mdy: keep if _n==1
collapse cumweek, by(mdy) fast
rename cumweek newcumweek
sort mdy
save "$data\misc\mdytocumweek", replace
use "$data\misc\all", replace
sort mdy
merge mdy using "$data\misc\mdytocumweek"
drop _merge
drop cumweek
rename newcumweek cumweek

*create season (yy) and week of season (ww) indicators
tab season, gen(yy)
tab cumweek, gen(ww)

*Create variables based on pre-game spread and halftime spread
gen spreadcat=1*(spread<-7 & spread!=.) + 1*(spread>=-7 & spread<-3.5) + 2*(spread>=-3.5 & spread<=3.5) + 3*(spread>3.5 & spread<=7) + 3*(spread>7 & spread!=.)

gen byte upsetloss=(gameday & loss & spreadcat==1)
gen byte closeloss=(gameday & loss & spreadcat==2)
gen byte upsetwin=(gameday & win & spreadcat==3)
gen byte predwin=spreadcat==1
gen byte predclose=spreadcat==2
gen byte predloss=spreadcat==3

gen spreadmiss=spread==.
replace spread=0 if spread==.
/*
gen halfspread=-halfdiff
gen halfpredwin=halfspread<-3
gen halfpredclose=halfspread>=-3 & halfspread<=3
gen halfpredloss=halfspread>3 & halfspread!=.
gen halfupsetloss=halfpredwin & loss
gen halfcloseloss=halfpredclose & loss
gen halfupsetwin=halfpredloss & win

replace halfspread=0 if halfspread==.

gen orcombo=(riv | s4t4p80) & !lowplayoff

global cat "riv lowplayoff s4t4p80 orcombo"

foreach var of varlist $cat {
  gen byte upsetloss`var'=upsetloss*`var'==1
  gen byte closeloss`var'=closeloss*`var'==1
  gen byte upsetwin`var'=upsetwin*`var'==1
  gen byte predwin`var'=predwin*`var'==1
  gen byte predclose`var'=predclose*`var'==1
  gen byte predloss`var'=predloss*`var'==1
}
*/
gen byte upsetlossbase=upsetloss
gen byte closelossbase=closeloss
gen byte upsetwinbase=upsetwin
gen byte predwinbase=predwin
gen byte predclosebase=predclose
gen byte predlossbase=predloss

foreach i in 1 4 {
  gen upsetloss`i'=upsetloss & easterntime==`i'
  gen closeloss`i'=closeloss & easterntime==`i'
  gen upsetwin`i'=upsetwin & easterntime==`i'
  gen predwin`i'=predwin & easterntime==`i'
  gen predclose`i'=predclose & easterntime==`i'
  gen predloss`i'=predloss & easterntime==`i'
}

save "$data\merge\final", replace
