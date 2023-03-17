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

#args <- commandArgs(trailingOnly = TRUE)
#print(args)

######################################################
##### Look for the "intersection" netCDF file. 
##### This is the file where: 
##### 1 when both Tmax and Tmin above threshold (Q90 or Q10)
##### 0 Tmax | Tmin below threshold
######################################################

list.files(pattern="^binary.+_intersection_quantile.+\\.nc")->intersection_ffile

if(!length(intersection_ffile)){
  stop("No intersection file found!")
}else if(length(intersection_ffile)>1){
  stop("Too many intersection files found! \n Please delete the old files!")
}else{
  rast(intersection_ffile)->hw_brick  
}

######################################################
##### Extract the info from the filename and create a calendar from yymmddS to yymmddE
######################################################

str_extract(intersection_ffile,"[0-9_-]+")->date_string
unlist(str_split(str_remove(date_string,"_"),"_"))->dates
dates[1]->yymmddS
dates[2]->yymmddE

as.Date(yymmddS,format="%Y-%m-%d")->yymmddS
as.Date(yymmddE,format="%Y-%m-%d")->yymmddE
seq.Date(yymmddS,yymmddE,by="day")->calendar
length(calendar)->number_of_days


######################################################
##### Look for the "anomaly" netCDF file.
##### This file has been calculated using CDO and it is used to calculate the first intensity heat wave metric.
##### Each time stamp of this file contains the sum of the Tmax and Tmin anomalies; namely: (Tmax-Qtmax+Tmin-Qtmin)
######################################################

list.files(pattern="^anomaly.+_i2n_quantile.+\\.nc")->anomaly_ffile

if(!length(anomaly_ffile)){
  stop("No anomaly I2(m) file found!")
}else if(length(anomaly_ffile)>1){
  stop("Too many anomaly files found! \n Please delete the old files!")
}else{
  rast(anomaly_ffile)->anomaly_brick 
}

######################################################
##### Calculate Heat Waves
######################################################
purrr::partial(.f=hw,.hw=hw_brick,.anomaly=anomaly_brick,.length_hw=LENGTH_HW,.max_number_pool_days=MAX_NUMBER_POOL_DAYS)->hw2
purrr::map2(1:number_of_days,calendar,.f=hw2)->listOut

rast(purrr::map(listOut,"hw"))->brickHW
rast(purrr::map(listOut,"i2n"))->brickI2

writeCDF(brickHW,glue::glue("hw_{yymmddS}_{yymmddE}.nc"),overwrite=TRUE)
writeCDF(brickI2,glue::glue("i2n_{yymmddS}_{yymmddE}.nc"),overwrite=TRUE)
