* Project: Card and Dahl Replication
* Author: Darius Martin, coauthor Jason Query
* Description: This script obtains all public datasets needed for replication, related to geography, weather, and NFL results.

*  ────── Public Data from outside sources: ──────────────────────────────

* County population centers from the Census Bureau, using old CT counties
* Needed in script 1.
import delimited "https://www2.census.gov/geo/docs/reference/cenpop2020/county/CenPop2020_Mean_CO.txt", varnames(1) clear
save "$rawdata\CountyPopCenters", replace

* County shapefiles from the National Weather Service. Source of Time Zone, also uses old CT counties.
* Needed in script 1.
copy "https://www.weather.gov/source/gis/Shapefiles/County/c_18mr25.zip" "$rawdata\shapefiles\c_18mr25.zip", replace

cd "$rawdata\shapefiles"
unzipfile "c_18mr25.zip", replace
cd "$root"

* State Shapefiles from the Census - needed to draw hometeam maps if build_maps switch is on.
* Needed in script 15.
copy "https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_state_20m.zip" "$rawdata\shapefiles\cb_2024_us_state_20m.zip", replace
	 
cd "$rawdata\shapefiles"
unzipfile "cb_2024_us_state_20m.zip", replace
cd "$root"
	 
* Weather Station Locations from NOAA  - needed to find weather stations nearest NFL stadiums if build_weather switch is on.
* Needed in script 7
copy "https://www.ncei.noaa.gov/pub/data/noaa/isd-history.csv" "$rawdata\isdhistory.csv", replace

/* NFL Data and dates: (from sports odd hist), get the internet location here:
capture confirm file "$rawdata\NFL Data sportsoddhist.csv"
capture confirm file "$rawdata\nfldates.csv"
*/
