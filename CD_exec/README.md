This directory contains our minimally-edited version of the code published by Gordon Dahl to generate the results in Card and Dahl (2011). We obtained the original code at Gordon Dahl's website here: <https://econweb.ucsd.edu/\~gdahl/football-violence-code.html> It enables a replication of Card and Dahl using their code, but running on our own independently collected NIBRS data from ICPSR. Minimal edits were necessary mainly to account for differences in the NIBRS data structure and formatting. We also identified and corrected some errors. These errors are thoroughly documented in MQ-crimedata-step3.do, we don't believe they have any material impact on the main results.



Running this requires some datasets that we obtained from Dahl's website. Also, it's necessary that the home directory has the same structure used by Card and Dahl. Namely, the home directory must have three subdirectories: data, out, and prog. The data subdirectory itself has three subdirectories - merge, misc, and nibrs.



To run the code, first update line 10 of MQ-main.do to give the full path to the home directory (contained in the global $homed), and update line 13 to give the full path to the directory containing NIBRS data (in $datanibrs).



The misc directory must contain the Stata datasets "holidaysweather.dta" and "nfl-online". We obtained these data by downloading "football-violence.dta.zip" at Gordon Dahl's website <https://econweb.ucsd.edu/\~gdahl/football-violence-code.html>. The misc directory must also contain the excel sheet "ICPSR NIBRS Codes.xlsx", which is included in this replication package (From the CD\_exec directory, navigate to data/misc). This excel sheet gives the numeric code that ICSPR assigns to each NIBRS extract, and is needed by the script MQ-crimedata-step1.do, which loads the NIBRS data to excel.



We obtained the NIBRS data from https://www.icpsr.umich.edu/sites/icpsr/find-data. Search for each annual NIBRS extract. E.g., enter "NIBRS 1995" into the search bar to get the 1995 extract. Select the result that links to the extract files (e.g., for the 1995 extract this page: https://www.icpsr.umich.edu/web/ICPSR/studies/22880/versions/V2). Then, click the download button, and select Stata. For 1995-2006, ICPSR distributes ASCII files and a Stata setup do-file, rather than a Stata dataset. For these years, it's necessary to make some minor edits to the setup do-file to ensure the data are extracted with the correct name to the correct location in datanibrs.



ICPSR assigns each NIBRS annual extract a different five digit code. The datanibrs folder must contain subfolders for each NIBRS extract from 1995-2006 name ICPSR\_ followed by the code for each year. E.g., the code for 1995 is 22880, so NIBRS data for 1995 is in $datanibrs\\ICPSR\_22880. Between 1995-2006, the incident extract should be in the subdirectory DS0001 and the victim extract in DS0002. This structure is created automatically when the datasets downloaded from ICPSR are extracted in the datanibrs folder.

