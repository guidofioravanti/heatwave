rm(list=objects())
library("terra")
library("tidyverse")
library("sf")


set.seed(100)

rast("hw_2003-05-01_2003-09-30.nc")->hw
rast("binary_2003-05-01_2003-09-30_cds_era5_2m_temperature_intersection_quantile90.nc")->binary
rast("i2n_2003-05-01_2003-09-30.nc")->i2n
rast("anomaly_2003-05-01_2003-09-30_cds_era5_2m_temperature_max_quantile90.nc")->tmax
rast("anomaly_2003-05-01_2003-09-30_cds_era5_2m_temperature_min_quantile90.nc")->tmin
rast("anomaly_2003-05-01_2003-09-30_cds_era5_2m_temperature_i2n_quantile90.nc")->somma


spatSample(hw,size=100,method="random",as.points=TRUE,values=FALSE,cells=TRUE)->punti

estrai<-function(.x,.punti,.values_to){
  
  terra::extract(.x,.punti,xy=TRUE,cells=TRUE,ID=FALSE) %>%
    tidyr::pivot_longer(contains("_"),values_to=.values_to) %>%
    mutate(name=as.integer(str_extract(name,"[0-9]+$"))) %>%
    dplyr::select(cell,x,y,name,everything()) %>%
    arrange(cell,name)
}

#estrai(.x=tmax,.punti=punti,.values_to="tmax")->zz


purrr::map2(.x=list(hw,binary,i2n,somma,tmax,tmin),.y=list("hw","binary","i2n","somma","tmax","tmin"),.f=~(estrai(.x=.x,.punti=punti,.values_to=.y)))->listaOut

purrr::reduce(listaOut,.f=left_join)->finale
write_delim(finale,"debug.csv",delim=";",col_names=TRUE)
st_as_sf(punti)->punti

st_write(punti,"punti","punti",driver="ESRI Shapefile",delete_layer = TRUE,delete_dsn = TRUE)
