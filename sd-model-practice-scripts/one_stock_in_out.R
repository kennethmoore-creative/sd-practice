
#One Stock, one inflow one outflow model
#System Dynamics Modelling with R, PDF pg 41


#define simulation time and step
START<-2015; FINISH<-2030; STEP<-0.25
simtime <- seq(START, FINISH, by=STEP)

#define stocks
stocks <- c(sCustomers=10000)

#define model parameters
auxs <- c(aGrowthFraction=0.08, aDeclineFraction=0.03)

#Define stock flow model
model <- function(time, stocks, auxs){
  with(as.list(c(stocks, auxs)),{
    fRecruits<-sCustomers*aGrowthFraction
    fLosses<-sCustomers*aDeclineFraction
    dC_dt <- fRecruits - fLosses
    return (list(c(dC_dt),
                 Recruits=fRecruits, Losses=fLosses,
                 GF=aGrowthFraction,DF=aDeclineFraction))
  })
}

#solve equation
o <- data.frame(ode(y=stocks, times=simtime, func = model,
                  parms=auxs, method="euler"))

#visualise results
ggplot()+
  geom_line(data=o,aes(time,o$sCustomers),colour="blue")+
  geom_point(data=o,aes(time,o$sCustomers),colour="blue")+
  scale_y_continuous()+
  ylab("Customers")+
  xlab("Year")







