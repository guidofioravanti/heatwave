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
# event: the third position argument ("hw" for heat waves, "cw" for cold waves)
#
##################################################################################################

yymmddS=${1}
yymmddE=${2}
event=${3}

if [ ${#event} -eq 0 ] || [ ${#yymmddS} -eq 0 ] || [ ${#yymmddE} -eq 0 ];then

    echo "Three non-empty arguments must be passed to run.sh"
    echo "E.g: ./run.sh 2003-06-01 2003-06-10 hw"
    exit 1
    
fi   


######################################################################
#
#Check if the third argument is "hw" (for heatwaves) or "cw" (for cold spells). If not, the script stops
#
######################################################################

if [ ${event} = "hw" ];then
    
    quantile="${quantile_vect[0]}" #quantile
    GTLT="ge" #operator for CDO
    event_name="HeatWave"

    
elif [ ${event} = "cw" ];then

    quantile="${quantile_vect[1]}"
    GTLT="le"
    event_name="ColdSpell"


else

    echo "${event} is not valid, please use: hw or cw"
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
# Check the input dates
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
