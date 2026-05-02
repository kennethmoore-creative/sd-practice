# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow

Do **not** automatically commit or push changes. Make file edits and stop there — the user controls all commits and pushes. Only commit or push when explicitly asked to do so in a specific instruction.

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

The project will grow to cover the full Road Maps curriculum progressively. PDFs currently on hand cover chapters 3, 4, and 5. New chapters will be added over time.

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

### Road Maps 5 additions
- **Delays**: material vs. information delays; `SMTH1` delay function
- **Combined feedback in first-order systems**: one stock with both a positive and negative loop — four possible behaviors: equilibrium, exponential growth, asymptotic growth, S-shaped growth. Equilibrium is found by equating inflow and outflow algebraically.
- **S-shaped growth Structure 1**: one stock, two flows; positive (birth) loop initially dominant; nonlinear density-dependent deaths multiplier causes negative loop to take over at the inflection point. Key variables: `Births_Normal`, `Average_Lifetime`, `Area`, `Deaths_Multiplier` (lookup table).
- **S-shaped growth Structure 2**: two stocks (Healthy / Sick), SIS epidemic structure (no permanent immunity); infection rate driven by product of healthy and sick stocks — `Catching_Illness = Healthy * (Sick/Total) * Population_Interactions * P_Catching`. Key insight: S-shaped growth is a **behavior**, not a structure — two mechanistically different structures can produce it.
- **Model validity**: structural, behavioral, and policy-implication tests (Shreckengost)

## Workflow

1. **Explore** — build a plain `.R` script in the root folder to get the model working interactively
2. **Present** — once the model is solid, port it into a Quarto `.qmd` tutorial in `sd_model_examples/`

## Website (`website-tutorials/`)

The `website-tutorials/` folder is a Quarto website published to GitHub Pages. Every push to `main` triggers a GitHub Actions workflow that rebuilds and redeploys it automatically.

**When adding a new `.qmd` tutorial to `website-tutorials/`, always update both:**

1. `website-tutorials/_quarto.yml` — add a navbar entry:
   ```yaml
   - href: tut-XX-your-tutorial-name.qmd
     text: "X: Short Title"
   ```
2. `website-tutorials/index.qmd` — add a row to the tutorial table:
   ```markdown
   | [X](tut-XX-your-tutorial-name.qmd) | Full Tutorial Title | Key concept |
   ```

## R function library (`R/`)

The `R/` folder is the **single source of truth** for all reusable functions used across `.qmd` tutorials and exploratory `.R` scripts. Never redefine a function inline if it already exists here.

| File | Contains |
|------|----------|
| `R/gg-helper-functions.R` | `make_cloud`, `make_ellipse` — ggplot2 shape primitives for SD diagrams |
| `R/sd-diagram-functions.R` | `draw_pos_feedback`, `draw_neg_feedback_simple` — reusable stock-and-flow diagram functions (sources `gg-helper-functions.R`) |

**Rules:**

- **To use an existing function** — source the appropriate file at the top of your script or `.qmd` setup chunk:
  ```r
  source("R/sd-diagram-functions.R")        # from a root .R script
  source("../R/sd-diagram-functions.R")     # from website-tutorials/*.qmd
  ```
- **To create a new reusable function** — add it to the relevant file in `R/` first, then source it. Never define a reusable function only inside a `.qmd` chunk or `.R` script.

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
- `method = "euler"` — linear first-order models where the flow is a constant fraction of the stock or gap (e.g. closing the gap, simple exponential growth/decay)
- `method = "rk4"` — any model with nonlinear relationships: lookup tables, products of stocks, oscillating systems. Euler evaluates the derivative only at the start of each step and can overshoot badly when the derivative itself changes rapidly (e.g. near the inflection point of S-shaped growth, or when a deaths multiplier kicks in sharply). RK4 evaluates at four points per step and tracks the curve accurately without requiring a tiny step size.

Always note the step size if it affects numerical accuracy. The existing oscillating system script has a comment illustrating this: Euler at step=0.25 produces spurious damped oscillations that are purely numerical artefacts.

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

### Nonlinear lookup tables (graph functions)
When a Road Maps model uses a graph/lookup function (e.g. deaths multiplier as a function of density), implement it with `approxfun()` **outside** the model function, then call it inside:

```r
deaths_mult_fn <- approxfun(x_values, y_values, rule = 2)
# rule = 2 clamps out-of-range inputs to the boundary value

model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    a_deaths_multiplier <- deaths_mult_fn(a_normalized_density)
    # ...
  })
}
```

### Two-stock model function signature
When there are two stocks, return two derivatives as a single concatenated vector. The order must match the order in the `stocks` named vector passed to `ode()`:

```r
stocks <- c(s_healthy = 90, s_sick = 10)

model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    # ...
    return(list(c(ds_healthy_dt, ds_sick_dt),   # order matches stocks vector
                catching_illness = f_catching_illness,
                recovery_rate    = f_recovery_rate))
  })
}
```

## Completed work and their Road Maps source

### Quarto tutorials (`sd_model_examples/`)

| File | Tutorial # | Road Maps source (PDF) |
|------|-----------|----------------------|
| `first-order-positive-feedback.rmd` | Tutorial 1 (legacy .rmd) | D-4474-2, §2–3: generic structure + deer/bank/knowledge examples; specific case: deer population (stock=100, fraction=0.1/yr, 2000–2020) |
| `first-order-positive-feedback-behavior.rmd` | Tutorial 2 (legacy .rmd) | D-4474-2, §4: sensitivity analysis — varying initial stock (-200 to 200) and compounding fraction (0 to 0.4), replicating Figures 7 & 8 |
| `first-order-negative-feedback.rmd` | Tutorial 3 (legacy .rmd) | D-4475-2, §2–3: generic structure + radioactive decay / mule death / company downsizing; specific case: downsizing 20,000→12,000 employees over 7 years |
| `closing-the-gap.qmd` | Tutorial 4 | D-4475-2, §3–4: generic negative feedback with inverted gap definition (`goal − stock`); shows exponential decay (stock above goal) and asymptotic growth (stock below goal) from the same model |

### Exploratory R scripts (root folder)

| File | Road Maps source |
|------|-----------------|
| `company_downsizing.R` | D-4475-2, §2.3: company downsizing — first complete negative feedback script using prefixed naming convention |
| `closing_the_gap.R` | D-4475-2: generic closing-the-gap model with inverted gap; two runs showing decay and growth |
| `s_shaped_structure_1_rabbit.R` | D-4432-2, Structure 1: rabbit population with density-dependent deaths multiplier (nonlinear lookup via `approxfun`); three initial values replicating Exercise 1 |
| `epidemic_sis.R` | D-4432-2, Structure 2: two-stock SIS epidemic model; four initial conditions replicating Exercise 2; equilibrium H=40 S=60 verified |
| `combined_feedback_trees.R` | D-4593-2: Eddie's tree nursery — all four behavior modes (equilibrium, exponential growth, asymptotic growth, S-shaped growth) in one script |
