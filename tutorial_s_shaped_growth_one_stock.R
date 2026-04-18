#One Stock, one inflow 
#Simple population growth


# ------------------------------------------------------------------------------
# Set model parameters and runtime
# ------------------------------------------------------------------------------

# Time ---------------------------------

start <- 2000
finish <- 2020
increment <- 0.25

sim_time <- seq(from = start,
               to = finish,
               by = increment)

# Initial conditions and parameters ------------------

# stocks
stocks <- c(population = 20000)              # people

# parameters
params <- c(growth_rate = 0.05)              # people/(people*year)

# Model designation ---------------------------------

system_model <- function(time,
                         stocks,
                         params,
                         sim = 1){
  
  # concatenate model inputs and store as list
  model_inputs <- c(stocks, params) %>% 
    as.list()
  
  # create data environment so variable names can be accessed
  with(model_inputs,{
    
    # define flows
    pop_growing <- growth_rate * population         # people/year
    
    # stock differentials
    dp_dt <- pop_growing
    
    # results
    return(list(c(dp_dt),
                pop_inflow = pop_growing,
                sim = sim))

  })
}

# solve the ode and store in tibble
sim_data <- ode(times = sim_time, 
                y = stocks, 
                parms = params, 
                func = system_model,
                method = "euler") %>% 
  as_tibble()

# clean and reshape for ggplot
sim_data_long <- sim_data %>% 
  pivot_longer(-time) %>% 
  mutate(value = as.numeric(value),
         name = factor(name, levels = c("population", "pop_inflow")),
         date = round_date(date_decimal(time), "month"))  %>% 
  select(-time)


#Visualise
sim_data_long %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~name, scales = "free") +
  geom_line() 



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






# ------------------------------------------------------------------------------
# sensitiveity testing
# ------------------------------------------------------------------------------

ode_function <- function(sim = 1,
                         stock,
                         compounding_fraction,
                         start,
                         finish,
                         step) {

  # sim time
  sim_time <- seq(from = start,
                  to = finish,
                  by = step)
  
  # stocks
  stocks <- c(stock = stock)                   # unit
  # parameters
  params <- c(compounding_fraction = compounding_fraction)  # (unit/unit)/time
  
  
  
  system_model <- function(time,
                           stocks,
                           params,
                           sim){
    
    # concatenate model inputs and store as list
    model_inputs <- c(stocks, params) %>% 
      as.list()
    
    # create data environment so variable names can be accessed for ease of constructing the model
    with(model_inputs,{
      
      # define flow
      flow <- compounding_fraction * stock         # people/year
      
      # stock differential to integrate
      ds_dt <- flow
      
      # results... when we solve this ODE below,
      return(list(c(ds_dt),
                  change_in_stock = flow,
                  sim = sim))
      
    })
  }
  
  # get data
  sim_data <- ode(times = sim_time, 
                  y = stocks, 
                  parms = params, 
                  func = system_model,
                  method = "euler",
                  sim = sim) %>%
    # keep things tidy as a tibble
    as_tibble()
  
  return(sim_data)
}

# --------------- iterate the ode_funtion ------------

# stocks
stocks_list <- c(-200, -100, 0, 100, 200)

# sim runs
sim_runs <- seq_along(stocks_list)

# map
sim_results <- pmap_dfr(list(sim = sim_runs,
                             stock = stocks_list),
                        .f = ode_function,
                        compounding_fraction = 0.05,
                        start = 0,
                        finish = 50,
                        step = 0.25)

