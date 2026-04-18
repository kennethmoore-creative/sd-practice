#Oscillating Systems
#Roadmaps no. 6, Appendix 3


START <- 0 ; FINISH <- 100 ; STEP <- 0.25 # 0.25 will cause damped oscillations 
# because it can't integrate at the exact endpoints
simtime <- seq(START, FINISH, by=STEP)

#define stocks
stocks <- c(s_inventory = 25000,                #widgets
            s_employment = 200)                 #people

#define model parameters
params <- c(p_productivity = 100,               #widgets/(person*year)
            p_hiring_delay = 0.25,              #years
            p_time_close_inv_gap = 0.5,         #years
            p_desired_inventory = 20000,        #widgets
            p_sales_contract = 20000)           #widgets/year     

model <- function(time, stocks, params){
  with(as.list(c(stocks, params)),{
    
    c_inv_gap                    <- p_desired_inventory - s_inventory               #widgets
    C_production_to_close_gap    <- c_inv_gap/p_time_close_inv_gap                  #widgets/year
    c_hiring_need                <- C_production_to_close_gap/p_productivity        #people
    
    f_changing_employment        <- c_hiring_need/p_hiring_delay                    #people/year
    f_changing_inventory         <- (p_productivity*s_employment)-p_sales_contract  #widgets/year
    
    dE_dt                        <- f_changing_employment
    dI_dt                        <- f_changing_inventory
    
    
    return (list(c(dI_dt, dE_dt), 
                 inventory_gap = c_inv_gap,
                 production_to_close_gap = C_production_to_close_gap, 
                 hiring_need = c_hiring_need,
                 changing_employment = f_changing_employment,
                 changing_inventory = f_changing_inventory))
  })
}

#solve
output <- data.frame(ode(
  y = stocks, times = simtime, func = model,
  parms = params, method = "rk4"
))

#long format for faceting
output_long <- output %>% 
  gather(key = 'variable', value = "value", s_inventory:changing_inventory)

ggplot()+
  geom_line(data=output_long,aes(x = time,y = output_long$value),colour="blue")+
  #geom_point(data=o,aes(time,o$sCustomers),colour="blue")+
  scale_y_continuous()+
  ylab("Customers")+
  xlab("Year")+
  facet_wrap(vars(variable), scales = "free")

