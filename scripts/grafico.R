rm(list=objects())
library("terra")
library("rnaturalearth")
library("sf")
library("dplyr")
library("tidyterra")
library("scico")
library("ggplot2")

XMIN=-20
XMAX=40
YMIN=25
YMAX=80


rnaturalearth::ne_countries(continent="Europe")->europe
rnaturalearth::ne_countries(continent="Africa")->africa
cleangeo::clgeo_Clean(europe)->europe
cleangeo::clgeo_Clean(africa)->africa
st_as_sf(africa)->africa
st_make_valid(africa)->africa
st_as_sf(europe)->europe
st_make_valid(europe)->europe
st_union(africa,europe)->countries

st_union(countries)->countries
st_crop(st_geometry(countries),c(xmin=XMIN,xmax=XMAX,ymin=YMIN,ymax=YMAX))->countries
terra::vect(countries)->vcountries

fixRaster<-function(x){
  
  terra::flip(x,direction="v")->x
  
  as.data.frame(x,xy=TRUE) %>%
    mutate(x=ifelse(x>180,x-360,x))->df
  
  names(df)<-c("x","y","z")
  
  rast(as.matrix(df),type="xyz")->y
  crs(y)<-"epsg:4326"
  
  return(y)
  
}


rast("hw_2003-07-01_2003-08-31.nc")->mybrick
purrr::map(1:nlyr(mybrick),.f=~(fixRaster(mybrick[[.]]))) %>%
  rast()->mybrick

names(mybrick)<-seq.Date(from=as.Date("2003-07-01"),to=as.Date("2003-08-31"),by="day")
#mask(mybrick,vcountries)->mybrick
ifel(subset(mybrick,32:48)<1,NA,subset(mybrick,12:29))->zz
#ifel(mybrick<1,NA,mybrick)->zz

ggplot()+
  tidyterra::geom_spatraster(data=zz)+
  tidyterra::geom_spatvector(data=vcountries,fill="transparent")+
  scale_fill_scico(na.value="transparent",palette="lajolla")+
  facet_wrap(~lyr)+
  scale_x_continuous(limits = c(XMIN-1,XMAX+1),expand = c(0.0,0.0))+
  scale_y_continuous(limits = c(YMIN-1,YMAX+1),expand = c(0.0,0.0))+
  theme_bw()+
  theme(panel.grid = element_blank(),
        axis.text = element_blank(),
        axis.ticks = element_blank())->grafico


print(grafico)






