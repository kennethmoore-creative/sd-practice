#Two Stocks, non-renewable resource
#System Dynamics Modelling with R, PDF pg 59

#set time and step
START<-0; FINISH<-200; STEP<-0.25
simtime <- seq(START, FINISH, by=STEP)

#define stocks
stocks <- c(s_capital = 5, s_resource = 1000)

#define model parameters
params <- c(p_desired_growth = 0.07,
          p_depreciation = 0.05, 
          p_cost_per_investement = 2.00,
          p_fraction_reinvested = 0.12,
          p_rev_per_unit = 3.00)

#define relationship between resource availability and extraction efficiency
x_resource <- seq(0, 1000, by = 100)
y_efficiency <- c(0, .25, .45, .63, .75, .85, .92, .96, .98, .99, 1)

func.efficiency <- approxfun(x = x_resource,
                             y = y_efficiency,
                             method = "linear",
                             yleft = 0,
                             yright = 1)
#test function
func.efficiency(100)
func.efficiency(150)


#define diffEq
model <- function(time, stocks, params){
  with(as.list(c(stocks, params)),{
    
    c_extraction_efficiency      <- func.efficiency(s_resource)
    f_extracting                 <- c_extraction_efficiency * s_capital
    
    c_total_revenue              <- f_extracting * p_rev_per_unit
    c_capital_costs              <- s_capital * 0.1
    c_profit                     <- c_total_revenue - c_capital_costs
    c_capital_funds              <- p_fraction_reinvested * c_profit
    c_max_investment             <- c_capital_funds / p_cost_per_investement
    
    c_desired_investment         <- s_capital * p_desired_growth
    
    f_investing                  <- min(c_max_investment, c_desired_investment)
    f_depreciating               <- s_capital * p_depreciation
    
    ds_dt                        <- f_investing - f_depreciating
    dr_dt                        <- -f_extracting
    
    
    return (list(c(ds_dt, dr_dt), 
                 desired_investment = c_desired_investment,
                 max_investment = c_max_investment, 
                 investing = f_investing,
                 depreciating = f_depreciating,
                 extracting = f_extracting))
  })
}

#solve
output <- data.frame(ode(
  y = stocks, times = simtime, func = model,
  parms = params, method = "euler"
))



#Visualise

#long format for faceting
output_long <- output %>% 
  gather(key = 'variable', value = "value", s_capital:extracting)

ggplot()+
  geom_line(data=output_long,aes(x = time,y = output_long$value),colour="blue")+
  #geom_point(data=o,aes(time,o$sCustomers),colour="blue")+
  scale_y_continuous()+
  ylab("Customers")+
  xlab("Year")+
  facet_wrap(vars(variable), scales = "free")

#test  
