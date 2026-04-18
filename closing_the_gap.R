# Closing the Gap — Generic First-Order Negative Feedback
# Road Maps 4: Generic Structures — First-Order Negative Feedback (D-4475-2)
# The gap is calculated as goal minus stock, so the sign of the flow is
# self-managing: positive gap drives growth, negative gap drives decay.

library(deSolve)
library(tidyverse)

# sim time
START <- 0; FINISH <- 20; STEP <- 0.25
simtime <- seq(START, FINISH, by = STEP)

# parameters
params <- c(p_goal            = 100,   # units  — desired level of the stock
            p_adjustment_time = 2)     # time   — time constant controlling speed of closure

# model
model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    c_gap    <- p_goal - s_stock              # units       — positive: below goal; negative: above goal
    f_flow   <- c_gap / p_adjustment_time     # units/time  — net flow; sign drives growth or decay

    ds_dt <- f_flow

    return(list(c(ds_dt),
                gap  = c_gap,
                flow = f_flow))
  })
}

# two runs: stock starting below goal, and stock starting above goal
run_below <- data.frame(ode(y = c(s_stock = 50),  times = simtime, func = model,
                            parms = params, method = "euler")) %>%
  mutate(run = "below goal (stock = 50)")

run_above <- data.frame(ode(y = c(s_stock = 150), times = simtime, func = model,
                            parms = params, method = "euler")) %>%
  mutate(run = "above goal (stock = 150)")

# combine and pivot long
output_long <- bind_rows(run_below, run_above) %>%
  gather(key = "variable", value = "value", s_stock:flow)

# visualise
ggplot() +
  geom_line(data = output_long, aes(x = time, y = value, colour = run)) +
  geom_hline(yintercept = params["p_goal"], linetype = "dashed", colour = "grey50") +
  facet_wrap(vars(variable), scales = "free") +
  xlab("Time") +
  ylab("") +
  labs(title = "Closing the Gap — Generic First-Order Negative Feedback",
       colour = "Run")
