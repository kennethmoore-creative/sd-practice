# Combined Feedback in First-Order Systems — Eddie's Tree Nursery
# Road Maps 5: Beginner Modelling Exercises Section 5 (D-4593-2)
# One stock (Trees), one inflow (Planting), one outflow (Sales).
# Four examples demonstrate the four possible behaviors when positive and negative
# feedback loops coexist in a first-order system.

library(deSolve)
library(tidyverse)

START <- 0; FINISH <- 20; STEP <- 0.125   # years
simtime <- seq(START, FINISH, by = STEP)

# ---------------------------------------------------------------------------
# Example 1: Identical constant fractions -> EQUILIBRIUM
# Planting = Trees * Planting_Fraction (positive feedback)
# Sales    = Trees * Sales_Fraction    (negative feedback)
# When fractions are equal the loops perfectly cancel -> net flow = 0
# ---------------------------------------------------------------------------

model_ex1 <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    f_planting <- s_trees * p_planting_fraction   # trees/year
    f_sales    <- s_trees * p_sales_fraction      # trees/year
    ds_dt      <- f_planting - f_sales
    return(list(c(ds_dt), planting = f_planting, sales = f_sales))
  })
}

out1 <- data.frame(ode(y = c(s_trees = 500), times = simtime, func = model_ex1,
                       parms = c(p_planting_fraction = 0.08, p_sales_fraction = 0.08),
                       method = "euler")) %>%
  mutate(example = "1: Equilibrium (equal fractions 0.08 / 0.08)")

# ---------------------------------------------------------------------------
# Example 2: Planting fraction > Sales fraction -> EXPONENTIAL GROWTH
# Same structure as Example 1 but Planting_Fraction (0.30) > Sales_Fraction (0.08)
# Positive loop dominates at all times -> net flow is always positive
# ---------------------------------------------------------------------------

out2 <- data.frame(ode(y = c(s_trees = 500), times = simtime, func = model_ex1,
                       parms = c(p_planting_fraction = 0.30, p_sales_fraction = 0.08),
                       method = "euler")) %>%
  mutate(example = "2: Exponential growth (planting 0.30 > sales 0.08)")

# ---------------------------------------------------------------------------
# Example 3: Gap-driven planting + constant-fraction sales -> ASYMPTOTIC GROWTH
# Planting = Planting_Fraction * (Goal - Trees)  <- negative feedback inflow
# Sales    = Sales_Fraction * Trees              <- negative feedback outflow
# Both loops are negative, but inflow starts strong and weakens as gap closes.
# Equilibrium is BELOW the goal because outflow must be matched by inflow,
# requiring a persistent gap: equilibrium ≈ 4578 trees (goal = 5800).
# ---------------------------------------------------------------------------

model_ex3 <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    c_difference <- p_desired_trees - s_trees           # trees — gap from goal
    f_planting   <- p_planting_fraction * c_difference  # trees/year
    f_sales      <- p_sales_fraction * s_trees          # trees/year
    ds_dt        <- f_planting - f_sales
    return(list(c(ds_dt), planting = f_planting, sales = f_sales, difference = c_difference))
  })
}

out3 <- data.frame(ode(y = c(s_trees = 500), times = simtime, func = model_ex3,
                       parms = c(p_planting_fraction = 0.30,
                                 p_sales_fraction    = 0.08,
                                 p_desired_trees     = 5800),
                       method = "euler")) %>%
  mutate(example = "3: Asymptotic growth (gap-driven planting, goal = 5800)")

# ---------------------------------------------------------------------------
# Example 4: Nonlinear density multiplier on planting -> S-SHAPED GROWTH
# Planting = Planting_Fraction * Trees * Density_Multiplier(density)
# At low density: multiplier ≈ 1 -> positive loop dominates -> exponential growth
# At high density: multiplier falls sharply -> negative loop dominates -> asymptotic
# Inflection point occurs around density 0.6 trees/sq yard.
# Equilibrium: Density_Multiplier = Sales_Fraction / Planting_Fraction ≈ 0.267
#              at density ≈ 0.96 trees/sq_yard -> ~5800 trees
# ---------------------------------------------------------------------------

density_mult_x  <- c(0,   0.2, 0.4,  0.6,  0.7,  0.8,  0.9,  0.96, 1.0,  1.1,  1.2)  # trees/sq_yard
density_mult_y  <- c(1.0, 1.0, 0.98, 0.90, 0.70, 0.45, 0.30, 0.267,0.10, 0.02, 0.0)  # dimensionless
density_mult_fn <- approxfun(density_mult_x, density_mult_y, rule = 2)

model_ex4 <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    a_density         <- s_trees / p_area                             # trees/sq_yard
    a_density_mult    <- density_mult_fn(a_density)                   # dimensionless
    f_planting        <- p_planting_fraction * s_trees * a_density_mult  # trees/year
    f_sales           <- p_sales_fraction * s_trees                   # trees/year
    ds_dt             <- f_planting - f_sales
    return(list(c(ds_dt),
                planting         = f_planting,
                sales            = f_sales,
                density_multiplier = a_density_mult))
  })
}

out4 <- data.frame(ode(y = c(s_trees = 500), times = simtime, func = model_ex4,
                       parms = c(p_planting_fraction = 0.30,
                                 p_sales_fraction    = 0.08,
                                 p_area              = 6000),          # sq yards
                       method = "rk4")) %>%
  mutate(example = "4: S-shaped growth (nonlinear density multiplier)")

# ---------------------------------------------------------------------------
# Compare all four stock behaviors on one plot
# ---------------------------------------------------------------------------

bind_rows(
  out1 %>% select(time, s_trees, example),
  out2 %>% select(time, s_trees, example),
  out3 %>% select(time, s_trees, example),
  out4 %>% select(time, s_trees, example)
) %>%
  ggplot(aes(x = time, y = s_trees, colour = example)) +
  geom_line(linewidth = 0.8) +
  xlab("Years") +
  ylab("Trees") +
  labs(title  = "Combined Feedback — Eddie's Tree Nursery (four behavior modes)",
       colour = "Example")
