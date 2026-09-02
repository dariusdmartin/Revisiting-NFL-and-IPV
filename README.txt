__________________________________________________________________________________________________
Instructions:

To reproduce all tables and figures in the paper:

1) Download and unzip Revisiting-NFL-and-IPV-data.zip from google drive here:
2) Update line 7 of "master.do" to give the full path to the home directory for the replication.  
3) Run "master.do" (with default settings).

The home directory contains these sub-directories: raw_data, code, proc, results, provided_data, and maps. Sub-directories are created by master.do if they are not already present. 

raw_data contains needed datasets from outside sources, including NFL results and season information, geographic information for building maps and hometeam assignment, and codes used by ICPSR referring to annual NIBRS extracts. These datasets are included in Revisiting-NFL-and-IPV-data.zip.

proc contains datasets that are produced by scripts in the code directory. Tables and figures in the paper are produced by code using the proc datasets, and go in the results folder. The maps directory is only needed if the build_maps switch is on (see below). 

provided_data distributes six key datasets needed to run master.do with all switches set to their default values. Each of these datasets may be reconstructed from source data by the code provided a switch in master.do is set to 1.
___________________________________________________________________________________________________
Switches:

There are six switches in master.do. To turn a switch on, change the 0 to 1 for the desired switch on lines 10-15 of master.do. Most switches determine whether or not a key final dataset needed to generate results are reconstructed in the replication from source data. To facilitate replication, the versions of the six key datasets used to produce published tables and figures are included in the data archive "Revisiting-NFL-and-IPV-data.zip" in the directory "provided_data". With all switches off by default, master.do will reproduce all published tables and figures using those provided datasets. More details concerning each switch may be found below.

download_public     0   
build_drivedistance 0    
build_weather       0   
build_nibrs         0    
build_maps          0 
haveCDfiles         0

1. download_public 
Setting this switch to 1 executes "0_download_public_data.do". This script will attempt to obtain needed data related to geography, weather, and NFL spreads and results from the original public sources where they were originally obtained. The versions of these datasets used to produce published results are included in the archive "Revisiting-NFL-and-IPV-data.zip." The script also serves as documentation for the sources of these data.

2. build_drivedistance
This switch will run "2_calculate_driving_distances.do" to produce "driving distances.dta". Our preferred hometeam assignment procedure is based on driving distances between county population centers and NFL stadiums. This script calculates those driving distances using the Google Distance Matrix API. This script requires an API key, which must be provided in the global MapsAPIKey on line 21 of master.do.

3. build_weather
This switch will execute "7_create_weather_data" to produce "weather.dta", a dataset containing weather conditions as recorded at the NOAA station nearest each NFL team's home stadium on each gameday in the 1995-2023 NFL seasons. This involves downloads from the NOAA Global Summary of Day dataset online.

4. build_nibrs 
This switch determines whether the analytic sample is constructed from the raw NIBRS incident and victim extracts. Scripts 8 and 9 ("8_inclusion_criteria" and "9_extract_victim_files") only run if this switch is on. Both scripts require NIBRS data from ICPSR to be accessible at the location specified in the global datanibrs on line 18 of master.do

We originally obtained these data by navigating to https://www.icpsr.umich.edu/sites/icpsr/find-data. Search for each annual NIBRS extract. E.g., enter "NIBRS 2014" into the search bar to get the 2014 extract. Select the result that links to the extract files (e.g., for the 2014 extract this page: https://www.icpsr.umich.edu/web/ICPSR/studies/36421/versions/V2). Then, click the data and documentation tab, and download incident-level and victim-level Stata datasets. For earlier years (1995-2006), ICPSR distributes ASCII files and a Stata setup do-file, rather than a Stata dataset. For these years, it's necessary to make some minor edits to the setup do-file to ensure the data are extracted with the correct name to the correct location in datanibrs.

ICPSR assigns each NIBRS annual extract a different five digit code. The datanibrs folder must contain subfolders for each NIBRS extract from 1995-2024 name ICPSR_ followed by the code for each year. E.g., the code for 1995 is 22880, so NIBRS data for 1995 is in $datanibrs\ICPSR_22880. For years before 2017, the incident extract should be in the subdirectory DS0001 and the victim extract in DS0002. From 2017 on, the incident and victim extracts should be in subdirectories DS0003 and DS0004 respectively. This structure should be created automatically when the datasets downloaded from ICPSR are extracted in the datanibrs folder. 

5. build_maps
The replication only reproduces Figures 1 and 2 if the build_maps switch is on. This is off by default, as the necessary shapefile processing is time consuming. 

6. haveCDfiles
This switch indicates whether the estimation sample originally used in Card and Dahl (2011) is present in the raw_data directory. We use the CD estimation sample to produce summary stats in column 1 of Table 1, and regression results in Table 3, columns 1 and 5, and columns 5-8 of the appendix table. If the switch is off, indicating that the sample is not present raw_data, then these numbers will not be replicated. This dataset, named "estsample.dta" must be generated from code and data distributed by Gordon Dahl, as we do not redistribute it in our replication package.

To obtain the dataset go to https://econweb.ucsd.edu/~gdahl/football-violence-code.html and download the following files: 
merge.do
tables.do
football-violence.dta.zip

Run merge.do and tables.do to create estsample.dta, and move it to $rawdata\estsample.dta.
___________________________________________________________________________________________________
Author-created datasets needed that are included in Revisiting-NFL-and-IPV-data.zip:

"$rawdata\county_pop_center_fixes.csv" 
Needed by: scripts 1 and 2. 
Description: Hometeams are assigned based on distance from county pop center. These fixes are used for certain counties where the hometeam is distant from a road, and the google maps API could not calculate driving distance. For these counties, the population center is reset to the location of the county seat.
 
"$rawdata\SeasonDatesNFL.xlsx",
Needed by: scripts 5, 7, 11
Description: Has the start and end dates of each NFL season.

"$rawdata\CT county correspondence.xlsx"
Needed by: scripts 8 and 9
Description: Connecticut County Correspondence - CT replaced counties with planning regions in 2023. The NIBRS data switches to new planning regions in 2023. However, the dataset $proc\census counties" that we produce which links counties to hometeams and time zones, uses old CT counties. It comes from Census Bureau pop centers and NWS shapefiles, which used old counties as of 2026. 

"$rawdata\missing counties fips.xlsx"
Needed by: scripts 8 and 9
Description: FIPS codes for agencies with missing county codes in the raw NIBRS data. This is mostly for city agencies in VA, as cities in VA are independent and not officially within a county.

"$rawdata\ICPSR NIBRS Codes.xlsx"
Needed by: scripts 8 and 9
Description: Has the numeric codes for each year's NIBRS extracts from ICPSR.

"$rawdata\Stadiums.xlsx"

"$rawdata\team color scheme.txt"
Needed by: script 15.

Sources of all tables and figures in the paper:
Table 1 -> "12_summary stats.do"
Table 2 -> "12_summary stats.do"
Table 3 -> "13_regressions.do"
Table 4 -> "13_regressions.do"
Table 5 -> "13_regressions.do"
Table 6 -> "13_regressions.do"
Table 7 -> "13_regressions.do"
Table 8 -> "14_regional heterogeneity.do"
Table 9 -> "14_regional heterogeneity.do"
Table 10 -> "13_regressions.do"

Figure 1 -> "15_draw hometeam maps.do"
Figure 2 -> "15_draw hometeam maps.do"
Figure 3 -> "13_regressions.do"
Figure 4 -> "13_regressions.do"
Figure 5 -> "13_regressions.do"
Figure 6 -> "13_regressions.do"
