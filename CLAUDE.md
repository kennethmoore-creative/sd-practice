# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An R project for building statistical/structural dynamics (sd) models from scratch. Uses RStudio (`.Rproj` configured with 2-space indentation, UTF-8 encoding).

## Common Commands

Run R scripts from the terminal:
```bash
Rscript path/to/script.R
```

Launch an interactive R session:
```bash
R
```

Run a specific function or expression inline:
```bash
Rscript -e "source('path/to/script.R')"
```

## Project Conventions

- 2 spaces for indentation (per `.Rproj` settings)
- UTF-8 encoding throughout
- `.RData`, `.Rhistory`, and `.Renviron` are gitignored — do not commit session state or environment variables
- New tutorials are written in **Quarto** (`.qmd`), not R Markdown (`.rmd`). Existing `.rmd` files are legacy.

## Road Maps Curriculum Context

This project replicates examples from the **MIT System Dynamics in Education Project** Road Maps series (supervised by Jay W. Forrester). The PDFs in `RoadMaps Reference/` are the source material. Original models used STELLA/Vensim/DYNAMO — we implement equivalent models in R.

The project will grow to cover the full Road Maps curriculum progressively. PDFs currently on hand cover chapters 3 and 4, but new chapters will be added over time.

### Core modeling pattern (Euler integration)

All SD models use discrete-time Euler integration:

```r
stock[i+1] <- stock[i] + net_flow[i] * dt
```

### Generic Structure: First-Order Positive Feedback

Produces **exponential growth** (or decay if stock starts negative).

```
flow = stock * compounding_fraction
  OR
flow = stock / time_constant
```

- `time_constant = 1 / compounding_fraction`
- Doubling time ≈ `0.7 * time_constant`
- Examples: population-birth, bank balance-interest, knowledge-learning

### Generic Structure: First-Order Negative Feedback

Produces **goal-seeking / exponential decay**.

```
adjustment_gap = stock - goal
flow = adjustment_gap * draining_fraction   # outflow
  OR
flow = adjustment_gap / time_constant       # outflow
```

- `time_constant = 1 / draining_fraction`
- Halving time ≈ `0.7 * time_constant`
- Goal defaults to 0 in simplest cases (radioactive decay, population death)
- Explicit goal used in systems like company downsizing
- Examples: radioactive decay, mule population death, company downsizing, package deliveries

### Road Maps 4 additions
- **Section 4**: Positive feedback with a constant outflow; negative feedback with a constant inflow
- **Fish Banks**: Two-stock renewable resource depletion model (tragedy of the commons)
- **Problems with causal loop diagrams**: Why stock-and-flow diagrams are more rigorous

## Workflow

1. **Explore** — build a plain `.R` script in the root folder to get the model working interactively
2. **Present** — once the model is solid, port it into a Quarto `.qmd` tutorial in `sd_model_examples/`

## Variable Naming Convention (R scripts)

Prefix all variables by type so the model structure is self-documenting:

| Prefix | Type | Example |
|--------|------|---------|
| `s_` | stock | `s_inventory`, `s_employment` |
| `p_` | parameter / constant | `p_productivity`, `p_hiring_delay` |
| `a_` | auxiliary / converter | `a_availability`, `a_growth_rate` |
| `f_` | flow | `f_net_flow`, `f_changing_employment` |
| `c_` | calculated intermediate | `c_inv_gap`, `c_hiring_need` |

## Integration Method

Choose based on model complexity:
- `method = "euler"` — simple first-order models
- `method = "rk4"` — oscillating or higher-order systems (Euler can produce spurious damping at larger step sizes)

Always note the step size if it affects numerical accuracy.

## R Implementation Patterns

These patterns are established across the existing `.rmd` tutorials and should be followed consistently.

### Core stack
- `deSolve` — ODE solver (Euler method)
- `tidyverse` — data wrangling and ggplot2 visualization
- `lubridate` — convert decimal-year time indices to real calendar dates
- `purrr` — multi-simulation sensitivity runs via `pmap_dfr()`
- `janitor` — `clean_names()` after pivoting for tidy column names

### Model function signature
Every model is a function with this signature, as required by `deSolve::ode()`:

```r
system_model <- function(time, stocks, params, sim = 1) {
  with(as.list(c(stocks, params)), {
    # ... equations ...
    return(list(c(ds_dt), change_in_stock = flow, sim = sim))
  })
}
```

`with(as.list(c(stocks, params)), {...})` is the standard idiom to expose variable names directly.

### Solving and tidying
```r
sim_data <- ode(times = sim_time, y = stocks, parms = params,
                func = system_model, method = "euler") %>%
  as_tibble() %>%
  relocate(sim, .before = time) %>%
  pivot_longer(-c(sim:time)) %>%
  mutate(value = as.numeric(value), time = as.numeric(time))
```

### Multi-simulation sensitivity tests (Tutorial 2 pattern)
Wrap the whole model in one function accepting all parameters as arguments, then use `pmap_dfr()` to iterate over parameter lists and bind results by rows for comparative plotting:

```r
pmap_dfr(list(sim = sim_runs, stock = stocks_list),
         .f = my_model_fn,
         compounding_fraction = 0.1, ...)
```

### Real calendar dates
When a simulation runs over calendar years (e.g. 2015–2022), use `lubridate`:

```r
date = round_date(date_decimal(time), "month")
```

## Completed tutorials and their Road Maps source

| File | Tutorial # | Road Maps source (PDF) |
|------|-----------|----------------------|
| `first-order-positive-feedback.rmd` | Tutorial 1 | D-4474-2, §2–3: generic structure + deer/bank/knowledge examples; specific case: deer population (stock=100, fraction=0.1/yr, 2000–2020) |
| `first-order-positive-feedback-behavior.rmd` | Tutorial 2 | D-4474-2, §4: sensitivity analysis — varying initial stock (-200 to 200) and compounding fraction (0 to 0.4), replicating Figures 7 & 8 |
| `first-order-negative-feedback.rmd` | Tutorial 3 | D-4475-2, §2–3: generic structure + radioactive decay / mule death / company downsizing; specific case: downsizing 20,000→12,000 employees over 7 years |
