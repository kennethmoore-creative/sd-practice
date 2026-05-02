# S-Shaped Growth — Food-Mediated Rabbit Deaths (Flow-Balance Nutrition)
# Companion to s_shaped_structure_1_rabbit.R.
#
# Structure 1 used an empirical lookup table (approxfun) to relate population
# density to a deaths multiplier.  This script replaces all empirical inputs
# with a mechanistic food sub-model: deaths rise when the food supply cannot
# keep pace with demand.
#
# Nutrition signal:
#
#   a_food_per_rabbit      = p_replenishment / s_rabbit_population
#   a_normalized_nutrition = min(a_food_per_rabbit / p_rabbitt_appetite, 1)
#
# When supply >= demand: nutrition = 1, deaths at baseline.
# When supply < demand:  nutrition < 1, effective lifespan shortens.
# The S-shape emerges because deaths grow as pop^2 in the food-scarce regime:
# as population doubles, food per rabbit halves and deaths per rabbit double.
#
# Carrying capacity derivation (births = deaths at equilibrium):
#   pop * B = pop / (L * a_norm_nutr)  =>  a_norm_nutr = 1 / (B * L) = 1/6
#   a_norm_nutr = p_replenishment / (pop * p_rabbitt_appetite)
#   pop_eq = 6 * p_replenishment / p_rabbitt_appetite = 6 * 1530/10 = 918

library(deSolve)
library(tidyverse)

START <- 0; FINISH <- 12; STEP <- 0.0625
simtime <- seq(START, FINISH, by = STEP)

params <- c(
  p_births_normal    = 1.5,    # 1/year
  p_average_lifetime = 4,      # years (baseline, when food is adequate)
  p_replenishment    = 1530,   # kg carrot/year (sustainable food supply)
  p_rabbitt_appetite  = 10      # kg carrot/rabbit/year consumed
)

model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    # food: can supply keep up with demand?
    f_carrots_eaten        <- s_rabbit_population * p_rabbitt_appetite
    a_food_per_rabbit      <- p_replenishment / max(s_rabbit_population, 0.001)
    a_normalized_nutrition <- min(a_food_per_rabbit / p_rabbitt_appetite, 1)

    f_births <- s_rabbit_population * p_births_normal
    f_deaths <- s_rabbit_population / (p_average_lifetime * a_normalized_nutrition)

    ds_rabbits_dt <- f_births - f_deaths

    return(list(
      c(ds_rabbits_dt),
      births               = f_births,
      deaths               = f_deaths,
      carrots_eaten        = f_carrots_eaten,
      normalized_nutrition = a_normalized_nutrition,
      nutritional_stress   = 1 / a_normalized_nutrition
    ))
  })
}

run_a <- data.frame(ode(
  y     = c(s_rabbit_population = 2),
  times = simtime, func = model, parms = params, method = "rk4"
)) %>% mutate(run = "a: init = 2  (S-shaped growth, K ≈ 918)")

run_a %>%
  pivot_longer(cols = -c(time, run), names_to = "variable", values_to = "value") %>%
  mutate(value = as.numeric(value), time = as.numeric(time)) %>%
  ggplot(aes(x = time, y = value)) +
  geom_line(colour = "#e07b54") +
  facet_wrap(vars(variable), scales = "free") +
  xlab("Years") +
  ylab("") +
  labs(title = "S-Shaped Growth — Food-Mediated Deaths (Flow-Balance Nutrition)")
