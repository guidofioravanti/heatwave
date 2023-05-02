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
# Note: we need to take into account leap years! For non-leap years, we need to strip off the 29th February quantile from the quantile netCDF files
#
####################
####################

function extract_quantile {

    #extract "year" for the first date
    yearS=$(echo ${1} | cut -d"-" -f1)
    #"month" for the first date
    monthS=$(echo ${1} | cut -d"-" -f2)
    #"day" for the first date
    dayS=$(echo ${1} | cut -d"-" -f3)

    #extract "year" for the last date
    yearE=$(echo ${2} | cut -d"-" -f1)
    #extract "month" for the last date
    monthE=$(echo ${2} | cut -d"-" -f2)
    #extract "day" for the last date
    dayE=$(echo ${2} | cut -d"-" -f3)

    #Note: the idea is that the script is run for one year (namely, yearS==yearE)
    #This does not affect the results
    #because for the computation of the heatwaves length/intensity,
    #the script considers the previous date results. So for the elaboration of cold spells over two years:
    # -run the script till the 12/31 of the first year
    # -run the script from the 01/01 of the second year


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

	leapCommand="-del29feb" #delete 29feb from the quantile files

    fi 

    #the command below:
    # -first apply the leapCommand: for a leap year
    #  the CDO command is "-del29feb", otherwise no action is taken
    # -second extract the area of interest
    # -third, select the period of interest
    # -forth, select the name of the variable of interest


    #The timestamp in the quantile files is 2020. This year is stored in the variable "q_year"
    #The variable name in the quantile files and in the input files is t2m. This name is stored
    #in the variable "var_name".

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

    #extract the year, month and day from the first date yymmddS
    yearS=$(echo ${1} | cut -d"-" -f1)
    monthS=$(echo ${1} | cut -d"-" -f2)
    dayS=$(echo ${1} | cut -d"-" -f3)

    #extract the year, month and day from the second date yymmddE (we have already checked that yearS==yearE)
    monthE=$(echo ${2} | cut -d"-" -f2)
    dayE=$(echo ${2} | cut -d"-" -f3)

    #subset daily data and save them in a temporary file temp.nc
    #Here, there is no problem with the 29feb. The quantile files always contain the 29th of february.
    #The input data contain the 29th of February only for leap years.
    cdo select,name=${var_name} -seldate,${1},${2} \
        -sellonlatbox,${xmin},${xmax},${ymin},${ymax} \
	${yearS}_cds_era5_2m_temperature_${3}.nc temp.nc
    
    #create a binary file: 1 if temp >= quantile (temp <= quantile for cold spells), 0 otherwise
    #GTLT is a cdo operator defined at the beginning of the script. If we are elaborating heatwaves,
    #GTLT is ge (greater or equal than). For cold spells, the operator is le (less or equal than).
    cdo -b F32 ${GTLT} temp.nc \
                  quantile_${monthS}_${dayS}_${monthE}_${dayE}_${3}_quantile${4}.nc \
                  binary_${1}_${2}_cds_era5_2m_temperature_${3}_quantile${4}.nc

    #The binary output files contain 1 where the condition is TRUE, 0 otherwise. We use the sequences of 1s to
    #have the length of a heatwave/coldspell.
    
    #calculate anomaly (for intensity: I2(n) metric in the paper of Christof)
    cdo -b F32 sub temp.nc \
		   quantile_${monthS}_${dayS}_${monthE}_${dayE}_${3}_quantile${4}.nc \
		   anomaly.nc

    #anomaly.nc contains the difference between the daily temperature and its quantile.

    if [ ${event} = "hw" ];then

	#where anomalies are negative assign 0 otherwise 1
	cdo gec,0 anomaly.nc mask.nc

    elif [ ${event} = "cs" ];then

	#where anomalies are positive assign 0 otherwise 1
	cdo lec,0 anomaly.nc mask.nc	
	
    else

    echo "Why am I here? This cannot happen!"
    exit 1
    
    fi	
	   	
    #for the intensity, we need to store only those values where mask.nc is 1.	
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

    #sum anomaly and divide by 2: 
    cdo divc,2 -add anomaly_${1}_${2}_cds_era5_2m_temperature_max_quantile${3}.nc \
            anomaly_${1}_${2}_cds_era5_2m_temperature_min_quantile${3}.nc \
	    anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc

    if [ ${event} = "cs" ];then
	
	cdo mulc,-1 anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc temp.nc
	mv temp.nc anomaly_${1}_${2}_cds_era5_2m_temperature_i2n_quantile${3}.nc

    fi     

}



