############################
#!/bin/bash
###########################

# Usage: ./run.sh 2003-06-01 2003-06-30 hw (heat waves for the whole month of June 2003)
# Usage: ./run.sh 2003-03-01 2003-03-09 cs (cold spell for the month of March 2003, from the 1st to the 9th of March)

##########################
#this bash script uses two other sources:
#########################
source run_variables.sh #some input variables
source run_utility.sh #utility functions

#########################
#remove previous temporary output files from the working directory
#########################
rm -rf quantile*.nc
rm -rf binary*.nc
rm -rf anomaly*.nc

##################################################################################################
#
# CDO and R script for heatwaves
#
# The three positional arguments passed to ./run.sh are save into three variables: yymmddS, yymmddE and event.
#
# yymmdd is for year month day, S is for start, E is for end: yymmddS and yymmddE
#
# yymmddS: the first positional argument of the script, the initial date for the heatwave/coldspell computation
# yymmddE: the second positional argument of the script, the final date for the heatwave/coldspell computation
# event: the third position argument ("hw" for heat waves, "cs" for cold spells)
#
##################################################################################################

yymmddS=${1}
yymmddE=${2}
event=${3}

##################################################################################################
#
# TSrat checking if three arguments have been passed to the script or not. If not, stop.
#
#################################################################################################

# ${#event} is the length of the "event" string.

if [ ${#event} -eq 0 ] || [ ${#yymmddS} -eq 0 ] || [ ${#yymmddE} -eq 0 ];then

    echo ""
    echo "Three non-empty arguments must be passed to run.sh"
    echo "E.g: ./run.sh 2003-06-01 2003-06-10 hw"
    exit 1
    
fi   


######################################################################
#
# Check the input dates: the first and the second positional arguments passed to the script
# are valid dates? are formatted well?
#
######################################################################

check_date ${yymmddS}
check_date ${yymmddE}

######################################################################
#
# Check if the third argument is "hw" (for heatwaves) or "cs" (for cold spells).
# If not, the script stops
#
######################################################################

#quantile_vect is the vector with the quantile values (90 for heatwaves, 10 for cold spells). quantile_vect
#is defined in run_variables.sh

if [ ${event} = "hw" ];then
    
    quantile="${quantile_vect[0]}" #quantile for hw
    GTLT="ge" #operator for CDO: temperature >= (ge) than the threshold
    event_name="HeatWave" #<---- do not use spaces here, too fix!!

    
elif [ ${event} = "cs" ];then

    quantile="${quantile_vect[1]}"
    GTLT="le" #less equal CDO operator, for cold spells
    event_name="ColdSpell" #<---- do not use spaces here, too fix!!


else

    echo "${event} is not valid, please use: hw or cs"
    exit 1
    
fi


######################################################################
#
# Welcome message
#
######################################################################

welcome_message ${event_name} ${yymmddS} ${yymmddE} ${quantile}


######################################################################
#
# Extract the quantiles for the period: yymmddS - yymmddE
# The quantile depends on the event (90 for heatwaves, 10 for cold spells)
#
######################################################################

extract_quantile ${yymmddS} ${yymmddE} "max" ${quantile}
extract_quantile ${yymmddS} ${yymmddE} "min" ${quantile} 


######################################################################
#
# Subset the data
#
######################################################################

extract_data ${yymmddS} ${yymmddE} "max" ${quantile}
extract_data ${yymmddS} ${yymmddE} "min" ${quantile} 

######################################################################
#
#create the intersection between Tmax and Tmin: this is the file to elaborate with R
#
######################################################################
intersect_data ${yymmddS} ${yymmddE} ${quantile}



######################################################################
#
#create Tmax+Tmin anomaly netCDF file for the I2(n) intensity metric
#
######################################################################
sum_anomaly  ${yymmddS} ${yymmddE} ${quantile}


######################################################################
#
# Launch R program to detect heat waves
#
######################################################################
R CMD BATCH --vanilla "--args ${yymmddS} ${yymmddE}" hw.R 
