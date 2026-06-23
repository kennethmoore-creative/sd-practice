# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow

Do **not** automatically commit or push changes. Make file edits and stop there — the user controls all commits and pushes. Only commit or push when explicitly asked to do so in a specific instruction.

### Branching strategy

- `main` — production branch. Triggers the GitHub Pages website deployment on every push. **Never merge anything into `main` directly.** Only a deliberate website release cut (explicitly instructed by the user) should ever land on `main`.
- `dev` — integration branch. All feature branches must PR into `dev`, never into `main`. Do not create PRs or perform any merges without explicit user instruction.
- Feature branches — branch off `dev`, named `feature/<short-description>`. When creating an issue and its feature branch, always target `dev` as the PR base.

Commits on a feature branch stay on that branch until the user explicitly asks to merge or PR. Do not merge, rebase, or cherry-pick across branches without being asked.

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

## Tutorial Writing Style

- **No algebraic equilibrium derivations.** Do not include sections that work through the algebra to derive an equilibrium analytically (e.g. setting inflow = outflow and solving for the stock). The simulation and plots demonstrate the behaviour; the algebra adds length without pedagogical value in this context. Conclusion sections should stay conceptual — key structural and behavioural insights only.

## Workflow

1. **Explore** — build a plain `.R` script in the root folder to get the model working interactively
2. **Present** — once the model is solid, port it into a Quarto `.qmd` tutorial in `sd_model_examples/`

## Website (`website-tutorials/`)

The `website-tutorials/` folder is a Quarto website published to GitHub Pages at **kmooresolutions.com**. Every push to `main` triggers a GitHub Actions workflow that rebuilds and redeploys it automatically.

**Hand-crafted HTML pages (not Quarto-generated — Quarto copies them as static resources):**

- `website-tutorials/index.html` — main landing page. **Do not suggest converting to `index.qmd`** — deliberately rewritten as raw HTML for full layout control. That decision is final.
- `website-tutorials/solutions.html` — full Solutions page with four category sections: Business Solutions, Measurement & Scientific Services, Training & Advisory, Indonesia Education Solutions. Previously named `services.html` (renamed June 2026).
- `website-tutorials/contact.html` — contact form page using Formspree (endpoint `https://formspree.io/f/mdarnlve`, delivers to ken@kamiiq.com). AJAX submit with inline success/error messages.
- `website-tutorials/services-portable.html` — **NEVER commit this file.** It is a private colleague-facing copy, intentionally gitignored.

**Quarto-generated pages:**
- `website-tutorials/tutorials.qmd` — tutorials index page (linked from navbar "All Tutorials").
- `website-tutorials/_site/index.html` — built output; open in browser to preview locally.
- `website-tutorials/bio.md` — editable source for the About section bio text. Edit this file; never edit bio paragraphs directly in `index.html`.

**Navigation pattern (all hand-crafted pages must use this order):**
Solutions → Works → Learn → People → About → Contact

All four hand-crafted HTML pages (`index.html`, `solutions.html`, `contact.html`, `people.html`) include:
- Fixed navy navbar with brand + desktop links + hamburger toggle for mobile
- Desktop links hidden at 900px, replaced by hamburger menu
- Same nav order on every page

**`_quarto.yml` resources list** — every hand-crafted HTML file and the `assets/` folder must be listed under `resources:` so Quarto copies them into `_site/` without rendering them:
```yaml
resources:
  - assets/
  - solutions.html
  - contact.html
  - people.html
  - CNAME
```

**Rendering the site** — Quarto is not on the system PATH; it is bundled inside Positron. Always render via the full executable path from the project root:

```powershell
Set-Location "C:\Users\KenMoore\OneDrive - AptoNow\Documents\R\Personal\sd-practice"
& "C:\Users\KenMoore\AppData\Local\Programs\Positron\resources\app\quarto\bin\quarto.cmd" render website-tutorials
```

Output goes to `website-tutorials/_site/`. Open `_site/index.html` to preview locally.

**Bio update workflow:**

1. Edit `website-tutorials/bio.md` — plain Markdown, one blank line between paragraphs.
2. Run `Rscript splice_bio.R` from the project root — this reads `bio.md`, converts it to HTML, and writes it into `index.html` between the `<!-- BIO_START -->` and `<!-- BIO_END -->` markers. The markers remain in `index.html` after every run, so the splicer will always find them.
3. Do **not** remove or edit the `<!-- BIO_START -->` / `<!-- BIO_END -->` comment markers in `index.html` — the splicer depends on them. If they go missing the script will error.

**When adding a new `.qmd` tutorial to `website-tutorials/`, always update all three:**

1. `website-tutorials/_quarto.yml` — add a navbar entry:
   ```yaml
   - href: tut-XX-your-tutorial-name.qmd
     text: "X: Short Title"
   ```
2. `website-tutorials/tutorials.qmd` — add a row to the tutorial table:
   ```markdown
   | [X](tut-XX-your-tutorial-name.qmd) | Full Tutorial Title | Key concept |
   ```
3. `website-tutorials/index.html` — add a card to the tutorial grid (the landing page cards are hardcoded and do not auto-update):
   ```html
   <a href="tut-XX-your-tutorial-name.html" class="tutorial-card">
     <div class="tutorial-num">XX &middot; System Dynamics</div>
     <h4>Full Tutorial Title</h4>
     <p>Key concept</p>
   </a>
   ```
   Then run `Rscript splice_bio.R` and `quarto render` to push the change into `_site/`.

**Adding a logo to the clients strip (`index.html`):**

All logos in the clients strip have the CSS filter `brightness(0) invert(1)` applied, which renders them as white silhouettes on the dark navy background. This means every logo file **must have a transparent background** — a white background becomes a white box.

When a new PNG logo is added with a white background, remove it with R magick before adding the `<img>` tag:

```r
library(magick)
img <- image_read("website-tutorials/assets/logo-name.png")
img <- image_trim(img)   # remove excess whitespace/padding first
img <- image_convert(img, type = "TrueColorAlpha")
img <- image_transparent(img, "white", fuzz = 20)
image_write(img, "website-tutorials/assets/logo-name.png", format = "png")
```

After fixing the file, **always re-render** (`quarto render website-tutorials`) so the updated asset is copied into `_site/assets/`. Editing the source file alone does not update the live preview.

SVG logos are naturally transparent and do not need this treatment.

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

## SD Stock-and-Flow Diagram Style Guide

These conventions apply to all stock-and-flow diagrams drawn inline in `.qmd` tutorial chunks. Simple first-order diagrams may use the reusable helpers in `R/sd-diagram-functions.R`; complex or unique diagrams (multi-stock, oscillating, epidemic, etc.) are coded inline following this guide.

### Arrow objects (declare once per chunk, before `ggplot()`)

```r
flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")
```

### Valve position variables (declare before `ggplot()`)

Name every valve position explicitly so the flow segment, the valve circle, and all incoming info links reference the same variables:

```r
cp_valve_x <- 3.5
cp_valve_y <- 4.0
```

### Primitives

| Element | How to draw |
|---------|-------------|
| Stock | Two nested rects: outer `annotate("rect", linewidth=1.6)` + inner `annotate("rect", fill="#fafaf0", linewidth=0.5)`, inner inset 0.12 units on all sides |
| Source / sink | `geom_polygon(data = make_cloud(cx, cy), aes(x, y), ...)` |
| Flow arrow (unidirectional) | `annotate("segment", linewidth=2, colour="#4e8cd4", arrow=flow_arrow)` where `flow_arrow <- arrow(length=unit(0.44,"cm"), type="closed")` |
| Flow arrow (bi-flow) | Same segment call, but declare `flow_arrow <- arrow(ends="both", length=unit(0.44,"cm"), type="closed")`. Use `ends="both"` **if and only if** the flow can reverse direction (e.g. net flows in oscillating systems). Never add it to a unidirectional inflow or outflow. |
| Valve | `annotate("point", x=valve_x, y=valve_y, size=5, colour="#4e8cd4")` — placed **after** the flow segment so it renders on top |
| Auxiliary variable | `annotate("text", ..., fontface = "bold")` — **bold**, no ellipse. Bold distinguishes calculated values from plain parameters. |
| Parameter | `annotate("text", ...)` — plain text, no ellipse |
| Info link | `geom_curve(..., arrow=info_arrow)` — use `annotate("segment")` only when elements are so close that a curve cannot render cleanly |

### Content rules

- **Show every auxiliary and parameter** that appears in the model equations — removing ellipses frees enough canvas space to do this without clutter.
- **Info links use `geom_curve` throughout** as the default. Straight segments are the exception: use `annotate("segment")` only when elements are stacked directly above/below each other (e.g. a vertical auxiliary chain) where a curve cannot render cleanly.
- **Never draw an arrow through text.** When an info link terminates near a flow label, stop the arrowhead at the near edge of the label — not at the valve centre. If the arrow approaches from above, set `yend` to just above the label top; if from below, set `yend` to just below the label bottom. Apply the same logic for any other text the arrow path would cross.

### Single-stock S-shaped growth layout

Reference implementation: `sd-model-practice-scripts/s1_rabbit_diagram.R` and `website-tutorials/tut-05-s-shaped-growth.qmd`.

**Canvas:** `fig-width=9`, `fig-height=4.5`, `xlim=c(0,11)`, `ylim=c(0.3,5.1)`

**Horizontal flow line at `y=4`:** source cloud → inflow → stock → outflow → sink cloud.
Stock: `xmin=3.85`, `xmax=7.15`, center `(5.5, 4.0)`. Two named valve variable pairs:

```r
births_valve_x <- 2.55;  births_valve_y <- 4.0
deaths_valve_x <- 8.45;  deaths_valve_y <- 4.0
```

**Vertical auxiliary chain at `x=5.5`**, descending below the stock:

| y    | Element |
|------|---------|
| 2.75 | `population density` (bold) |
| 1.85 | `normalized density` (bold) |
| 0.95 | `deaths multiplier` (bold) |
| 0.62 | `(empirical lookup)` — italic, `colour="grey40"`, `size=2.5` |

Links along the vertical chain use `annotate("segment")` (straight), not `geom_curve`, because the elements are stacked directly above each other.

**Parameters** — plain text, positioned to avoid the chain:

| Label | Position | Info link to |
|-------|----------|--------------|
| `births normal` | `(1.5, 2.6)` | births valve — `geom_curve(curvature=-0.3)` |
| `average lifetime` | `(9.1, 2.6)` | deaths valve — `geom_curve(curvature=0.3)` |
| `area` | `(2.9, 2.15)` | population density — `geom_curve(curvature=-0.2)` |
| `normal pop density` | `(2.9, 1.3)` | normalized density — `geom_curve(curvature=-0.2)` |

**Loop labels:** R1 (+) at `(2.7, 2.9)` green; B1 (−) at `(9.3, 2.1)` red.

### Figure sizing

`fig-height` and `ylim` span must scale together. When the `ylim` range changes, scale `fig-height` proportionally to preserve element proportions:

```
new_fig_height = old_fig_height × (new_ylim_span / old_ylim_span)
```

## Variable Naming Convention (R scripts)

Prefix all variables by type so the model structure is self-documenting:

| Prefix | Type | Example |
|--------|------|---------|
| `s_` | stock | `s_inventory`, `s_employment` |
| `p_` | parameter / constant | `p_productivity`, `p_hiring_delay` |
| `c_` | converter / calculated intermediate | `c_growth_rate`, `c_inv_gap`, `c_hiring_need` |
| `f_` | flow | `f_net_flow`, `f_changing_employment` |

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

### Quarto tutorials (live at `website-tutorials/`, 8 complete)

| File | Tutorial # | Road Maps source (PDF) |
|------|-----------|----------------------|
| `tut-01-first-order-positive-feedback.qmd` | Tutorial 1 (ported from legacy .rmd) | D-4474-2, §2–3: generic structure + deer/bank/knowledge examples; specific case: deer population (stock=100, fraction=0.1/yr, 2000–2020) |
| `tut-02-first-order-positive-feedback-behavior.qmd` | Tutorial 2 (ported from legacy .rmd) | D-4474-2, §4: sensitivity analysis — varying initial stock (-200 to 200) and compounding fraction (0 to 0.4), replicating Figures 7 & 8 |
| `tut-03-first-order-negative-feedback.qmd` | Tutorial 3 (ported from legacy .rmd) | D-4475-2, §2–3: generic structure + radioactive decay / mule death / company downsizing; specific case: downsizing 20,000→12,000 employees over 7 years |
| `tut-04-closing-the-gap.qmd` | Tutorial 4 | D-4475-2, §3–4: generic negative feedback with inverted gap definition (`goal − stock`); shows exponential decay (stock above goal) and asymptotic growth (stock below goal) from the same model |
| `tut-05-s-shaped-growth.qmd` | Tutorial 5 | D-4432-2: two S-shaped growth structures — Structure 1 (rabbit population, density-dependent deaths multiplier, RK4, `approxfun` lookup); Structure 2 (SIS epidemic two-stock model, product-of-stocks infection rate) |
| `tut-06-epidemic-sis.qmd` | Tutorial 6 | D-4432-2, Structure 2: two-stock SIS epidemic in depth; four initial conditions replicating Exercise 2; equilibrium H=40 S=60 verified; no-recovery edge case |
| `tut-07-oscillation-pendulum.qmd` | Tutorial 7 | D-4935 (oscillation): second-order negative feedback producing oscillation; pendulum as canonical example; Euler vs RK4 comparison showing spurious damping at step=0.25 |
| `tut-08-damped-oscillations.qmd` | Tutorial 8 | D-4935: damped oscillation with friction parameter; sensitivity analysis across friction values; phase portrait comparison |

### Exploratory R scripts (root folder)

| File | Road Maps source |
|------|-----------------|
| `company_downsizing.R` | D-4475-2, §2.3: company downsizing — first complete negative feedback script using prefixed naming convention |
| `closing_the_gap.R` | D-4475-2: generic closing-the-gap model with inverted gap; two runs showing decay and growth |
| `s_shaped_structure_1_rabbit.R` | D-4432-2, Structure 1: rabbit population with density-dependent deaths multiplier (nonlinear lookup via `approxfun`); three initial values replicating Exercise 1 |
| `epidemic_sis.R` | D-4432-2, Structure 2: two-stock SIS epidemic model; four initial conditions replicating Exercise 2; equilibrium H=40 S=60 verified |
| `combined_feedback_trees.R` | D-4593-2: Eddie's tree nursery — all four behavior modes (equilibrium, exponential growth, asymptotic growth, S-shaped growth) in one script |

### Tutorials in the pipeline (next to build)

Road Maps PDFs on hand cover chapters 3, 4, and 5. Tutorials 1–8 exhaust the core content from those chapters. The natural next additions, pending acquisition of further Road Maps PDFs, are:

- **Tutorial 9** — Delays in depth (material vs. information delays; `SMTH1` pipeline delay; D-4197 or equivalent)
- **Tutorial 10** — Combined feedback / Eddie's trees as a full tutorial (D-4593-2: four behavior modes from one structure depending on parameter values)
- **Tutorial 11+** — Further Road Maps chapters as PDFs become available
