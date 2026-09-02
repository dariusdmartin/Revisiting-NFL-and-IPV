* Project: Card and Dahl Replication
* Name: Jason Alan Query, coauthor Darius Martin
* Packages Needed: (None)
* Uses: "$rawdata\NFL Data sportsoddhist.csv", "$rawdata\nfldates.csv"
* Creates: "$proc\NFLData_All", "$proc\nfldates"
* Description: Formats NFL Data

clear
tempfile allteams
save `allteams', emptyok

glo teams `" "Arizona Cardinals" "Atlanta Falcons" "Baltimore Ravens" "Buffalo Bills" "Carolina Panthers" "Chicago Bears" "Cincinnati Bengals" "Cleveland Browns" "Dallas Cowboys" "Denver Broncos" "Detroit Lions" "Green Bay Packers" "Houston Oilers" "Houston Texans" "Indianapolis Colts" "Jacksonville Jaguars" "Kansas City Chiefs" "Las Vegas Raiders" "Los Angeles Chargers" "Los Angeles Rams" "Miami Dolphins" "Minnesota Vikings" "New England Patriots" "New Orleans Saints" "New York Giants" "New York Jets" "Oakland Raiders" "Philadelphia Eagles" "Pittsburgh Steelers" "San Diego Chargers" "San Francisco 49ers" "Seattle Seahawks" "St. Louis Rams" "Tampa Bay Buccaneers" "Tennessee Titans" "Washington Commanders" "'

/******Gen Weeks and Years*****/
import delimited using "$rawdata\nfldates.csv", clear varnames(1)
save "$proc\nfldates", replace

/*****imprort data and name variables*****/
import delimited using "$rawdata\NFL Data sportsoddhist.csv", clear varnames(1)
rename dayofweek dow
label var dow "day of week of game"
label var date "date of game"
rename starttimeeastern starttime
label var starttime "start team - EST"
label var favoredteam "team favored to win"
label var favoredteamhomeoraway "favored team was home team if this variable has a value @, N indicates game was played at a neutral site"
label var result "result, W indicates the favored team won L indicates the favored team lost"
label var spread "W indicates the favored team covered the spread, L indicates the favored team did not cover the spread, P indicates the bet was a push, PK represents a Pick 'em game"
label var underdog "non-favored team"
label var underdogteamhomeoraway "underdog team was home team if this variable has a value @"
label var overunder "over under of game, O indicates over won the bet, U indicates under won the bet"
label var playoffgame "value of 1 if game is a playoff game"
replace playoffgame=0 if playoffgame==.
drop if playoffgame==1
merge m:1 date using "$proc\nfldates", keep(master match)
assert _merge==3
drop _merge

rename week Sunday
label var Sunday "NFL week of game played"
label var year "year of game played"
replace favoredteam="Tennessee Titans" if favoredteam=="Tennessee Oilers"
replace underdog="Tennessee Titans" if underdog=="Tennessee Oilers"
replace favoredteam="Washington Commanders" if favoredteam=="Washington Football Team"
replace underdog="Washington Commanders" if underdog=="Washington Football Team"
replace favoredteam="Washington Commanders" if favoredteam=="Washington Redskins"
replace underdog="Washington Commanders" if underdog=="Washington Redskins"
replace underdog="St. Louis Rams" if underdog=="St Louis Rams"
replace favoredteam="St. Louis Rams" if favoredteam=="St Louis Rams"

* Ensure no missing values of these variables:
count if missing(favoredteam) & missing(underdog) & missing(result)
assert r(N)==0

/*****generate relevant variables*****/
gen favoredteamhome1=1 if favoredteamhomeoraway=="@"
replace favoredteamhome1=0 if favoredteamhome1==.
*drop favoredteamhomeoraway
rename favoredteamhome1 favoredteamhome
label var favoredteamhome "favored team was home team if this variable has a value 1"
gen underdogteamhome1=1 if underdogteamhomeoraway=="@"
replace underdogteamhome1=0 if underdogteamhome1==.
*drop underdogteamhomeoraway
rename underdogteamhome1 underdogteamhome
label var underdogteamhome "underdog team was home team if this variable has a value 1"
*validty check
gen check=favoredteamhome+underdogteamhome+playoffgame
summ check
drop check
*end validity check

gen winloss=substr(result,1,1)
gen wl=1 if winloss=="W"
replace wl=0 if winloss=="L"
label var wl "value of 1 if favored team won"
drop winloss
rename wl winloss
gen byte tie = substr(result,1,1)=="T"
label var tie "value of 1 if game ended in a tie"
assert tie == missing(winloss)

gen cv=substr(spread,1,1)
gen covered=1 if cv=="W"
replace covered=0 if cv=="L"
replace covered=0 if cv=="P"
label var covered "value of 1 if favored team covered spread"
gen push=1 if cv=="P"
replace push=0 if push==.
label var push "value of 1 if the bet was a push"
drop cv

gen spreadvalue=substr(spread,3,40)
label var spreadvalue "numerical value of the spread"
drop if spreadvalue=="PK"
*NOTE: I DROPPED PICKEM GAMES BECAUSE I DON'T KNOW HOW TO QUANTIFY THOSE AS PREDICTED WINS OR PREDICTED LOSSES.  WE LOST 67 GAMES OUT OF MORE THAN 7400
destring spreadvalue, replace

/***Military Start Time***/
destring starttime, replace ignore(":")
replace starttime=starttime+1200 if starttime<1200
*Change AM games*
replace starttime=starttime-1200 if date=="10/26/2014" & favoredteam=="Detroit Lions"
replace starttime=starttime-1200 if date=="10/4/2015"  & favoredteam=="Miami Dolphins"
replace starttime=starttime-1200 if date=="10/25/2015" & favoredteam=="Buffalo Bills"
replace starttime=starttime-1200 if date=="11/1/2015"  & favoredteam=="Kansas City Chiefs"
replace starttime=starttime-1200 if date=="10/2/2016"  & favoredteam=="Indianapolis Colts"
replace starttime=starttime-1200 if date=="10/23/2016" & favoredteam=="New York Giants"
replace starttime=starttime-1200 if date=="10/30/2016" & favoredteam=="Cincinnati Bengals"
replace starttime=starttime-1200 if date=="9/24/2017"  & favoredteam=="Baltimore Ravens"
replace starttime=starttime-1200 if date=="10/1/2017"  & favoredteam=="New Orleans Saints"
replace starttime=starttime-1200 if date=="10/29/2017" & favoredteam=="Minnesota Vikings"
replace starttime=starttime-1200 if date=="10/21/2018" & favoredteam=="Los Angeles Chargers"
replace starttime=starttime-1200 if date=="10/28/2018" & favoredteam=="Philadelphia Eagles"
replace starttime=starttime-1200 if date=="10/13/2019" & favoredteam=="Carolina Panthers"
replace starttime=starttime-1200 if date=="11/3/2019"  & favoredteam=="Jacksonville Jaguars"
replace starttime=starttime-1200 if date=="10/10/2021" & favoredteam=="Atlanta Falcons"
replace starttime=starttime-1200 if date=="10/17/2021" & favoredteam=="Miami Dolphins"
replace starttime=starttime-1200 if date=="10/9/2022"  & favoredteam=="Green Bay Packers"
replace starttime=starttime-1200 if date=="10/30/2022" & favoredteam=="Jacksonville Jaguars"
replace starttime=starttime-1200 if date=="11/13/2022" & favoredteam=="Tampa Bay Buccaneers"
replace starttime=starttime-1200 if date=="10/1/2023"  & favoredteam=="Jacksonville Jaguars"
replace starttime=starttime-1200 if date=="10/8/2023"  & favoredteam=="Buffalo Bills"
replace starttime=starttime-1200 if date=="10/15/2023" & favoredteam=="Baltimore Ravens"
replace starttime=starttime-1200 if date=="11/5/2023"  & favoredteam=="Kansas City Chiefs"
replace starttime=starttime-1200 if date=="11/12/2023" & favoredteam=="Indianapolis Colts"
replace starttime=starttime-1200 if date=="10/6/2024"  & favoredteam=="Minnesota Vikings"
replace starttime=starttime-1200 if date=="10/13/2024" & favoredteam=="Jacksonville Jaguars"
replace starttime=starttime-1200 if date=="10/20/2024" & favoredteam=="Jacksonville Jaguars"
replace starttime=starttime-1200 if date=="11/10/2024" & favoredteam=="New York Giants"

foreach i in $teams {
preserve
	gen     check1=1 if favoredteam=="`i'"
	replace check1=0 if check1==.
	gen 	check2=1 if underdog=="`i'"
	replace check2=0 if check2==.
	gen 	check3=check1+check2
	sum check3
	drop if check3==0
	gen team="`i'"
	label var team "Local Team"
	
	gen     upset=1 if spreadvalue<=-4
	replace upset=0 if upset==.
	label var upset "value of 1 if spread is greater than or equal to 4"
	
	gen     close=1 if spreadvalue>-4
	replace close=0 if close==.
	label var close "value of 1 if spread is less than 4"

	gen predictedwin=1 if favoredteam=="`i'"
	replace predictedwin=0 if predictedwin==.
	label var predictedwin "value of 1 if team in var team is predicted to win"
	gen predictedloss=1-predictedwin
	label var predictedloss "value of 1 if team in var team is predicted to lose"

	gen byte win = 0
	replace win = 1 if predictedwin==1 & winloss==1
	replace win = 1 if predictedwin==0 & winloss==0
	label var win "value of 1 if team in var team won"

	gen byte loss = 0
	replace loss = 1 if predictedwin==1 & winloss==0
	replace loss = 1 if predictedwin==0 & winloss==1
	label var loss "value of 1 if team in var team lost"

	assert win+loss==1 if !tie
	assert win+loss==0 if  tie

	gen upsetlosspredictedwin=loss*predictedwin*upset
	label var upsetlosspredictedwin "value of 1 if the team in var team lost but was predicted to win"
	gen losspredictedclose=loss*close
	label var losspredictedclose "value of 1 if the team in var team lost but the spread was close"
	gen winpredictedloss=win*predictedloss*upset
	label var winpredictedloss "value of 1 if the tema in team var won but was predicted to lose"

    drop check1 check2 check3
    append using `allteams'
    save `allteams', replace
restore
}

use `allteams', clear
assert !missing(team)
count
save "$proc\NFLData_All", replace