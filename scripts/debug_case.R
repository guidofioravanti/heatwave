rm(list=objects())
library("terra")
library("stringr")

set.seed(21)
yymmddS<-"2003-06-01"
yymmddE<-"2003-06-30"

#splits
inizio<-c(1,16,18,19,22)
fine<-c(15,17,18,21,30)

seq.Date(from=as.Date(yymmddS),to=as.Date(yymmddE),by="day")->calendar

v_hw<-rbinom(n = length(calendar),size = 1,prob = 0.5)
v_i2<-v_hw+round(runif(n=length(calendar)),1)
saveRDS(v_hw,"v_hw2.RDS")
saveRDS(v_i2,"v_i2.RDS")

nomeBinary<-"binary_2003-06-01_2003-06-30_cds_era5_2m_temperature_intersection_quantile90.nc"
nomeAnomaly<-"anomaly_2003-06-01_2003-06-30_cds_era5_2m_temperature_i2n_quantile90.nc"

creaCDF<-function(.nomeFile,.calendar,.hw){

  #str_replace(.nomeFile,"X1",as.character(.calendar[1]))->.nomeFile
  #str_replace(.nomeFile,"X2",as.character(.calendar[length(.calendar)]))->.nomeFile  
  
  rast(.nomeFile)->t2m  

  purrr::map(1:nlyr(t2m),.f=function(.lyr){

    t2m[[.lyr]]->mygrid
    
    mygrid[TRUE]<-.hw[.lyr]
    
    mygrid
    
  })->listaOut
  
  rast(listaOut) 
  
  
}#creaCDF


creaCDF(nomeBinary,.calendar = calendar,.hw=v_hw)->t2m
writeCDF(t2m,nomeBinary,overwrite=TRUE)


purrr::walk2(.x=inizio,.y=fine,.f=function(.x,.y){

  writeCDF(subset(t2m,.x:.y),filename = glue::glue("binary_{as.character(calendar[.x])}_{as.character(calendar[.y])}_cds_era5_2m_temperature_intersection_quantile90.nc"),overwrite=TRUE)

})


creaCDF(nomeAnomaly,.calendar = calendar,.hw=v_i2)->t2m
writeCDF(t2m,nomeAnomaly,overwrite=TRUE)
purrr::walk2(.x=inizio,.y=fine,.f=function(.x,.y){
  
  writeCDF(subset(t2m,.x:.y),filename = glue::glue("anomaly_{as.character(calendar[.x])}_{as.character(calendar[.y])}_cds_era5_2m_temperature_i2n_quantile90.nc"),overwrite=TRUE)
  
})




