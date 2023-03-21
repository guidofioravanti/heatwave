#!/bin/bash

rm -rf quantile*.nc
rm -rf binary*.nc
rm -rf anomaly*.nc

##################################################################################################
#
# CDO and R script for heatwaves
#
# yymmddS: the first positional argument of the script, initial date for the heatwave computation
# yymmddE: the second positional argument of the script, final date for the heatwave computation
# event: the third position argument ("hw" for heat waves, "cw" for cold waves)
#
##################################################################################################

yymmddS=${1}
yymmddE=${2}
event=${3}

function welcome_message {

    echo ""    
    echo "###############################################################"
    echo ""
    echo "Computation of ${1} from ${2} to ${3}, reference quantile: ${4}"
    echo ""
    echo "###############################################################"    

}


if [ ${event} = "hw" ];then
    
    quantile="90"
    welcome_message "heat waves" ${yymmddS} ${yymmddE} ${quantile}
    
elif [ ${event} = "cw" ];then

    quantile="10"
    wlecome_message "cold waves" ${yymmddS} ${yymmddE} ${quantile}    

else

    echo "${event} is not valid, please use: hw or cw"
    exit 1
    
fi


####################
####################
#
# Subset quantiles
#
# We want to extract the quantile for the period between ${yymmddS} and ${yymmddE}
# We must take into account leap years
#
####################
####################

function extract_quantile {


    yearS=$(echo ${1} | cut -d"-" -f1)
    monthS=$(echo ${1} | cut -d"-" -f2)
    dayS=$(echo ${1} | cut -d"-" -f3)

    monthE=$(echo ${2} | cut -d"-" -f2)
    dayE=$(echo ${2} | cut -d"-" -f3)

    let reminder="${yearS} % 4"

    if [ ${reminder} -eq 0 ];then

	echo "Leap year...not implemented yet"
	exit 1
	
    else

        #the files provided by Arthur use 2021 as the year of the timestamps
        cdo select,name=t2m -seldate,2021-${monthS}-${dayS},2021-${monthE}-${dayE} \
	    1980-2021_cds_era5_2m_temperature_${3}_ydrunpctl${4}.nc \
            quantile_2021_${monthS}_${dayS}_2021_${monthE}_${dayE}_${3}_quantile${4}.nc #subset of Arthur's quantile file

    fi 
	
    
} #end extract_quantile

extract_quantile ${yymmddS} ${yymmddE} "max" ${quantile}
extract_quantile ${yymmddS} ${yymmddE} "min" ${quantile} 

############################################################################################
#
# Subset the data:
# - extract the daily data from ${yymmddS} to ${yymmddE}
# - for tmax and tmin, generate a binary file where: 1 (temperature above (hw)/below(cw) the threshold), 0 otherwise;
# - for tmax and tmin, generate an anomaly file for the calculation of the I2(n) intensity metric
#
############################################################################################

function extract_data {

    yearS=$(echo ${1} | cut -d"-" -f1)
    monthS=$(echo ${1} | cut -d"-" -f2)
    dayS=$(echo ${1} | cut -d"-" -f3)

    monthE=$(echo ${2} | cut -d"-" -f2)
    dayE=$(echo ${2} | cut -d"-" -f3)

    #subset daily data and save them in a temporary file temp.nc
    cdo select,name=t2m -seldate,${1},${2} ${yearS}_cds_era5_2m_temperature_${3}.nc temp.nc
    
    #create a binary file: 1 if temp > treshold, 0 otherwise
    cdo -b F32 gt temp.nc \
                  quantile_2021_${monthS}_${dayS}_2021_${monthE}_${dayE}_${3}_quantile${4}.nc \
                  binary_${1}_${2}_cds_era5_2m_temperature_${3}_quantile${4}.nc
    
    #calculate anomaly (for intensity I2(n) metric)
    cdo -b F32 sub temp.nc \
		   quantile_2021_${monthS}_${dayS}_2021_${monthE}_${dayE}_${3}_quantile${4}.nc \
		   anomaly.nc

    #where anomalies are negative assign 0 otherwise 1
    cdo gtc,0 anomaly.nc mask.nc
    cdo mul mask.nc anomaly.nc anomaly_${1}_${2}_cds_era5_2m_temperature_${3}_quantile${4}.nc

    #delete the temporary file, please!
    rm -rf temp.nc anomaly.nc mask.nc

} #end etract_data


extract_data ${yymmddS} ${yymmddE} "max" ${quantile}
extract_data ${yymmddS} ${yymmddE} "min" ${quantile} deselect when data are available


####################
# Intersect Tmax and Tmin binary files in order to detect points where both Tmax and Tmin are above/below the corresponding threshold
####################


function intersect_data {

    #multiply binay files Tmax and Tmin: 1 is for cells where bot Tmax and Tmin are above (or below) the threshold
    cdo mul binary_${1}_${2}_cds_era5_2m_temperature_max_quantile${3}.nc \
	    binary_${1}_${2}_cds_era5_2m_temperature_min_quantile${3}.nc \
            binary_${1}_${2}_cds_era5_2m_temperature_intersection_quantile${3}.nc 


}


#create the intersection between Tmax and Tmin: this is the file to elaborate with R
intersect_data ${yymmddS} ${yymmddE} ${quantile}



#create Tmax+Tmin anomaly netCDF file for the I2(n) intensity metric
function sum_anomaly {

    #sum annomaly files Tmax and Tmin: 
    cdo add anomaly_${1}_${2}_cds_era5_2m_temperature_max_quantile${3}.nc \
            anomaly_${1}_${2}_cds_era5_2m_temperature_min_quantile${3}.nc \
	    temp.nc
    
    cdo mul binary_${1}_${2}_cds_era5_2m_temperature_intersection_quantile${3}.nc \
	    temp.nc \
	    anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc     

    rm -rf temp.nc
}


sum_anomaly  ${yymmddS} ${yymmddE} ${quantile}


#launch R program to detect heat waves
#R CMD BATCH hw.R 


 


