rm(list=objects())
library("terra")
library("stringr")
library("lubridate")
library("purrr")
source("hw_functions.R")

#How many pool days?
MAX_NUMBER_POOL_DAYS<-1
#Lentgh of a heatwave
LENGTH_HW<-3
#Should a heatwave length (number of days) include the pool days?
COUNT_WITH_POOLS<-TRUE


#dates
yymmddS<-"2003-05-01" #start
yymmddE<-"2003-09-30" #end


######################################################
##### Extract the info from the filename and create a calendar from yymmddS to yymmddE
######################################################

as.Date(yymmddS,format="%Y-%m-%d")->yymmddS
as.Date(yymmddE,format="%Y-%m-%d")->yymmddE
seq.Date(yymmddS,yymmddE,by="day")->calendar
length(calendar)->number_of_days

######################################################
##### Look for the "intersection" netCDF file. 
##### This is the file where: 
##### 1 when both Tmax and Tmin above threshold (Q90 or Q10)
##### 0 Tmax | Tmin below threshold
######################################################

glue::glue("^binary_{yymmddS}_{yymmddE}_.+intersection_quantile.+\\.nc$")->intersectionFileName
list.files(pattern=intersectionFileName)->intersection_ffile

if(!length(intersection_ffile)){
  stop(glue::glue("No intersection {intersectionFileName} file found!"))
}else{
  rast(intersection_ffile)->hw_brick  
}



######################################################
##### Look for the "anomaly" netCDF file.
##### This file has been calculated using CDO and it is used to calculate the first intensity heat wave metric.
##### Each time stamp of this file contains the sum of the Tmax and Tmin anomalies; namely: (Tmax-Qtmax+Tmin-Qtmin)
######################################################

glue::glue("^anomaly_{yymmddS}_{yymmddE}_.+i2n_quantile.+\\.nc$")->anomalyFileName
list.files(pattern=anomalyFileName)->anomaly_ffile

if(!length(anomaly_ffile)){
  stop(glue::glue("No anomaly {anomalyFileName} file found!"))
}else{
  rast(anomaly_ffile)->anomaly_brick 
}


######################################################
##### Calculate Heat Waves
######################################################
purrr::partial(.f=hw,.hw=hw_brick,
               .anomaly=anomaly_brick,
               .total_number_of_days=number_of_days,
               .length_hw=LENGTH_HW,
               .max_number_pool_days=MAX_NUMBER_POOL_DAYS,
               .count_with_pools=COUNT_WITH_POOLS)->hw2

purrr::walk2(1:number_of_days,calendar,.f=hw2)

#look for hw files in scratch for the time period of interest
rast(purrr::map(glue::glue("./scratch/hw_previous_{calendar}.tif"),.f=~(readRaster(.))))->brickHW
rast(purrr::map(glue::glue("./scratch/i2n_previous_{calendar}.tif"),.f=~(readRaster(.))))->brickI2

rast(purrr::map(glue::glue("./scratch/hw_previous_fullcount_{calendar}.tif"),.f=~(readRaster(.))))->brickHW_fullcount
#rast(purrr::map(glue::glue("./scratch/i2n_previous_fullcount_{calendar}.tif"),.f=~(readRaster(.))))->brickI2_fullcount

#return fullcount values only where brickHW >= LENGTH_HW
purrr::map(1:number_of_days,.f=function(.lyr){
  
  ifel(brickHW[[.lyr]]>=LENGTH_HW,brickHW_fullcount[[.lyr]],0)
  
})->gridHW

purrr::map(1:number_of_days,.f=function(.lyr){
  
  ifel(brickHW[[.lyr]]>=LENGTH_HW,brickI2[[.lyr]],0)
  
})->gridI2


writeCDF(rast(gridHW),glue::glue("hw_{yymmddS}_{yymmddE}.nc"),overwrite=TRUE)
writeCDF(rast(gridI2),glue::glue("i2n_{yymmddS}_{yymmddE}.nc"),overwrite=TRUE)
