############################
#!/bin/bash
###########################

# Usage: ./run.sh 2003-06-01 2003-06-30 hw (heat waves for the month of June 2003)
# Usage: ./run.sh 2003-03-01 2003-03-09 cs (cold spell for the month of March 2003)

source run_variables.sh
source run_utility.sh

rm -rf quantile*.nc
rm -rf binary*.nc
rm -rf anomaly*.nc

##################################################################################################
#
# CDO and R script for heatwaves
#
# yymmddS: the first positional argument of the script, the initial date for the heatwave computation
# yymmddE: the second positional argument of the script, the final date for the heatwave computation
# event: the third position argument ("hw" for heat waves, "cs" for cold waves)
#
##################################################################################################

yymmddS=${1}
yymmddE=${2}
event=${3}

# ${#event} is the length of the "event" string.
#"event" contains the third argument passed to ./run.sh 

if [ ${#event} -eq 0 ] || [ ${#yymmddS} -eq 0 ] || [ ${#yymmddE} -eq 0 ];then

    echo ""
    echo "Three non-empty arguments must be passed to run.sh"
    echo "E.g: ./run.sh 2003-06-01 2003-06-10 hw"
    exit 1
    
fi   


######################################################################
#
#Check if the third argument is "hw" (for heatwaves) or "cs" (for cold spells).
#If not, the script stops
#
######################################################################

#quantile_vect is the vector with the quantile values (90 for heatwaves, 10 for cold spells)

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
# Check the input dates: the first and the second positional arguments passed to the script
# are valid dates? are formatted well?
#
######################################################################

check_date ${yymmddS}
check_date ${yymmddE}


######################################################################
#
# Extract the quantiles
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
