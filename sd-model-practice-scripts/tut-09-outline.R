library(tidyverse)
library(deSolve)

# ── Scenario ──────────────────────────────────────────────────────────────────
#
# A call centre is tracking its abandoned call rate (% of inbound calls
# disconnected before being answered) for the East region over 24 months.
#
# Two feedback loops drive the system:
#
#   R1 (+): Higher abandoned rate → frustrated customers call back repeatedly
#           → higher call volume → even higher abandoned rate
#
#   B1 (−): Rising abandoned rate → management pressure to hire agents /
#           adjust routing policy → lower abandoned rate
#
# The problem in this data:
#   - B1 kicks in too late  (~month 13, vs. an acceptable target of month 8)
#   - The implicit equilibrium in current staffing policy is too high
#     (~41 % vs. an acceptable target of < 10 %)
#
# ─────────────────────────────────────────────────────────────────────────────


# ------------------------------------------------------------------------------
# SECTION 1: load and explore the data
# ------------------------------------------------------------------------------

# ── Step 1: Raw data (wide format — as received from BI / Excel export) ───────
 
wide_data <- tribble(
  ~period,   ~abandoned_pct,
  "Jan-23",   0.5,
  "Feb-23",   2.1,
  "Mar-23",   1.7,
  "Apr-23",   0.5,
  "May-23",   5.3,
  "Jun-23",   4.3,
  "Jul-23",   4.4,
  "Aug-23",   6.4,
  "Sep-23",   9.2,
  "Oct-23",  10.6,
  "Nov-23",   7.4,
  "Dec-23",  17.4,
  "Jan-24",  19.8,
  "Feb-24",  24.5,
  "Mar-24",  28.7,
  "Apr-24",  33.4,
  "May-24",  31.7,
  "Jun-24",  37.8,
  "Jul-24",  37.4,
  "Aug-24",  40.0,
  "Sep-24",  40.7,
  "Oct-24",  40.9,
  "Nov-24",  37.8,
  "Dec-24",  40.1
)

print(wide_data)

# ── Step 2: Reshape to tidy (long) format ─────────────────────────────────────

tidy_data <- wide_data |>
  mutate(date = as.Date(paste0("01-", period), format = "%d-%b-%y")) |>
  arrange(date) |>
  mutate(t = row_number())

# ── Step 3: Plot ──────────────────────────────────────────────────────────────

ggplot(tidy_data, aes(x = date, y = abandoned_pct)) +
  geom_line(linewidth = 0.8, colour = "#619CFF") +
  geom_point(size = 1.8, colour = "#619CFF") +
  geom_hline(yintercept = 10, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 12,
           label = "Target: < 10%", colour = "grey40", size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 50),
                     labels = function(x) paste0(x, "%")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Call Centre Abandoned Call Rate — East Region (2023–2024)",
    subtitle = "S-shaped growth: balancing feedback kicks in too late; equilibrium far above target",
    x        = NULL,
    y        = "Abandoned Call Rate (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 2: fit a logistic curve using binomial GLM
# ------------------------------------------------------------------------------

# ── Why we need to rescale ────────────────────────────────────────────────────
# glm(family = binomial) assumes the response is bounded in [0, 1], treating
# 1.0 as the upper asymptote (K = 100 %). Our data settles around 41 %, so a
# naive fit pushes the inflection point (t0) far outside the observation window
# and underestimates the growth rate (r).
#
# Fix: estimate K as the average of the top 5 observed values, then rescale
# the data to [0, 1] before fitting. The logistic identity:
#   K / (1 + exp(−r(t − t0)))  ÷ K  =  1 / (1 + exp(−r(t − t0)))
# shows that r and t0 are unchanged by the scaling — only K is factored out.
# After fitting, reverse-scale the fitted curve back to percentage units.

N <- 1000  # fictional trial count: gives the GLM stable binomial weights

y     <- tidy_data$abandoned_pct
t_seq <- tidy_data$t

# Step 1: estimate K as average of top-5 observed values
K_hat <- mean(sort(y, decreasing = TRUE)[1:5])

# Step 2: rescale to (0, 1); clamp just below 1 to avoid Inf on the logit
y_scaled <- pmin(y / K_hat, 0.9999)

# Step 3: fit binomial GLM on rescaled proportions
fit <- glm(
  cbind(round(y_scaled * N), round((1 - y_scaled) * N)) ~ t_seq,
  family = binomial(link = "logit")
)

b0 <- coef(fit)[["(Intercept)"]]
b1 <- coef(fit)[["t_seq"]]

# Step 4: recover r and t0 from GLM coefficients
# logit(p) = b0 + b1*t  →  b1 = r,  t0 = -b0 / b1
r_fit  <- b1
t0_fit <- -b0 / b1

tibble(
  parameter = c("K (estimated)", "r (fitted)", "t0 (fitted)"),
  value     = c(round(K_hat, 1), round(r_fit, 3), round(t0_fit, 1))
) |> print()

# Step 5: compute smooth fitted curve in original % units
t_fine   <- seq(1, max(t_seq), length.out = 200)
y_fitted <- plogis(b0 + b1 * t_fine) * K_hat

fitted_curve <- tibble(
  date   = seq(min(tidy_data$date), max(tidy_data$date), length.out = 200),
  fitted = y_fitted
)

# ── Plot: observed data + fitted curve ────────────────────────────────────────

ggplot() +
  geom_line(data  = tidy_data,
            aes(x = date, y = abandoned_pct),
            linewidth = 0.6, colour = "#619CFF", alpha = 0.5) +
  geom_point(data = tidy_data,
             aes(x = date, y = abandoned_pct),
             size = 1.5, colour = "#619CFF", alpha = 0.5) +
  geom_line(data  = fitted_curve,
            aes(x = date, y = fitted),
            linewidth = 1.2, colour = "#619CFF") +
  geom_hline(yintercept = 10, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 12,
           label = "Target: < 10%", colour = "grey40", size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 50),
                     labels = function(x) paste0(x, "%")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Call Centre Abandoned Call Rate — East Region, Fitted Logistic Curve",
    subtitle = "Faint: observed data  |  Solid: rescaled-binomial GLM fit",
    x        = NULL,
    y        = "Abandoned Call Rate (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

# ------------------------------------------------------------------------------
# SECTION 3: SD model with policy and operational levers
# ------------------------------------------------------------------------------

# ── Structure ─────────────────────────────────────────────────────────────────
#
# One stock: s_abandoned_rate (% of inbound calls abandoned)
#
# Two flows drive the stock — directly analogous to the rabbit model in tut-05:
#
#   f_repeat_pressure  [R1, +]
#     Abandoned callers ring back, compounding call volume and pushing the
#     abandoned rate higher.  cf. f_birthing = population × births_normal
#
#   f_policy_response  [B1, −]
#     Management hires agents / adjusts routing to drive the rate down.
#     The effective response delay contracts once the abandoned rate exceeds
#     the staffing threshold — exactly as the rabbit's effective lifetime
#     shortens once food per rabbit falls below appetite.
#     cf. f_dying = population / (avg_lifetime × normalised_nutrition)
#
# ── Policy levers ─────────────────────────────────────────────────────────────
#
#   p_staffing_threshold  — the abandoned-rate level that triggers escalated
#                           management action; lower = B1 kicks in sooner
#                           (controls timing AND equilibrium)
#
#   p_response_delay      — baseline months for improvement when below
#                           threshold; shorter = B1 acts more aggressively
#                           (controls equilibrium)
#
# ── Implied equilibrium ───────────────────────────────────────────────────────
#   At equilibrium, f_repeat_pressure = f_policy_response, which gives:
#   K = p_staffing_threshold × p_callback_fraction × p_response_delay
#
# ─────────────────────────────────────────────────────────────────────────────

model_callcentre <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {

    # Ratio of staffing threshold to current abandoned rate.
    # Mirrors c_normalised_nutrition from tut-05 model_s2:
    #   < 1 once abandoned rate exceeds threshold → effective delay contracts
    #   = 1 while abandoned rate is below threshold → baseline (slow) response
    c_policy_effectiveness <- min(
      p_staffing_threshold / max(s_abandoned_rate, 0.001), 1
    )

    # R1: repeat callbacks compound call volume → abandoned rate rises
    f_repeat_pressure <- s_abandoned_rate * p_callback_fraction

    # B1: staffing / routing policy drives abandoned rate down;
    # effective delay shortens as management urgency grows above threshold
    f_policy_response <- s_abandoned_rate /
      (p_response_delay * c_policy_effectiveness)

    ds_abandoned_rate_dt <- f_repeat_pressure - f_policy_response

    return(list(
      c(ds_abandoned_rate_dt),
      repeat_pressure      = f_repeat_pressure,
      policy_response      = f_policy_response,
      policy_effectiveness = c_policy_effectiveness
    ))
  })
}

# ── Scenarios ─────────────────────────────────────────────────────────────────
# Implied K per scenario = p_staffing_threshold × p_callback_fraction × p_response_delay

scenarios <- list(
  `Current policy`  = c(p_callback_fraction = 0.55, p_response_delay = 5.0, p_staffing_threshold = 15),
  `Earlier trigger` = c(p_callback_fraction = 0.55, p_response_delay = 5.0, p_staffing_threshold = 8),
  `Faster response` = c(p_callback_fraction = 0.55, p_response_delay = 2.5, p_staffing_threshold = 15),
  `Both levers`     = c(p_callback_fraction = 0.55, p_response_delay = 2.5, p_staffing_threshold = 8)
)

stocks   <- c(s_abandoned_rate = 0.5)
sim_time <- seq(1, 24, by = 0.1)
origin_date <- as.Date("2023-01-01")

sim_results <- imap_dfr(scenarios, function(params, label) {
  ode(y = stocks, times = sim_time, func = model_callcentre,
      parms = params, method = "rk4") |>
    as_tibble() |>
    transmute(
      scenario      = label,
      time          = as.numeric(time),
      date          = origin_date + (time - 1) * 30.44,
      abandoned_rate = as.numeric(s_abandoned_rate)
    )
}) |>
  mutate(scenario = factor(scenario, levels = names(scenarios)))

# ── Equilibrium reached by each scenario ──────────────────────────────────────

sim_results |>
  group_by(scenario) |>
  filter(time == max(time)) |>
  transmute(scenario, equilibrium_pct = round(abandoned_rate, 1)) |>
  print()

# ── Plot: SD model scenarios vs observed data ─────────────────────────────────

ggplot(sim_results, aes(x = date, y = abandoned_rate, colour = scenario)) +
  geom_line(linewidth = 0.9) +
  geom_point(
    data = tidy_data,
    aes(x = date, y = abandoned_pct),
    colour = "grey50", size = 1.5, alpha = 0.7, inherit.aes = FALSE
  ) +
  geom_hline(yintercept = 10, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = origin_date, y = 12,
           label = "Target: < 10%", colour = "grey40", size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 50), labels = function(x) paste0(x, "%")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  scale_colour_manual(values = c(
    "Current policy"  = "#E74C3C",
    "Earlier trigger" = "#F39C12",
    "Faster response" = "#3498DB",
    "Both levers"     = "#27AE60"
  )) +
  labs(
    title    = "Call Centre Abandoned Rate — Policy Scenarios",
    subtitle = "Grey points: observed data  |  Lines: SD model under each policy",
    x        = NULL,
    y        = "Abandoned Call Rate (%)",
    colour   = "Policy scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )

# ── Equilibrium by scenario ───────────────────────────────────────────────────
#
#   Scenario          Equilibrium
#   ──────────────────────────────
#   Current policy     41.2 %   matches the observed East region data
#   Earlier trigger    22.0 %   B1 threshold moved from 15 % → 8 %
#   Faster response    15.7 %   response delay halved from 5 → 2.5 months
#   Both levers        10.7 %   just above the 10 % target
#
# The model calibrates directly to observed data under the current policy.
# Each lever independently moves the equilibrium downward; pulling both
# together nearly hits the 10 % target — demonstrating that the gap between
# current performance and acceptable performance is a structural, not
# operational, problem: it is encoded in when management responds and how
# aggressively the staffing policy responds once triggered.


# ── Stock-and-flow diagram ────────────────────────────────────────────────────
# Adapted directly from model_s2 in tut-05-s-shaped-growth.qmd.
#
# Structural mapping (rabbit → call centre):
#   rabbit population     →  abandoned call rate (%)
#   births / births norm  →  repeat callbacks / callback fraction
#   deaths / avg lifetime →  policy response / response delay
#   food per rabbit       →  abandonment ratio  (rate ÷ threshold)
#   normalised nutrition  →  policy effectiveness  (min(1/ratio, 1))
#   food supply + appetite→  staffing threshold  (collapses to one parameter)

make_cloud <- function(cx, cy, w = 0.45, h = 0.28) {
  theta <- seq(0, 2 * pi, length.out = 200)
  bump  <- 1 + 0.12 * sin(8 * theta)
  tibble(x = cx + w * bump * cos(theta), y = cy + h * bump * sin(theta))
}

flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")

callbacks_valve_x <- 2.55
callbacks_valve_y <- 4.0
response_valve_x  <- 8.45
response_valve_y  <- 4.0

ggplot() +
  # Source cloud
  geom_polygon(data = make_cloud(0.75, callbacks_valve_y), aes(x, y),
               fill = "white", colour = "black", linewidth = 0.7) +
  # Repeat callbacks — inflow (R1)
  annotate("segment", x = 1.2, xend = 3.85,
           y = callbacks_valve_y, yend = callbacks_valve_y,
           linewidth = 2, colour = "#4e8cd4", arrow = flow_arrow) +
  annotate("point", x = callbacks_valve_x, y = callbacks_valve_y,
           size = 5, colour = "#4e8cd4") +
  annotate("text", x = callbacks_valve_x, y = 4.44,
           label = "repeat\ncallbacks", size = 3.2, colour = "#4e8cd4",
           lineheight = 0.9) +
  # Stock
  annotate("rect", xmin = 3.85, xmax = 7.15, ymin = 3.45, ymax = 4.55,
           fill = "white", colour = "black", linewidth = 1.6) +
  annotate("rect", xmin = 3.97, xmax = 7.03, ymin = 3.57, ymax = 4.43,
           fill = "#fafaf0", colour = "black", linewidth = 0.5) +
  annotate("text", x = 5.5, y = 4.0, label = "abandoned\ncall rate (%)",
           size = 3.2, fontface = "bold", lineheight = 0.9) +
  # Policy response — outflow (B1)
  annotate("segment", x = 7.15, xend = 9.8,
           y = response_valve_y, yend = response_valve_y,
           linewidth = 2, colour = "#d45b4e", arrow = flow_arrow) +
  annotate("point", x = response_valve_x, y = response_valve_y,
           size = 5, colour = "#d45b4e") +
  annotate("text", x = response_valve_x, y = 4.44,
           label = "policy\nresponse", size = 3.2, colour = "#d45b4e",
           lineheight = 0.9) +
  # Sink cloud
  geom_polygon(data = make_cloud(10.25, response_valve_y), aes(x, y),
               fill = "white", colour = "black", linewidth = 0.7) +

  # Auxiliary chain (bold — calculated converters)
  annotate("text", x = 5.5, y = 2.75, label = "abandonment\nratio",
           size = 3.0, fontface = "bold", lineheight = 0.9) +
  annotate("text", x = 5.5, y = 1.85, label = "policy\neffectiveness",
           size = 3.0, fontface = "bold", lineheight = 0.9) +

  # Parameters (plain text)
  annotate("text", x = 1.5,  y = 2.6,  label = "callback\nfraction",
           size = 3.0, lineheight = 0.9) +
  annotate("text", x = 9.1,  y = 2.6,  label = "response\ndelay",
           size = 3.0, lineheight = 0.9) +
  annotate("text", x = 2.9,  y = 2.75, label = "staffing\nthreshold",
           size = 3.0, lineheight = 0.9) +

  # Info: vertical chain — stock ↓ abandonment ratio ↓ policy effectiveness
  annotate("segment", x = 5.5, xend = 5.5, y = 3.45, yend = 2.98,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +
  annotate("segment", x = 5.5, xend = 5.5, y = 2.52, yend = 2.08,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +

  # Info: staffing threshold → abandonment ratio
  geom_curve(
    data = data.frame(x = 3.22, y = 2.75, xend = 4.72, yend = 2.75),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.2, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: policy effectiveness → response valve (B1)
  geom_curve(
    data = data.frame(x = 6.3, y = 1.85,
                      xend = response_valve_x, yend = response_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = 0.25, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: stock → callbacks valve (R1 reinforcing loop)
  geom_curve(
    data = data.frame(x = 4.5, y = 3.45,
                      xend = 2.1, yend = callbacks_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.38, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: callback fraction → callbacks valve
  geom_curve(
    data = data.frame(x = 1.9, y = 2.6,
                      xend = callbacks_valve_x - 0.1, yend = callbacks_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.3, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # Info: response delay → response valve
  geom_curve(
    data = data.frame(x = 8.8, y = 2.6,
                      xend = response_valve_x + 0.1, yend = response_valve_y - 0.12),
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
  labs(title = "Call Centre S-Curve — stock-and-flow diagram")









