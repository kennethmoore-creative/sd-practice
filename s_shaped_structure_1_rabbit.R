# S-Shaped Growth Structure 1 — Rabbit Population with Density-Dependent Deaths
# Road Maps 5: Generic Structures — S-Shaped Growth I (D-4432-2, Section: S-Shaped Growth Structure 1)
# One stock, two flows. Positive feedback (births) initially dominates; as density rises a nonlinear
# deaths multiplier causes the negative loop to take over -> S-shaped growth.
# Replicates Exercise 1: three initial values showing all three possible behaviors.

library(deSolve)
library(tidyverse)

START <- 0; FINISH <- 12; STEP <- 0.0625   # years
simtime <- seq(START, FINISH, by = STEP)

# deaths multiplier lookup (Vensim documentation, D-4432-2)
# x = normalized population density (population_density / normal_population_density)
# y = deaths multiplier (dimensionless) — rises sharply at high densities
deaths_mult_x  <- c(0.01, 1, 2, 3,  4,   5,   6,   7,   8,   9,   10,  11,  12,  13,  14,  15,  16,  17,  18,  19,  20)
deaths_mult_y  <- c(1,    1, 1, 1,   1.5, 2,   2.7, 3.7, 4.7, 5.7, 7.5, 9,   10.5,12,  14,  17,  19,  21,  23,  24,  25)
deaths_mult_fn <- approxfun(deaths_mult_x, deaths_mult_y, rule = 2)

# parameters
params <- c(p_births_normal       = 1.5,   # 1/year
            p_average_lifetime    = 4,     # years
            p_area                = 1,     # acres
            p_normal_pop_density  = 100)   # rabbits/acre (normalisation reference)

# model
model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    a_population_density <- s_rabbit_population / p_area                                   # rabbits/acre
    a_normalized_density <- a_population_density / p_normal_pop_density                    # dimensionless
    a_deaths_multiplier  <- deaths_mult_fn(a_normalized_density)                           # dimensionless

    f_births <- s_rabbit_population * p_births_normal                                      # rabbits/year
    f_deaths <- (s_rabbit_population / p_average_lifetime) * a_deaths_multiplier           # rabbits/year

    ds_dt <- f_births - f_deaths

    return(list(c(ds_dt),
                births             = f_births,
                deaths             = f_deaths,
                population_density = a_population_density,
                deaths_multiplier  = a_deaths_multiplier))
  })
}

# three runs matching Exercise 1 (a, b, c)
run_a <- data.frame(ode(y = c(s_rabbit_population = 2),   times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "a: init = 2   (S-shaped growth)")

run_b <- data.frame(ode(y = c(s_rabbit_population = 0),   times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "b: init = 0   (trivial equilibrium)")

run_c <- data.frame(ode(y = c(s_rabbit_population = 990), times = simtime, func = model,
                        parms = params, method = "rk4")) %>%
  mutate(run = "c: init = 990 (decay to equilibrium)")

# combine and plot
bind_rows(run_a, run_b, run_c) %>%
  gather(key = "variable", value = "value", s_rabbit_population:deaths_multiplier) %>%
  ggplot(aes(x = time, y = value, colour = run)) +
  geom_line() +
  facet_wrap(vars(variable), scales = "free") +
  xlab("Years") +
  ylab("") +
  labs(title  = "S-Shaped Growth Structure 1 — Rabbit Population with Density-Dependent Deaths",
       colour = "Run")
