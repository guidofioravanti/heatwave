#!/bin/bash

######################
#
# This function prints a welcome message: if we are processing heat waves or cold spells, the first and last date and the quantile
#
######################

function welcome_message {

    echo ""    
    echo "###############################################################"
    echo ""
    echo "Computation of ${1} from ${2} to ${3}, reference quantile: ${4}"
    echo ""
    echo "###############################################################"    

}


######################################################################
#
# This function checks the "date" arguments:
# - od the input dates use the "-" separator?
# - are the dates valid?
#
######################################################################

function check_date {

    #count the number of "-" occurences in the argument
    #if the number is != 2, the script stops
    
    ris=$(echo ${1} | grep -o "-" | wc -l)

    if [ ${ris} != "2" ];then

	echo "Bad string separator in ${1}, please use the format: yyyy-mm-dd"
	exit 1
	
    fi

    #ok, the date contains two "-", but is it the date correct?
    date_ris=$(date -d ${1} 2>&1 | grep -c "invalid")

    #if date_ris equals 1, it means that grep -c has found one occurence of "invalid" in the output of the date command
    if [ ${date_ris} = 1 ];then

	echo "Invalid date ${1}"
	exit 1

    fi
 


} #end of check_date


####################
####################
#
# Subset quantiles
#
# We need to extract the quantiles for the period of interest (from ${yymmddS} to  ${yymmddE})
#
# yymmddS is the first date (the first argument passed to the ./run.sh script)
# yymmddE is the last date (the second argument passed to the ./run.sh script)
#
# Note: we need to take into account leap years!
#
####################
####################

function extract_quantile {

    #estract year for the first date
    yearS=$(echo ${1} | cut -d"-" -f1)
    #month for the first date
    monthS=$(echo ${1} | cut -d"-" -f2)
    #day for the first date
    dayS=$(echo ${1} | cut -d"-" -f3)

    #estract year for the last date
    yearE=$(echo ${2} | cut -d"-" -f1)
    #extract month for the last date
    monthE=$(echo ${2} | cut -d"-" -f2)
    #extract day for the last date
    dayE=$(echo ${2} | cut -d"-" -f3)

    #Note: the idea is that the script is run for one year (namely, yearS==yearE)
    #This does not affect the results
    #because for the computation of the heatwaves length/intensity,
    #the script considers the previous date.


    if [ ${yearS} != ${yearE} ];then

        echo "Please, the first and last dates must refer to the same year!"   
	exit 1
	
    fi
    
    
    #check the presence of 29th february (leap year)
    let reminder="${yearS} % 4"

    #the quantile file contains the 29th, this must be stripped off for non-leap years
    if [ ${reminder} -eq 0 ];then

	leapCommand=""
	
    else

	leapCommand="-del29feb" #delete 29feb from the input dataset

    fi 

    #the command below:
    # -first apply the leapCommand: for a leap year
    #  the CDO command is "-del29feb", otherwise no action is taken
    # -second extract the area of interest
    # -third, select the period of interest
    # -forth, select the name of the variable of interest 

    cdo select,name=${var_name} -seldate,${q_year}-${monthS}-${dayS},${q_year}-${monthE}-${dayE} \
        -sellonlatbox,${xmin},${xmax},${ymin},${ymax} \
	${leapCommand}\
	./quantiles/cds_era5_2m_temperature_${3}_ydrunpctl${4}_fix29feb.nc \
        quantile_${monthS}_${dayS}_${monthE}_${dayE}_${3}_quantile${4}.nc
    #subset of Arthur's quantile file

    
} #end extract_quantile


############################################################################################
#
# Subset the data:
#
# - extract the daily data from ${yymmddS} to ${yymmddE}
# - for tmax and tmin, generate a binary file where: 1 (temperature above (hw)/below(cs)
#   the threshold), 0 otherwise;
# - for tmax and tmin, generate an anomaly file (temperature - threshold)
#   for the calculation of the I2(n) intensity metric
#
############################################################################################

function extract_data {

    yearS=$(echo ${1} | cut -d"-" -f1)
    monthS=$(echo ${1} | cut -d"-" -f2)
    dayS=$(echo ${1} | cut -d"-" -f3)

    monthE=$(echo ${2} | cut -d"-" -f2)
    dayE=$(echo ${2} | cut -d"-" -f3)

    #subset daily data and save them in a temporary file temp.nc
    #Here, there is no problem with the 29feb.
    cdo select,name=${var_name} -seldate,${1},${2} \
        -sellonlatbox,${xmin},${xmax},${ymin},${ymax} \
	${yearS}_cds_era5_2m_temperature_${3}.nc temp.nc
    
    #create a binary file: 1 if temp >= quantile (temp <= quantile for cold spells), 0 otherwise
    cdo -b F32 ${GTLT} temp.nc \
                  quantile_${monthS}_${dayS}_${monthE}_${dayE}_${3}_quantile${4}.nc \
                  binary_${1}_${2}_cds_era5_2m_temperature_${3}_quantile${4}.nc
    
    #calculate anomaly (for intensity I2(n) metric)
    cdo -b F32 sub temp.nc \
		   quantile_${monthS}_${dayS}_${monthE}_${dayE}_${3}_quantile${4}.nc \
		   anomaly.nc

    #where anomalies are negative assign 0 otherwise 1
    if [ ${event} = "hw" ];then
	
	cdo gec,0 anomaly.nc mask.nc

    elif [ ${event} = "cs" ];then

	cdo lec,0 anomaly.nc mask.nc	
	
    else

    echo "Why am I here? This cannot happen!"
    exit 1
    
    fi	
	   	
	
    cdo mul mask.nc anomaly.nc anomaly_${1}_${2}_cds_era5_2m_temperature_${3}_quantile${4}.nc

    #delete the temporary file, please!
    rm -rf temp.nc anomaly.nc mask.nc

} #end extract_data


####################
#
# Intersect Tmax and Tmin binary files in order to detect points where both Tmax and Tmin are above/below the corresponding threshold
#
####################


function intersect_data {

    #multiply binary files Tmax and Tmin: 1 is for cells where bot Tmax and Tmin are above
    #(or below) the threshold, 0 otherwise
    cdo mul binary_${1}_${2}_cds_era5_2m_temperature_max_quantile${3}.nc \
	    binary_${1}_${2}_cds_era5_2m_temperature_min_quantile${3}.nc \
            binary_${1}_${2}_cds_era5_2m_temperature_intersection_quantile${3}.nc 


}

######################################################################
#
#create Tmax+Tmin anomaly netCDF file for the I2(n) intensity metric
#
######################################################################


function sum_anomaly {

    #sum annomaly files Tmax and Tmin: 
    cdo divc,2 -add anomaly_${1}_${2}_cds_era5_2m_temperature_max_quantile${3}.nc \
            anomaly_${1}_${2}_cds_era5_2m_temperature_min_quantile${3}.nc \
	    anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc

    if [ ${event} = "cs" ];then
	
	cdo mulc,-1 anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc temp.nc
	mv temp.nc anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc

    fi     

}



