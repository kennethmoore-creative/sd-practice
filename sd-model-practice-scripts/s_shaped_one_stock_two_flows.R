#One Stock, net inflow 
#System Dynamics Modelling with R, Econ Model two flows, PDF pg 56

#set time and step
START<-0; FINISH<-100; STEP<-0.25
simtime <- seq(START, FINISH, by=STEP)

#define stocks
stocks <- c(s_machines = 100)

#define model parameters
auxs <- c(c_depr_fraction = 0.1, 
          c_reinvest_fraction = 0.2,
          c_labour = 100)

model <- function(time, stocks, auxs){
  with(as.list(c(stocks, auxs)),{
    c_economic_output <- c_labour * sqrt(s_machines)
    f_investing <- c_economic_output * c_reinvest_fraction
    f_discarding <- s_machines * c_depr_fraction
    dm_dt <- f_investing - f_discarding
    
    return (list(c(dm_dt), 
                 investing = f_investing,
                 discarding = f_discarding, 
                 economic_output = c_economic_output))
  })
}

#solve
output <- data.frame(ode(
  y = stocks, times = simtime, func = model,
  parms = auxs, method = "euler"
))



#Visualise

#long format for faceting
output_long <- output %>% 
  gather(key = 'variable', value = "value", s_machines:economic_output)

ggplot()+
  geom_line(data=output_long,aes(x = time,y = output_long$value),colour="blue")+
  #geom_point(data=o,aes(time,o$sCustomers),colour="blue")+
  scale_y_continuous()+
  ylab("Customers")+
  xlab("Year")+
  facet_wrap(vars(variable), scales = "free")


