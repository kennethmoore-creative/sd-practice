#One Stock, net inflow 
#System Dynamics Modelling with R, Limits to growth, PDF pg 49

#set time and step
START<-0; FINISH<-100; STEP<-0.25
simtime <- seq(START, FINISH, by=STEP)

#define stocks
stocks <- c(s_stock = 100)

#define model parameters
auxs <- c(a_capacity = 10000, 
          a_ref_availability = 1,
          a_ref_growth_rate = 0.1)

#define model
model <- function(time, stocks, auxs){
  with(as.list(c(stocks, auxs)),{
    a_availability <- 1 - s_stock / a_capacity
    a_effect <- a_availability / a_ref_availability
    a_growth_rate <- a_ref_growth_rate * a_effect
    f_net_flow <- s_stock * a_growth_rate
    ds_dt <- f_net_flow
    
    return (list(c(ds_dt), 
                 net_flow = f_net_flow,
                 growth_rate = a_growth_rate, 
                 effect = a_effect,
                 availability = a_availability))
  })
}

o <- data.frame(ode(y=stocks, times=simtime, func = model,
                    parms=auxs, method="euler"))

o_long <- o %>% 
  gather(key = 'variable', value = "value", s_stock:availability)


#Visualise
ggplot()+
  geom_line(data=o_long,aes(x = time,y = o_long$value),colour="blue")+
  #geom_point(data=o,aes(time,o$sCustomers),colour="blue")+
  scale_y_continuous()+
  ylab("Customers")+
  xlab("Year")+
  facet_wrap(vars(variable), scales = "free")

