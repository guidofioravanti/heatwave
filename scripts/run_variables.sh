#!/bin/bash

#study domain: xmin,xmax,ymin,ymax
xmin=-25
xmax=45
ymin=30
ymax=73

#vector with quantiles
quantile_vect=( 90 10 )

###########################################
#
# Year in the timestamp of the quantiles: fix here the year used in the timestamps of the quantile files
# For example: use "cdo sinfon name_of_the_quantile_file" to see the year in the timestamps 
#
###########################################
q_year=2020


###########################################
#
# Name of the variable in the quantile files and in the tmax/tmin files. The name must be the same
#
###########################################
var_name=t2m
