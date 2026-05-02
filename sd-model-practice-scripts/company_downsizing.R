# Company Downsizing System
# Road Maps 4: Generic Structures — First-Order Negative Feedback (D-4475-2, Section 2.3)

library(deSolve)
library(tidyverse)

# sim time
START <- 0; FINISH <- 14; STEP <- 0.25   # years
simtime <- seq(START, FINISH, by = STEP)

# stocks
stocks <- c(s_employees = 20000)          # people

# parameters
params <- c(p_desired_employees = 12000,  # people
            p_adjustment_time = 2)        # years (time constant)

# model
model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    c_distance_to_goal <- s_employees - p_desired_employees   # people
    f_firing_rate      <- c_distance_to_goal / p_adjustment_time  # people/year

    ds_dt <- -f_firing_rate  # make sure it's negative to specify "draining"

    return(list(c(ds_dt),
                distance_to_goal = c_distance_to_goal,
                firing_rate      = f_firing_rate))
  })
}

# solve
output <- data.frame(ode(y = stocks, times = simtime, func = model,
                         parms = params, method = "euler"))

# long format for faceting
output_long <- output %>%
  gather(key = "variable", value = "value", s_employees:firing_rate)

# visualise
ggplot() +
  geom_line(data = output_long, aes(x = time, y = value), colour = "blue") +
  facet_wrap(vars(variable), scales = "free") +
  xlab("Year") +
  ylab("") +
  labs(title = "Company Downsizing — First-Order Negative Feedback")
