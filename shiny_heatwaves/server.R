library("raster")
library("leaflet")
library("shiny")
library("leafpop")
library("tidyverse")
library("stringr")
library("sf")
library("sp")
library("ggplot2")


rnaturalearth::ne_countries()->countries
cleangeo::clgeo_Clean(countries)->countries
st_as_sf(countries)->countries
st_make_valid(countries)->countries
st_crop(countries,c(xmin=-25,xmax=45,ymin=30,ymax=73))->europe
st_union(europe)->europe
as_Spatial(europe)->europe

matriceHW<-matrix(data=c(0,3,1,
                         3,7,2,
                         7,14,3,
                         14,21,4,
                         21,28,5,
                         28,Inf,6),ncol=3,byrow=TRUE)

colorBin(palette=scico::scico(n=7,palette = "lajolla"),
         domain = c(0,100),
         na.color = "transparent",
         bins=c(0,3,7,14,21,28,Inf),
         right=TRUE)->paletta_hw

colorNumeric(palette=scico::scico(n=10,palette = "lajolla"),
         domain = c(0,30),
         na.color = "transparent")->paletta_i2n


server<-function(input,output){
  
  calendario<-reactive({ seq.Date(from = as.Date(glue::glue("{input$year}-05-01")),to=as.Date(glue::glue("{input$year}-09-30")),by="day") })
  
  reactive({
    
    brick(glue::glue("hw_{input$year}-05-01_{input$year}-09-30.nc"))->hw
    hw[hw<3]<-NA
    names(hw)<-calendario()
    
    brick(glue::glue("i2n_{input$year}-05-01_{input$year}-09-30.nc"))->i2n
    i2n[is.na(hw)]<-NA
    i2n[i2n>30]<-30
    crs(i2n)<-crs(hw)
    names(i2n)<-calendario()
    list(hw=hw,i2n=i2n)

  })->listOut
  
  
  reactive({

    if(input$variable=="Heatwave Length"){
      listOut()$hw
    }else{
      listOut()$i2n
    }

  })->mappa
  
  observeEvent(input$month,{
    
    grep(input$month,month.name)->quale
    grep(str_c(".",str_pad(quale,pad="0",side="left",width=2),"."),names(listOut()$hw))[1]->inizioMese
    updateSliderInput(inputId = "day",label = "Day",value = inizioMese)
    
  })
  

  output$map_hw<-renderLeaflet({
    
    if(input$variable=="Heatwave Length"){
    
    leaflet(options = leafletOptions(zoomControl=FALSE)) %>%
      addTiles() %>%
      setView(lng=5,lat=50,zoom=3.3) %>%
      addLegend(position="topright",
                pal= paletta_hw,
                values =c(3,7,14,21,28,Inf),
                group="legend",
                title="Heatwave Length (# of days)",
                opacity = 1) 
    
    }else{
      
      leaflet(options = leafletOptions(zoomControl=FALSE)) %>%
        addTiles() %>%
        setView(lng=5,lat=50,zoom=3.3) %>%
        addLegend(position="topright",
                  pal= paletta_i2n,
                  values =c(0,30),
                  group="legend",
                  title="Heatwave Intensity (°C)",
                  opacity = 1)  
      
    }
    
    
  })
  
  observe({
    
    if(input$mask){
      
      mask(mappa()[[input$day]],europe)->mappa_masked
      
    }else{
      
     mappa()[[input$day]]->mappa_masked      
      
   }
    
    if(input$variable=="Heatwave Length"){

    leafletProxy(mapId = "map_hw") %>%
      addTiles() %>%
      addRasterImage(mappa_masked,colors=paletta_hw,layerId="raster",group = "raster")

    }else{
      
      leafletProxy(mapId = "map_hw") %>%
        addTiles() %>%
        addRasterImage(mappa_masked,colors=paletta_i2n,layerId="raster",group = "raster") 
      
    }  
      
  })
  
  
  observeEvent(input$variable,{
    
    if(input$mask){
      
      mask(mappa()[[input$day]],europe)->mappa_masked
      
    }else{
      
      mappa()[[input$day]]->mappa_masked      
      
    }

    if(input$variable=="Heatwave Length"){
    
      leafletProxy(mapId = "map_hw") %>%
        addTiles() %>%
        removeScaleBar() %>%
        addRasterImage(mappa_masked,colors=paletta_hw,layerId="raster",group="raster")->mappa_out
      
    }else{
      
      leafletProxy(mapId = "map_hw") %>%
        addTiles() %>%
        removeScaleBar() %>%
        addRasterImage(mappa_masked,colors=paletta_i2n,layerId="raster",group = "raster")->mappa_out
      
    }
    
    if(input$rectangle){
      
      mappa_out %>%
        addRectangles(lng1=-25,lat1=30,lng2=45,lat2=73,stroke = TRUE,color = "#333333",layerId = "domain",weight = 0.5,fillColor = "#D3D3D3",fillOpacity = 0.3)
      
    }
    
    
  })
  

  observeEvent(input$rectangle,{
    
    if(input$rectangle){
      leafletProxy(mapId = "map_hw") %>%
        addRectangles(lng1=-25,lat1=30,lng2=45,lat2=73,stroke = TRUE,color = "#333333",layerId = "domain",weight = 0.5,fillColor = "#D3D3D3",fillOpacity = 0.3)
    }else{
      leafletProxy(mapId = "map_hw")  %>%
        leaflet::removeShape(layerId="domain")
    }
    
  })
  
  
  observe({
    
    click<-input$map_hw_click
    
    if(!is.null(click)){

      data.frame(x=click$lng,y=click$lat)->df
      sp::coordinates(df)=~x+y
      proj4string(df)<-CRS("+proj=longlat +datum=WGS84 +no_defs")
      #spTransform(df,CRS(mappa()))->df
      as.numeric(raster::extract(mappa()[[c((input$day-5):(input$day+5))]],df))->valori
      valori[is.na(valori)]<-0
      dfPlot<-data.frame(x=1:length(valori),y=valori)
      
      leafletProxy(mapId="map_hw") %>%
        addPopups(lng = click$lng,lat=click$lat,data = dfPlot,group="raster",popup =paste0("<p>",str_flatten(dfPlot$y,","),"</p>"))
      
    }
  })
  

  
}#fine server