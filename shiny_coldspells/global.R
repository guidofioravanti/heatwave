guide<-cicerone::Cicerone$new()$
  step(el="year",
       title="Select Year",
       description="This shiny app shows the spatial and temporal evolution of the strongest heatwaves in Europe since 2000.")$
  step(el="month",
       title="Select Month",
       description="This web app covers the months from May to September.")$
  step(el="day",
       title="Select Day",
       description="There are 153 days in the period from May to September. Use this slider to select one day. The position of this slider is
       automatically set to the first day of the month when the month slider is used. The little arrow on the right shows an animation of the
       heatwaves.")