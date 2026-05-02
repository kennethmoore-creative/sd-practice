# ------------------------------------------------------------------------------
# Pendulum model
# RM_6_Generic+Structures+in+Oscillating+Systems.pdf Appendix 2
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Set model parameters and runtime
# ------------------------------------------------------------------------------

# Time ---------------------------------

start <- 0
finish <- 10
increment <- 0.001 # increment must be very small, or the oscillations will dampen

sim_time <- seq(from = start,
                to = finish,
                by = increment)

# Initial conditions and parameters ------------------

# stocks
stocks <- c(position = 0.15,             # horizontal displacement in meters
            velocity = 0)                # m/s      

# parameters
params <- c(desired_position = 0,        # horizontal equilibrium
            gravity = 9.8,               # m/s^2 
            length_of_pendulum = 1)                   

# Model designation ---------------------------------

system_model <- function(time,
                         stocks,
                         params){
  
  # concatenate model inputs and store as list
  model_inputs <- c(stocks, params) %>% 
    as.list()
  
  # create data environment so variable names can be accessed
  with(model_inputs,{
    
    # variables
    gap <- desired_position - position
    
    # define flows
    changing_position <- velocity                            # m/s
    changing_velocity <- (gravity/length_of_pendulum)*gap    # m/s^2
    
    # stock differentials
    dp_dt <- changing_position
    dv_dt <- changing_velocity
    
    # results
    return(list(c(dp_dt, dv_dt),
                acceleration = changing_velocity,
                gap = gap))
    
  })
}

# solve the ode and store in tibble
sim_data <- ode(times = sim_time, 
                y = stocks, 
                parms = params, 
                func = system_model,
                method = "rk4") %>% 
  as_tibble()

# clean and reshape for ggplot
sim_data_long <- sim_data %>% 
  pivot_longer(-time) %>% 
  mutate(value = as.numeric(value),
         time = as.numeric(time),
         name = factor(name, levels = c("position", "velicity", "gap", "acceleration")),
         date = round_date(date_decimal(time), "month"))


#Visualise
sim_data_long %>% 
  ggplot(aes(x = time, y = value)) +
  facet_wrap(~name, scales = "free") +
  geom_line() 



