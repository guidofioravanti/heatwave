hw<-function(.hw,.anomaly,.layer,.day,.length_hw=3,.max_number_pool_days=1){
  
  .hw[[.layer]]->x
  .anomaly[[.layer]]->y
  
  previous_date<-.day-1

  ######################################################
  ##### Read the previous file where the data are stored
  ##### 1) The program looks for a heat wave file referred to the yymmdd-1
  ##### 2) If this file is missing, the program reads a "template" file with all 0s
  #####
  ##### If 1) we don't need to reprocess the past data
  #####
  ######################################################
  
  tryCatch({

    rast(glue::glue("./scratch/hw_{previous_date}.tif")) 
    
  },error=function(e){
    
    rast("hw_previous_template.tif")
    
  })->hw_previous
  
  ######################################################
  ##### Read the previous file where the intensity data are stored
  ##### 1) The program looks for an intensity file referred to the yymmdd-1
  ##### 2) If this file is missing, the program reads a "template" file with all 0s
  #####
  ##### If 1) we don't need to reprocess the past data
  #####
  ######################################################
  
  tryCatch({
    
    rast(glue::glue("./scratch/i2n_{previous_date}.tif")) 
    
  },error=function(e){
    
    rast("i2n_previous_template.tif")
    
  })->i2n_previous  
  
  ######################################################
  ##### Read the pool file where the number of pool days is stored
  ##### If we process new data we need to know how many pool days have been observed 
  ##### in the previous elaboration.
  ##### The program looks for a pool previous file. If missin, the program reads a pool template file 
  ##### with all 0s.
  ######################################################
  
  tryCatch({
    
    rast(glue::glue("./scratch/hw_poolcount_{previous_date}.tif"))
    
  },error=function(e){
    
    rast("hw_poolcount_template.tif")
    
  })->pool_days_count  
  
  
  
  # Temporary local grids

  i2n_previous->temp_i2n_previous
  hw_previous->temp_hw_previous
  pool_days_count->temp_pool_days_count

  ######
  # First/Second case: previous case is 0, pool is 0, x is 0 or 1
  # When x=0, nothing to do
  ######
  
  #ifel((hw_previous==0) & (pool_days_count==0) ,x+hw_previous,x)->x
  CASE1<-((hw_previous==0) & (pool_days_count==0) )
  temp_hw_previous[CASE1]<-x+hw_previous
  temp_i2n_previous[CASE1]<-y+i2n_previous
  
  ######
  # Third case: previous case is !=0, pool is 0, x is 1
  # Here, if we overwite x no problem..we don't interfere with the following cases
  ######  
  CASE2<-((x==1) & (hw_previous!=0) & (pool_days_count==0))
  temp_hw_previous[CASE2]<-x+hw_previous
  temp_i2n_previous[CASE2]<-y+i2n_previous
  
  
  ######
  # Fourth case: previous case is !=0, pool is 0, x is 0
  ######  
  CASE3<-((x==0) & (hw_previous!=0) & (pool_days_count==0))
  temp_hw_previous[CASE3]<-x+hw_previous
  temp_i2n_previous[CASE3]<-y+i2n_previous
  temp_pool_days_count[CASE3]<-pool_days_count+1
  
  ######
  # Fifth case: previous case is !=0, pool is .max_number_pool_days, x is 0
  ######  
  #ifel((x==0) & (hw_previous!=0) & (pool_days_count==MAX_NUMBER_POOL_DAYS) ,0,x)->x  
  CASE4<-((x==0) & (hw_previous!=0) & (pool_days_count==.max_number_pool_days))
  temp_hw_previous[CASE4]<-0
  temp_i2n_previous[CASE4]<-0
  temp_pool_days_count[CASE4]<-0

  
  ######
  # Sixth case: previous case is !=0, pool is < MAX_NUMBER_POOL_DAYS, x is 0
  ######
  CASE5<-((x==0) & (pool_days_count > 0) & (pool_days_count<.max_number_pool_days))
  temp_pool_days_count[CASE5]<-pool_days_count+1
  
  ######
  # 7th case: previous case is !=0, pool is MAX_NUMBER_POOL_DAYS, x is 0
  ######  
  CASE6<-((x==1) & (hw_previous!=0) & (pool_days_count > 0) & (pool_days_count<=.max_number_pool_days))
  temp_hw_previous[CASE6]<-x+hw_previous
  temp_pool_days_count[CASE6]<-0
  

  writeRaster(temp_hw_previous,glue::glue("./scratch/hw_{.day}.tif"),overwrite=TRUE,datatype="U32")
  writeRaster(temp_pool_days_count,glue::glue("./scratch/hw_poolcount_{.day}.tif"),overwrite=TRUE,datatype="U32")
  writeRaster(temp_i2n_previous,glue::glue("./scratch/i2n_{.day}.tif"),overwrite=TRUE)

  list(hw=ifel(temp_hw_previous>=.length_hw,temp_hw_previous,0),
       i2n=ifel(temp_hw_previous>=.length_hw,temp_i2n_previous,0))
  
}