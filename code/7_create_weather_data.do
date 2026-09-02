* Project: Card and Dahl Replication 
* Name: Darius Martin, coauthor Jason Query
* Packages Needed: geodist
* Uses:    "$rawdata\isdhistory.csv", "$proc\NFLData_All", "$proc\nfl stadiums", "$proc\SeasonDatesNFL"
* Creates: "$proc\weather"
* Description: $proc\weather has observations for each team on each gameday, with indicators for weather at the station geographically nearest to team's home stadium.

capture program drop download_station
program define download_station
	args id yr jan_date filepath
	
	if "`id'"=="" | "`yr'"=="" | "`jan_date'"=="" | "`filepath'"=="" {
		display as error "download_station: empty argument — id=|`id'| yr=|`yr'| jan=|`jan_date'| file=|`filepath'|"
		exit 198
	}
	
	local downloaded = 0
	local attempts = 0
	while `downloaded' == 0 & `attempts' < 3 {
		capture copy "https://www.ncei.noaa.gov/data/global-summary-of-the-day/access/`yr'/`id'.csv" "temp.csv", replace
		if _rc == 0 {
			local downloaded = 1
			quietly {
				import delimited "temp.csv", clear stringcols(1)
				gen Date = date(date,"YMD")
				format %td Date
				if `jan_date' {
					keep if month(Date) == 1
				}
				else {
					drop if month(Date) < 8
				}
				keep station Date latitude longitude name max min mxspd prcp sndp temp dewp 
				ren station station_id
				append using `filepath'
				save `filepath', replace
			}
		}
		else {
			local attempts = `attempts' + 1
			display "Attempt `attempts' failed for `id' in season `yr', waiting..."
			sleep 5000
		}
	}
	if `downloaded' == 0 {
		disp "TRULY MISSING: id `id' and season `yr'"
	}
end

* Ensure needed weather station location data is in rawdata:
capture confirm file "$rawdata\isdhistory.csv"
if _rc {
	di as err "Missing $rawdata\isdhistory.csv — set build_weather to 0 or download replication_data.zip (see README)."
	exit 601
}

* Get a list of all dates of NFL games:
use "$proc\NFLData_All", clear
gen Date = date(date,"MDY")
format %td Date
drop date
keep Date
gen season = year(Date)
replace season = season-1 if month(Date)==1
bys Date: keep if _n==1

* Has one observation for any game-day league-wide. (Any day with an NFL game anywhere)
save "___temp_weather_data", replace

* Create one observation for each stadium on each league-wide game day.
use "$proc\nfl stadiums", clear
joinby season using "___temp_weather_data"
merge n:1 season using "$proc\SeasonDatesNFL", keep(match) nogen
* drop variables indicating postseason dates:
drop postStart postEnd
assert !missing(stadium_LAT) & !missing(stadium_LON)
save "___temp_weather_data", replace

* Get the nearest weather station to each stadium location:
quietly levelsof season, local(seasons)

clear
tempfile WeatherDate NearestStation
save `WeatherDate', emptyok
save `NearestStation', emptyok

foreach sn in `seasons' {
	display "Working on season `sn'"
	quietly {
	* Get all NFL stadium locations in the current season.
		tempfile teamyr gsod_stations
		
		use "___temp_weather_data", clear
		keep if season == `sn'
		bys team: keep if _n==1
		keep team season stadium_LAT stadium_LON regStart regEnd
		loc SeasonStart = regStart[1]
		loc SeasonEnd   = regEnd[1]
		save `teamyr', replace
	
	* Create a scalar indicating whether the season extends into January.
		scalar InJan = 0
		scalar str_years = "`sn'"
		if year(`SeasonEnd') > `sn' {
			scalar InJan = 1
			scalar str_years = "`sn' `= `sn' + 1'"
		}

		clear 	
		save `gsod_stations', replace emptyok
	
		**** Get a list of all weather stations from GSOD that are active throughout the season:
		local years_to_get = scalar(str_years)
		foreach yr in `years_to_get' {
			tempfile master_list
			copy "https://www.ncei.noaa.gov/data/global-summary-of-the-day/access/`yr'/" `master_list'
			import delimited `master_list', clear
			gen station_id = ustrregexs(0) if ustrregexm(v1, "[0-9]{11}")
			drop if missing(station_id)
			keep station_id
			bys station_id: keep if _n==1
		 
		* If not the first year, intersect with what we already have
			if "`yr'" != "`sn'" {
				merge 1:1 station_id using `gsod_stations', keep(match) nogen
			}
			save `gsod_stations', replace
		}

		* Limit to stations in GSOD that are active throughout the season: 
		import delimited "$rawdata\isdhistory.csv", clear
		keep if ctry == "US"
		drop if inlist(state, "AK","HI") | missing(state)
		drop if lat ==0 | missing(lat)
		gen str_begin = string(begin, "%12.0f")
		gen str_end   = string(end, "%12.0f")
		gen begin_date = date(str_begin, "YMD")
		gen end_date   = date(str_end,"YMD")
		format %td begin_date end_date
		keep if begin_date <= `SeasonStart' & end_date >= `SeasonEnd'
	
		* Create all stadium-weather station pairs:
		cross using `teamyr'
		geodist stadium_LAT stadium_LON lat lon, gen(distance)
		sort team distance
		gen station_id = usaf + string(wban,"%05.0f")
		merge n:1 station_id using `gsod_stations', keep(match) nogen
	
		* Keep weather information for the four nearest stations to each team. 
		sort team distance
		foreach vr in station_id distance stationname {
			by team: gen `vr'2 = `vr'[2]
			by team: gen `vr'3 = `vr'[3]
			by team: gen `vr'4 = `vr'[4]
		}
		label var station_id2 "id of 2nd nearest station"
		label var distance2   "distance of 2nd nearest station"
		label var stationname2 "name of the 2nd nearest station"
		
		by team: keep if _n==1
		keep team season station_id* stationname* lat lon distance*
		* Get the IDs of each station that's nearest an NFL stadium in the current season.
		levelsof station_id, local(IDs)
	
		append using `NearestStation'
		save `NearestStation', replace
	}
	* Download the weather data for the needed stations in the particular year. (Deal with January.)	
	local years_to_get = scalar(str_years)
	foreach id in `IDs' {
		foreach yr in `years_to_get' {
			loc is_jan_year = (`yr'==`sn'+1)
			download_station `id' `yr' `is_jan_year' `WeatherDate'
		}
	}
}

* Open our dataset with one observation for each team on any date with a gameday league-wide.
* Merge with `NearestStation', which has the id, name, and distance of the 4 nearest stations:
use "___temp_weather_data", clear
merge n:1 team season using `NearestStation', nogen
merge n:1 station_id Date using `WeatherDate', keep(master match) nogen
save "___temp_weather_data", replace

*** Fill in Missings:
use "___temp_weather_data", clear
count if missing(temp)
loc NumMissing = r(N)
loc level = 2

scalar s_NumMissing = `NumMissing'
scalar s_level = `level'
 
while `NumMissing' > 0 {
	clear
	tempfile MissingWeatherDate
	save `MissingWeatherDate', emptyok
	local level = s_level
	
	use "___temp_weather_data", clear
	gen missing_weather`level' = missing(temp)
	replace station_id  = station_id`level'    if missing_weather`level' == 1
	replace distance    = distance`level'      if missing_weather`level' == 1
	replace stationname = stationname`level'   if missing_weather`level' == 1
	save "___temp_weather_data", replace
	
	gen q = _n
	quietly levelsof q if missing_weather`level'==1, local(redo_weather)

	foreach k in `redo_weather' {
		use "___temp_weather_data", clear
		
		loc id = station_id[`k']
		loc yr = season[`k']
		loc jan_date = (month(Date[`k'])==1)
		if `jan_date'==1 {
			local yr = `yr'+1
		}
		download_station `id' `yr' `jan_date' `MissingWeatherDate'
	}
	use `MissingWeatherDate'
	quietly count
	if r(N) > 0 {
		bys station_id Date: keep if _n==1
		save "___missing_weatherdate`level'", replace
		use "___temp_weather_data", clear
		merge n:1 station_id Date using "___missing_weatherdate`level'", update
		drop if _merge==2
		drop _merge
		save "___temp_weather_data", replace
	}
	
	count if missing(temp)
	loc NumMissing = r(N)
	local level = `level'+1
	
	scalar s_NumMissing = `NumMissing'
	scalar s_level = `level'
	if `level' > 4 {
		loc NumMissing=0
	}
}
capture drop stationname2 stationname3 stationname4 station_id2 station_id3 station_id4 distance2 distance3 distance4 missing_weather2 missing_weather3 missing_weather4
save "___temp_weather_data", replace

* Note: Update missing values.
replace max = . if max > 9999
replace min = . if min > 9999
replace mxspd = . if mxspd > 999
replace prcp = . if prcp > 99
replace sndp = . if sndp > 999
replace temp = . if temp > 999

gen hot     = max > 80    if !missing(max) 
gen cold    = min < 32 	  if !missing(min)
gen windy   = mxspd > 17  if !missing(mxspd)
gen anyrain = prcp >0     if !missing(prcp)
gen anysnow = sndp >0     &  !missing(sndp)
gen T  = (temp-32)*5/9    if !missing(temp)

* Use temperature and dew point to calculate relative humidity (RH), according to this: https://earthscience.stackexchange.com/questions/16570/how-to-calculate-relative-humidity-from-temperature-dew-point-and-pressure
gen Td = (dewp-32)*5/9 if dewp < 9999
loc a = 17.625
loc b = 243.04 
gen RH = 100*exp(`a'*`b'*(Td-T) / ( (`b'+T)*(`b'+Td))) if (T > 0 & T < 60) & (Td > 0 & Td < 50)

* Calculate heat index (HI) using the equation given here: https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml
* Use max temp because there are no days with a high heat index using the mean temperature.
* Note: In the CD data, there are only 6 observations with a high heat index.

gen     maxheatindex = -42.379+2.04901523*max + 10.14333127*RH  - .22475541*max*RH - .00683783*max^2 - .05481717*RH^2 + .00122874*max^2*RH + .00085282*max*RH^2 - .00000199*max^2*RH^2 if max > 80
replace maxheatindex = maxheatindex - (13-RH)/4*sqrt((17-abs(temp-95))/17) if RH < 13 & max > 80 & max < 112
replace maxheatindex = maxheatindex + (RH-85)/10*(87-temp)/5 if RH > 85 & max > 80 & max < 87 & !missing(RH)
gen     hiheatindx  = maxheatindex > 100 & !missing(maxheatindex)

ren (latitude longitude) (WeatherStation_LAT WeatherStation_LON)

keep team Date stationname station_id WeatherStation_LAT WeatherStation_LON hot cold windy anyrain anysnow hiheatindx distance
save "$proc\weather", replace

capture erase "___temp_weather_data.dta"
capture erase "___missing_weatherdate2.dta"
capture erase "___missing_weatherdate3.dta"
capture erase "___missing_weatherdate4.dta"
capture erase temp.csv