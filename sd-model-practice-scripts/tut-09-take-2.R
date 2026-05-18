library(tidyverse)
library(deSolve)

# ── Scenario ──────────────────────────────────────────────────────────────────
#
# A technology company has undergone a round of redundancies, reducing
# headcount from 200 to 150. At the start of the observation period, 11 staff
# are already on reduced capacity due to burnout — a pre-existing condition
# made worse by the layoffs. As workload pressure mounts on the remaining team,
# burnout begins to spread.
#
# Two feedback loops drive the system:
#
#   R1 (+): Burnt-out staff reduce team capacity → remaining healthy staff
#           absorb extra workload → higher stress → more staff burn out
#
#   B1 (−): Rising burnout count → management deploys support measures
#           (contractors, reduced scope, wellness programmes) →
#           shorter effective recovery time → staff return to capacity
#
# The problem in this data:
#   - B1 kicks in too late  (management escalates only when > 32 staff affected)
#   - The resulting equilibrium is too high (~ 50 staff; target is < 25)
#
# Organisational levers:
#   (a) WHEN to trigger the support response  → B1 intervention threshold
#   (b) HOW QUICKLY support is deployed       → effective recovery time
#
# ─────────────────────────────────────────────────────────────────────────────


# ------------------------------------------------------------------------------
# SECTION 1: load and explore the data
# ------------------------------------------------------------------------------

# ── Step 1: Raw data (wide format — as received from HR system / Excel export)─
#
# Monthly count of staff recorded as working at reduced capacity due to burnout.
# Figures are rounded to the nearest whole number.

wide_data <- tribble(
  ~period,   ~burnt_out_staff,
  "Jan-23",  11,
  "Feb-23",  12,
  "Mar-23",  12,
  "Apr-23",  11,
  "May-23",  15,
  "Jun-23",  14,
  "Jul-23",  14,
  "Aug-23",  16,
  "Sep-23",  19,
  "Oct-23",  21,
  "Nov-23",  17,
  "Dec-23",  27,
  "Jan-24",  30,
  "Feb-24",  35,
  "Mar-24",  39,
  "Apr-24",  43,
  "May-24",  42,
  "Jun-24",  48,
  "Jul-24",  47,
  "Aug-24",  50,
  "Sep-24",  51,
  "Oct-24",  51,
  "Nov-24",  48,
  "Dec-24",  50
)

print(wide_data)

# ── Step 2: Reshape to tidy format ────────────────────────────────────────────

tidy_data <- wide_data |>
  mutate(date = as.Date(paste0("01-", period), format = "%d-%b-%y")) |>
  arrange(date) |>
  mutate(t = row_number())

# ── Step 3: Plot ──────────────────────────────────────────────────────────────

ggplot(tidy_data, aes(x = date, y = burnt_out_staff)) +
  geom_line(linewidth = 0.8, colour = "#619CFF") +
  geom_point(size = 1.8, colour = "#619CFF") +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 65)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Post-Redundancy Trend (2023–2024)",
    subtitle = "S-shaped growth: stress spreads faster than management responds; equilibrium far above target",
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

# ── Step 4: Linear regression baseline ────────────────────────────────────────

lm_fit  <- glm(burnt_out_staff ~ t, data = tidy_data, family = gaussian)
r_sq_lm <- 1 - lm_fit$deviance / lm_fit$null.deviance

lm_fitted_curve <- tibble(
  date   = seq(min(tidy_data$date), max(tidy_data$date), length.out = 200),
  fitted = predict(lm_fit,
                   newdata = tibble(t = seq(1, max(tidy_data$t), length.out = 200)))
)

ggplot() +
  geom_line(data  = tidy_data,
            aes(x = date, y = burnt_out_staff),
            linewidth = 0.6, colour = "#619CFF", alpha = 0.5) +
  geom_point(data = tidy_data,
             aes(x = date, y = burnt_out_staff),
             size = 1.5, colour = "#619CFF", alpha = 0.5) +
  geom_line(data  = lm_fitted_curve,
            aes(x = date, y = fitted),
            linewidth = 1.2, colour = "#619CFF") +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 27,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 65)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Linear Model Fit",
    subtitle = paste0("Gaussian GLM  |  R² = ", round(r_sq_lm, 3)),
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 2: fit a logistic curve using binomial GLM
# ------------------------------------------------------------------------------

# ── Handling a non-zero lower asymptote ───────────────────────────────────────
# The burnout count does not start near zero — 11 staff were already affected
# at the start of observation. The logistic curve therefore has a non-zero
# lower asymptote (L ≈ 11). The rescaling must account for both ends:
#
#   1. Estimate L as the minimum observed value.
#   2. Estimate K as the average of the top 5 observed values.
#   3. Rescale: y_scaled = (y − L) / (K − L), mapping the data to [0, 1].
#   4. Fit binomial GLM on the rescaled data.
#   5. Reverse-scale: y_fitted = L + plogis(b0 + b1*t) × (K − L).
#
# r and t0 are unchanged by this rescaling; only the amplitude is normalised.

N <- 1000

y     <- tidy_data$burnt_out_staff
t_seq <- tidy_data$t

K_hat <- mean(sort(y, decreasing = TRUE)[1:5])
L_hat <- min(y)

y_scaled <- pmin((y - L_hat) / (K_hat - L_hat), 0.9999)

fit <- glm(
  cbind(round(y_scaled * N), round((1 - y_scaled) * N)) ~ t_seq,
  family = binomial(link = "logit")
)

b0 <- coef(fit)[["(Intercept)"]]
b1 <- coef(fit)[["t_seq"]]

r_fit  <- b1
t0_fit <- -b0 / b1

tibble(
  parameter = c("K (estimated)", "L — lower asymptote", "r (fitted)", "t0 (fitted)"),
  value     = c(round(K_hat, 1), round(L_hat, 1), round(r_fit, 3), round(t0_fit, 1))
) |> print()

# R² comparison — both computed in original y-units (correlation of fitted vs observed)
r_sq_glm <- cor(y, L_hat + plogis(b0 + b1 * t_seq) * (K_hat - L_hat))^2

tibble(
  model     = c("Linear (gaussian GLM)", "Logistic (binomial GLM)"),
  r_squared = round(c(r_sq_lm, r_sq_glm), 3)
) |> print()

t_fine   <- seq(1, max(t_seq), length.out = 200)
y_fitted <- L_hat + plogis(b0 + b1 * t_fine) * (K_hat - L_hat)

fitted_curve <- tibble(
  date   = seq(min(tidy_data$date), max(tidy_data$date), length.out = 200),
  fitted = y_fitted
)

ggplot() +
  geom_line(data  = tidy_data,
            aes(x = date, y = burnt_out_staff),
            linewidth = 0.6, colour = "#619CFF", alpha = 0.5) +
  geom_point(data = tidy_data,
             aes(x = date, y = burnt_out_staff),
             size = 1.5, colour = "#619CFF", alpha = 0.5) +
  geom_line(data  = fitted_curve,
            aes(x = date, y = fitted),
            linewidth = 1.2, colour = "#619CFF") +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 65)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Fitted Logistic Curve",
    subtitle = "Faint: observed data  |  Solid: rescaled-binomial GLM fit",
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 3: SD model with policy and operational levers
# ------------------------------------------------------------------------------

# ── Structure ─────────────────────────────────────────────────────────────────
#
# One stock: s_burnt_out_staff
#
#   f_burning_out  [R1, +]
#     Stress contagion: each burnt-out person reduces team capacity, loading
#     extra pressure onto healthy colleagues and accelerating further burnout.
#
#   f_recovery     [B1, −]
#     Management support: once the count exceeds the intervention threshold,
#     leadership brings in additional resource — shortening the effective
#     recovery window. Mirrors c_policy_effectiveness from tut-09-outline.
#
# ── Implied equilibrium ───────────────────────────────────────────────────────
#   K = p_intervention_threshold × p_spread_rate × p_recovery_months
#
# ── Levers ────────────────────────────────────────────────────────────────────
#   p_intervention_threshold  — staff count that triggers escalated support
#   p_recovery_months         — baseline months to return to capacity

model_burnout <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    c_intervention_effectiveness <- min(
      p_intervention_threshold / max(s_burnt_out_staff, 0.001), 1
    )

    # R1: stress contagion spreads burnout through the team
    f_burning_out <- s_burnt_out_staff * p_spread_rate

    # B1: management support; effective recovery window contracts above threshold
    f_recovery <- s_burnt_out_staff /
      (p_recovery_months * c_intervention_effectiveness)

    ds_burnt_out_staff_dt <- f_burning_out - f_recovery

    return(list(
      c(ds_burnt_out_staff_dt),
      burning_out                = f_burning_out,
      recovery                   = f_recovery,
      intervention_effectiveness = c_intervention_effectiveness
    ))
  })
}

# ── Scenarios ─────────────────────────────────────────────────────────────────
# Implied K = p_intervention_threshold × p_spread_rate × p_recovery_months

scenarios <- list(
  `Current policy`  = c(p_spread_rate = 0.30, p_recovery_months = 5.2, p_intervention_threshold = 32),
  `Earlier trigger` = c(p_spread_rate = 0.30, p_recovery_months = 5.2, p_intervention_threshold = 20),
  `Faster response` = c(p_spread_rate = 0.30, p_recovery_months = 4.0, p_intervention_threshold = 32),
  `Both levers`     = c(p_spread_rate = 0.30, p_recovery_months = 4.0, p_intervention_threshold = 20)
)

stocks      <- c(s_burnt_out_staff = 11)
sim_time    <- seq(1, 24, by = 0.1)
origin_date <- as.Date("2023-01-01")

sim_results <- imap_dfr(scenarios, function(params, label) {
  ode(y = stocks, times = sim_time, func = model_burnout,
      parms = params, method = "rk4") |>
    as_tibble() |>
    transmute(
      scenario        = label,
      time            = as.numeric(time),
      date            = origin_date + (time - 1) * 30.44,
      burnt_out_staff = as.numeric(s_burnt_out_staff)
    )
}) |>
  mutate(scenario = factor(scenario, levels = names(scenarios)))

sim_results |>
  group_by(scenario) |>
  filter(time == max(time)) |>
  transmute(scenario, equilibrium_count = round(burnt_out_staff, 1)) |>
  print()

ggplot(sim_results, aes(x = date, y = burnt_out_staff, colour = scenario)) +
  geom_line(linewidth = 0.9) +
  geom_point(
    data = tidy_data,
    aes(x = date, y = burnt_out_staff),
    colour = "grey50", size = 1.5, alpha = 0.7, inherit.aes = FALSE
  ) +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = origin_date, y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 65)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  scale_colour_manual(values = c(
    "Current policy"  = "#E74C3C",
    "Earlier trigger" = "#F39C12",
    "Faster response" = "#3498DB",
    "Both levers"     = "#27AE60"
  )) +
  labs(
    title    = "Staff Burnout — Policy Scenarios",
    subtitle = "Grey points: observed data  |  Lines: SD model under each policy",
    x        = NULL,
    y        = "Staff on reduced capacity (count)",
    colour   = "Policy scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )

# ── Equilibrium by scenario ───────────────────────────────────────────────────
#
#   Scenario          K (implied)   Equilibrium (simulated)
#   ──────────────────────────────────────────────────────────────────────
#   Current policy      49.9            ~ 49       above target
#   Earlier trigger     31.2            ~ 31       above target
#   Faster response     38.4            ~ 38       above target
#   Both levers         24.0            ~ 24       below target of 25 ✓
#
# Note on the "Faster response" lever: p_recovery_months cannot be reduced
# below 1/p_spread_rate (= 3.33 months) without making the net flow negative
# even below the intervention threshold — the spread rate must dominate
# naturally for the S-curve to form. Reducing from 5.2 → 4.0 months
# represents realistic organisational improvements (better occupational
# health support, flexible working), not unlimited reduction.
#
# Neither single lever reaches the target of 25. Only pulling both together
# brings the equilibrium below it, demonstrating that the burnout trajectory
# is a structural problem encoded in how late and how weakly the organisation
# responds — not an unavoidable consequence of the redundancies.


# ── Stock-and-flow diagram ────────────────────────────────────────────────────

make_cloud <- function(cx, cy, w = 0.45, h = 0.28) {
  theta <- seq(0, 2 * pi, length.out = 200)
  bump  <- 1 + 0.12 * sin(8 * theta)
  tibble(x = cx + w * bump * cos(theta), y = cy + h * bump * sin(theta))
}

flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")

burning_valve_x <- 2.55
burning_valve_y <- 4.0
recovery_valve_x  <- 8.45
recovery_valve_y  <- 4.0

ggplot() +
  # Source cloud
  geom_polygon(data = make_cloud(0.75, burning_valve_y), aes(x, y),
               fill = "white", colour = "black", linewidth = 0.7) +
  # Burning out — inflow (R1)
  annotate("segment", x = 1.2, xend = 3.85,
           y = burning_valve_y, yend = burning_valve_y,
           linewidth = 2, colour = "#4e8cd4", arrow = flow_arrow) +
  annotate("point", x = burning_valve_x, y = burning_valve_y,
           size = 5, colour = "#4e8cd4") +
  annotate("text", x = burning_valve_x, y = 4.44,
           label = "burning\nout", size = 3.2, colour = "#4e8cd4",
           lineheight = 0.9) +
  # Stock
  annotate("rect", xmin = 3.85, xmax = 7.15, ymin = 3.45, ymax = 4.55,
           fill = "white", colour = "black", linewidth = 1.6) +
  annotate("rect", xmin = 3.97, xmax = 7.03, ymin = 3.57, ymax = 4.43,
           fill = "#fafaf0", colour = "black", linewidth = 0.5) +
  annotate("text", x = 5.5, y = 4.0, label = "burnt-out\nstaff",
           size = 3.2, fontface = "bold", lineheight = 0.9) +
  # Recovery — outflow (B1)
  annotate("segment", x = 7.15, xend = 9.8,
           y = recovery_valve_y, yend = recovery_valve_y,
           linewidth = 2, colour = "#d45b4e", arrow = flow_arrow) +
  annotate("point", x = recovery_valve_x, y = recovery_valve_y,
           size = 5, colour = "#d45b4e") +
  annotate("text", x = recovery_valve_x, y = 4.44,
           label = "recovery", size = 3.2, colour = "#d45b4e",
           lineheight = 0.9) +
  # Sink cloud
  geom_polygon(data = make_cloud(10.25, recovery_valve_y), aes(x, y),
               fill = "white", colour = "black", linewidth = 0.7) +

  # Auxiliary chain (bold — calculated converters)
  annotate("text", x = 5.5, y = 2.75, label = "burnout\nratio",
           size = 3.0, fontface = "bold", lineheight = 0.9) +
  annotate("text", x = 5.5, y = 1.85, label = "intervention\neffectiveness",
           size = 3.0, fontface = "bold", lineheight = 0.9) +

  # Parameters (plain text)
  annotate("text", x = 1.5,  y = 2.6,  label = "spread\nrate",
           size = 3.0, lineheight = 0.9) +
  annotate("text", x = 9.1,  y = 2.6,  label = "recovery\nmonths",
           size = 3.0, lineheight = 0.9) +
  annotate("text", x = 2.9,  y = 2.75, label = "intervention\nthreshold",
           size = 3.0, lineheight = 0.9) +

  # Info: vertical chain — stock ↓ burnout ratio ↓ intervention effectiveness
  annotate("segment", x = 5.5, xend = 5.5, y = 3.45, yend = 2.98,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +
  annotate("segment", x = 5.5, xend = 5.5, y = 2.52, yend = 2.08,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +

  # Info: intervention threshold → burnout ratio
  geom_curve(
    data = data.frame(x = 3.35, y = 2.75, xend = 4.72, yend = 2.75),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.2, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: intervention effectiveness → recovery valve (B1)
  geom_curve(
    data = data.frame(x = 6.3, y = 1.85,
                      xend = recovery_valve_x, yend = recovery_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = 0.25, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: stock → burning-out valve (R1 reinforcing loop)
  geom_curve(
    data = data.frame(x = 4.5, y = 3.45,
                      xend = 2.1, yend = burning_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.38, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: spread rate → burning-out valve
  geom_curve(
    data = data.frame(x = 1.9, y = 2.6,
                      xend = burning_valve_x - 0.1, yend = burning_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.3, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: recovery months → recovery valve
  geom_curve(
    data = data.frame(x = 8.8, y = 2.6,
                      xend = recovery_valve_x + 0.1, yend = recovery_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = 0.3, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +

  # Loop labels
  annotate("text", x = 2.7, y = 2.9, label = "R1  (+)", size = 3.8,
           colour = "#27ae60", fontface = "bold") +
  annotate("text", x = 9.3, y = 2.1, label = "B1  (−)", size = 3.8,
           colour = "#c0392b", fontface = "bold") +
  theme_void() +
  coord_cartesian(xlim = c(0, 11), ylim = c(0.5, 5.1)) +
  labs(title = "Staff Burnout S-Curve — stock-and-flow diagram")
