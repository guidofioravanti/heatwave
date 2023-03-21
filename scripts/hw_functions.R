readRaster<-function(.fileName){
  
  str_replace(.fileName,"[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}\\.tif","template.tif")->templateName

  tryCatch({
    
    rast(.fileName)
    
  },error=function(e){
    
    rast(templateName)
    
  })
  
  
}#end _readRaster


invalidate_previous_data<-function(.fileName,.day,.max_number_pool_days,.mask=CASE4){
  
  if(.max_number_pool_days==0){return()}

  purrr::walk(seq.Date(.day-.max_number_pool_days,.day-1,by="day"),.f=function(.x){

    readRaster(glue::glue("{.fileName}{.x}.tif"))->mygrid
    mygrid[.mask]<-0
    writeRaster(mygrid,glue::glue("{.fileName}{.x}.tif"),overwrite=TRUE)
    
  })  
  
}



hw<-function(.hw,.anomaly,.layer,.day,.total_number_of_days,.length_hw=3,.max_number_pool_days=1,.count_with_pools=TRUE){
  
  if(.total_number_of_days<0) stop()
  if(.max_number_pool_days<0) stop()  
  if(!is.logical(.count_with_pools)) stop()  
  if(!is.Date(.day)) stop()
  
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
  
  readRaster(glue::glue("./scratch/hw_previous_{previous_date}.tif"))->hw_previous
  readRaster(glue::glue("./scratch/hw_previous_fullcount_{previous_date}.tif"))->hw_previous_fullcount
  
  ######################################################
  ##### Read the previous file where the intensity data are stored
  ##### 1) The program looks for an intensity file referred to the yymmdd-1
  ##### 2) If this file is missing, the program reads a "template" file with all 0s
  #####
  ##### If 1) we don't need to reprocess the past data
  #####
  ######################################################
  
  readRaster(glue::glue("./scratch/i2n_previous_{previous_date}.tif"))->i2n_previous
  readRaster(glue::glue("./scratch/i2n_previous_fullcount_{previous_date}.tif"))->i2n_previous_fullcount
  
  ######################################################
  ##### Read the pool file where the number of pool days is stored
  ##### If we process new data we need to know how many pool days have been observed 
  ##### in the previous elaboration.
  ##### The program looks for a pool previous file. If missin, the program reads a pool template file 
  ##### with all 0s.
  ######################################################

  readRaster(glue::glue("./scratch/hw_poolcount_{previous_date}.tif"))->pool_days_count  
  
  if(.layer==1 & .count_with_pools){
    
    hw_previous_fullcount[(pool_days_count>0)]<-hw_previous_fullcount+pool_days_count
    
  }
    
  # Temporary local grids
  i2n_previous->temp_i2n_previous
  i2n_previous_fullcount->temp_i2n_previous_fullcount
  hw_previous->temp_hw_previous
  hw_previous_fullcount->temp_hw_previous_fullcount  
  pool_days_count->temp_pool_days_count

  ######
  # First/Second case: previous case is 0, pool is 0, x is 0 or 1
  # When x=0, nothing to do
  ######
  
  #ifel((hw_previous==0) & (pool_days_count==0) ,x+hw_previous,x)->x
  CASE1<-((hw_previous==0) & (pool_days_count==0) )
  temp_hw_previous[CASE1]<-x+hw_previous
  temp_i2n_previous[CASE1]<-y+i2n_previous
  temp_hw_previous_fullcount[CASE1]<-x+hw_previous_fullcount  
  temp_i2n_previous_fullcount[CASE1]<-y+i2n_previous_fullcount  

  ######
  # Third case: previous case is !=0, pool is 0, x is 1
  # Here, if we overwite x no problem..we don't interfere with the following cases
  ######  
  CASE2<-((x==1) & (hw_previous!=0) & (pool_days_count==0))
  temp_hw_previous[CASE2]<-x+hw_previous
  temp_i2n_previous[CASE2]<-y+i2n_previous  
  temp_hw_previous_fullcount[CASE2]<-x+hw_previous_fullcount  
  temp_i2n_previous_fullcount[CASE2]<-y+i2n_previous_fullcount  
  
  
  ######
  # Fourth case: previous case is !=0, pool is 0, x is 0
  ######  
  CASE3<-((x==0) & (hw_previous!=0) & (pool_days_count==0))
  
  temp_pool_days_count[CASE3]<-pool_days_count+1  
  
  if(.count_with_pools && (.layer<(.total_number_of_days-.max_number_pool_days+1))){
    temp_hw_previous_fullcount[CASE3]<-1+hw_previous_fullcount
    temp_i2n_previous_fullcount[CASE3]<-y+i2n_previous_fullcount
  }
  

  
  ######
  # Fifth case: previous case is !=0, pool is .max_number_pool_days, x is 0
  ######  
  #ifel((x==0) & (hw_previous!=0) & (pool_days_count==MAX_NUMBER_POOL_DAYS) ,0,x)->x  
  CASE4<-((x==0) & (hw_previous!=0) & (pool_days_count==.max_number_pool_days))

  temp_hw_previous[CASE4]<-0
  temp_i2n_previous[CASE4]<-0
  temp_hw_previous_fullcount[CASE4]<-0    
  temp_i2n_previous_fullcount[CASE4]<-0  
  temp_pool_days_count[CASE4]<-0
  
  if(any(values(CASE4)[[1]]==1)){
    invalidate_previous_data("./scratch/hw_previous_",.day,.max_number_pool_days,.mask=CASE4)
    invalidate_previous_data("./scratch/hw_previous_fullcount_",.day,.max_number_pool_days,.mask=CASE4)
    invalidate_previous_data("./scratch/i2n_previous_",.day,.max_number_pool_days,.mask=CASE4)    
    invalidate_previous_data("./scratch/i2n_previous_fullcount_",.day,.max_number_pool_days,.mask=CASE4)        
  }

  ######
  # Sixth case: previous case is !=0, pool is < MAX_NUMBER_POOL_DAYS, x is 0
  ######
  CASE5<-((x==0) & (pool_days_count > 0) & (pool_days_count<.max_number_pool_days))
  temp_pool_days_count[CASE5]<-pool_days_count+1
  if(.count_with_pools && (.layer<(.total_number_of_days-.max_number_pool_days+1))){
    temp_hw_previous_fullcount[CASE5]<-1+hw_previous_fullcount 
    temp_i2n_previous_fullcount[CASE5]<-y+i2n_previous_fullcount
  }
  
  ######
  # 7th case: 
  ######  
  CASE6<-((x==1) & (hw_previous!=0) & (pool_days_count > 0) & (pool_days_count<=.max_number_pool_days))
  temp_pool_days_count[CASE6]<-0
  temp_hw_previous[CASE6]<-x+hw_previous
  temp_i2n_previous[CASE6]<-y+i2n_previous
  temp_hw_previous_fullcount[CASE6]<-x+hw_previous_fullcount    
  temp_i2n_previous_fullcount[CASE6]<-y+i2n_previous_fullcount    

  writeRaster(temp_hw_previous,glue::glue("./scratch/hw_previous_{.day}.tif"),overwrite=TRUE,datatype="U32")
  writeRaster(temp_hw_previous_fullcount,glue::glue("./scratch/hw_previous_fullcount_{.day}.tif"),overwrite=TRUE,datatype="U32")
  writeRaster(temp_pool_days_count,glue::glue("./scratch/hw_poolcount_{.day}.tif"),overwrite=TRUE,datatype="U32")
  writeRaster(temp_i2n_previous,glue::glue("./scratch/i2n_previous_{.day}.tif"),overwrite=TRUE)
  writeRaster(temp_i2n_previous_fullcount,glue::glue("./scratch/i2n_previous_fullcount_{.day}.tif"),overwrite=TRUE)
  
  # list(hw=ifel(temp_hw_previous>=.length_hw,temp_hw_previous_fullcount,0),
  #      i2n=ifel(temp_hw_previous>=.length_hw,temp_i2n_previous_fullcount,0))
  
}