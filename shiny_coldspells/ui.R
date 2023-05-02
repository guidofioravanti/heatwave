library("leaflet")
library("shinydashboard")

dashboardHeader(title = "Coldwave Tracker")->header
dashboardSidebar(disable=TRUE)->sidebar

body<-dashboardBody(
  fluidPage(id="panel1",
            tags$style(type = "text/css", "#map_hw {height: calc(100vh) !important;}"),
            absolutePanel(top="50px",left=0,right=0,bottom=0,height="auto",leafletOutput(outputId = "map_hw")),
            absolutePanel(
              top="75px",
              left="25px",
              shinyWidgets::sliderTextInput(inputId = "year",label="Year",choices = c(2006,2018,2019,2022),grid = TRUE,force_edges = TRUE),
              shinyWidgets::sliderTextInput(inputId = "month",label = "Month",choices = month.name[1:5],grid=TRUE,force_edges = TRUE),
              sliderInput(inputId = "day",label = "Day",min = 1,max = 151,value = 1,step = 1,animate = TRUE),
              shinyWidgets::radioGroupButtons(inputId = "variable",label="Select Map Layer",choices=c("Heatwave Length","Heatwave Intensity"),justified = F,size = "sm",status="danger"),
              shinyWidgets::awesomeCheckbox(inputId = "rectangle",label="Show domain",value=FALSE),
              shinyWidgets::materialSwitch(inputId = "mask",label = "Mask water bodies",status = "primary",right = TRUE)
              
              
            ),
            
  ) #fine tabsetPanel
  
)#fine dashboardBody

ui<-dashboardPage(header,sidebar,body)

