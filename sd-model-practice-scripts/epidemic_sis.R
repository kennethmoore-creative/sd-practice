# S-Shaped Growth Structure 2 — SIS Epidemic Model
# Road Maps 5: Generic Structures — S-Shaped Growth I (D-4432-2, Section: S-Shaped Growth Structure 2)
# Two stocks: Healthy People and Sick People. No permanent immunity — recovered people return to healthy.
# Infection rate is driven by the product of healthy and sick people (contact probability),
# creating a positive feedback loop early on, then a negative loop as healthy people are depleted.
# Replicates Exercise 2: four initial conditions showing all three possible behaviors.

library(deSolve)
library(tidyverse)

START <- 0; FINISH <- 5; STEP <- 0.125   # months
simtime <- seq(START, FINISH, by = STEP)

# parameters
params <- c(p_duration_of_illness     = 0.5,   # months
            p_population_interactions = 10,    # contacts per person per month
            p_prob_catching           = 0.5)   # probability of catching illness on contact (dimensionless)

# model
model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    a_total_population  <- s_healthy + s_sick                                              # people
    a_prob_contact_sick <- s_sick / a_total_population                                     # dimensionless

    f_catching_illness  <- s_healthy * a_prob_contact_sick *
                           p_population_interactions * p_prob_catching                     # people/month
    f_recovery_rate     <- s_sick / p_duration_of_illness                                  # people/month

    ds_healthy_dt <- f_recovery_rate - f_catching_illness
    ds_sick_dt    <- f_catching_illness - f_recovery_rate

    return(list(c(ds_healthy_dt, ds_sick_dt),
                catching_illness = f_catching_illness,
                recovery_rate    = f_recovery_rate))
  })
}

# four runs matching Exercise 2 (a–d)
run_a <- data.frame(ode(y = c(s_healthy = 90, s_sick = 10), times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "a: 10 sick, 90 healthy")

run_b <- data.frame(ode(y = c(s_healthy = 100, s_sick = 0), times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "b: 0 sick — no epidemic")

run_c <- data.frame(ode(y = c(s_healthy = 45, s_sick = 55), times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "c: 55 sick, 45 healthy")

run_d <- data.frame(ode(y = c(s_healthy = 50, s_sick = 50), times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "d: 50 sick, 50 healthy")

# combine and plot
bind_rows(run_a, run_b, run_c, run_d) %>%
  gather(key = "variable", value = "value", s_healthy:recovery_rate) %>%
  ggplot(aes(x = time, y = value, colour = run)) +
  geom_line() +
  facet_wrap(vars(variable), scales = "free") +
  xlab("Months") +
  ylab("") +
  labs(title  = "S-Shaped Growth Structure 2 — SIS Epidemic Model",
       colour = "Run")
