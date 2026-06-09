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

# ── Logistic fit summary (from part 1 — nls / SSfpl) ─────────────────────────

tibble(
  parameter = c("K — upper asymptote", "L — lower asymptote", "r (growth rate)", "t0 (inflection month)"),
  value     = c(68.6, 10.1, 0.480, 8.8)
) |> print()

raw_data <- tribble(
  ~period,   ~burnt_out_staff,
  "Jan-23",  11,
  "Feb-23",  12,
  "Mar-23",  17,
  "Apr-23",  13,
  "May-23",  19,
  "Jun-23",  21,
  "Jul-23",  24,
  "Aug-23",  39,
  "Sep-23",  35,
  "Oct-23",  49,
  "Nov-23",  57,
  "Dec-23",  59,
  "Jan-24",  63,
  "Feb-24",  61,
  "Mar-24",  59,
  "Apr-24",  66,
  "May-24",  70,
  "Jun-24",  65,
  "Jul-24",  69,
  "Aug-24",  67,
  "Sep-24",  71,
  "Oct-24",  72,
  "Nov-24",  68,
  "Dec-24",  70
)

print(raw_data)

# ── Step 2: Reshape to tidy format ────────────────────────────────────────────

tidy_data <- raw_data |>
  mutate(date = as.Date(paste0("01-", period), format = "%d-%b-%y")) |>
  arrange(date) |>
  mutate(t = row_number())

# ------------------------------------------------------------------------------
# SECTION 3: simple logistic SD model from nls parameters
# ------------------------------------------------------------------------------

# The nls fit gives us K, L, r, and t0 directly. The ODE that produces the
# same S-shaped trajectory is just the logistic growth equation:
#
#   ds/dt = r * (s − L) * (1 − (s − L) / (K − L))
#
# (s − L) is how far above the baseline the stock currently sits.
# (1 − (s − L)/(K − L)) is how much room is left before the ceiling K.
# When s is near L the second term ≈ 1 and growth is near-exponential.
# When s approaches K the second term → 0 and growth halts.
#
# No auxiliary variables, no threshold logic — just the three nls parameters
# plugged straight into one net-flow formula.

p_K <- 68.6
p_L <- 10.1
p_r <- 0.480

logistic_model <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    f_net <- p_r * (s_burnt_out - p_L) * (1 - (s_burnt_out - p_L) / (p_K - p_L))
    list(c(f_net))
  })
}

sim_logistic <- ode(
  y      = c(s_burnt_out = 11),
  times  = seq(1, 24, by = 0.1),
  parms  = c(p_K = p_K, p_L = p_L, p_r = p_r),
  func   = logistic_model,
  method = "rk4"
) |>
  as_tibble() |>
  mutate(
    time        = as.numeric(time),
    s_burnt_out = as.numeric(s_burnt_out),
    date        = as.Date("2023-01-01") + (time - 1) * 30.44
  )

ggplot() +
  geom_point(data = tidy_data,
             aes(x = date, y = burnt_out_staff),
             colour = "grey50", size = 1.8, alpha = 0.7) +
  geom_line(data = sim_logistic,
            aes(x = date, y = s_burnt_out),
            colour = "#619CFF", linewidth = 1.0) +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = as.Date("2023-01-01"), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Simple Logistic SD Model",
    subtitle = "Parameters taken directly from nls fit  |  Grey points: observed data",
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 3a: decompose the net flow into explicit inflow and outflow
# ------------------------------------------------------------------------------

# Expanding r*(s−L)*(1−(s−L)/(K−L)) algebraically gives two terms:
#
#   f_in  = r * (s − L)              ← R1: contagion scales with active burnout
#   f_out = r * (s − L)² / (K − L)  ← B1: recovery drag grows as capacity fills
#
# The curve is identical to Section 3 — only the structure is now visible.
# Both flows share r, so the spread rate cancels at equilibrium:
#   setting f_in = f_out → s* = L + (K − L) = K
# The equilibrium is determined purely by K and L, not by r.
# r controls only the speed of approach, not where the system ends up.

logistic_decomposed <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    f_in  <- p_r * (s_burnt_out - p_L)
    f_out <- p_r * (s_burnt_out - p_L)^2 / (p_K - p_L)
    list(c(f_in - f_out), inflow = f_in, outflow = f_out)
  })
}

sim_decomposed <- ode(
  y      = c(s_burnt_out = 11),
  times  = seq(1, 24, by = 0.1),
  parms  = c(p_K = p_K, p_L = p_L, p_r = p_r),
  func   = logistic_decomposed,
  method = "rk4"
) |>
  as_tibble() |>
  mutate(
    time        = as.numeric(time),
    s_burnt_out = as.numeric(s_burnt_out),
    date        = as.Date("2023-01-01") + (time - 1) * 30.44
  )

ggplot() +
  geom_point(data = tidy_data,
             aes(x = date, y = burnt_out_staff),
             colour = "grey50", size = 1.8, alpha = 0.7) +
  geom_line(data = sim_decomposed,
            aes(x = date, y = s_burnt_out),
            colour = "#619CFF", linewidth = 1.0) +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = as.Date("2023-01-01"), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Decomposed Inflow / Outflow",
    subtitle = "Identical curve to Section 3; inflow and outflow now explicit",
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 3b: rename flows and parameters to operational language
# ------------------------------------------------------------------------------

# Same model as 3a with organisational names:
#
#   r       → p_spread_rate   monthly rate at which burnout spreads through the team
#   K − L   → p_capacity      how many additional staff can be affected before
#                              density-dependent recovery arrests further growth
#   L       → p_baseline      pre-existing burnout at the start of observation
#
# Seeded from nls:
#   p_spread_rate = r         = 0.480
#   p_capacity    = K − L     = 68.6 − 10.1 = 58.5
#   p_baseline    = L         = 10.1
#
# Equilibrium: s* = p_baseline + p_capacity = 10.1 + 58.5 = 68.6
# To reach target K < 25, management would need p_capacity < 14.9 —
# a 75% reduction. That motivates the richer threshold model in Section 4,
# which gives independent levers on both the speed and the ceiling.

model_burnout_simple <- function(time, stocks, params) {
  with(as.list(c(stocks, params)), {
    f_burning_out <- p_spread_rate * (s_burnt_out - p_baseline)
    f_recovering  <- p_spread_rate * (s_burnt_out - p_baseline)^2 / p_capacity
    list(c(f_burning_out - f_recovering),
         burning_out = f_burning_out,
         recovering  = f_recovering)
  })
}

sim_simple <- ode(
  y      = c(s_burnt_out = 11),
  times  = seq(1, 24, by = 0.1),
  parms  = c(p_spread_rate = 0.480, p_capacity = 58.5, p_baseline = 10.1),
  func   = model_burnout_simple,
  method = "rk4"
) |>
  as_tibble() |>
  mutate(
    time        = as.numeric(time),
    s_burnt_out = as.numeric(s_burnt_out),
    date        = as.Date("2023-01-01") + (time - 1) * 30.44
  )

ggplot() +
  geom_point(data = tidy_data,
             aes(x = date, y = burnt_out_staff),
             colour = "grey50", size = 1.8, alpha = 0.7) +
  geom_line(data = sim_simple,
            aes(x = date, y = s_burnt_out),
            colour = "#619CFF", linewidth = 1.0) +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = as.Date("2023-01-01"), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Operationally Named Model",
    subtitle = "p_spread_rate, p_capacity, p_baseline seeded from nls  |  Grey points: observed data",
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 4: SD model with policy and operational levers
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
  `Current policy`  = c(p_spread_rate = 0.30, p_recovery_months = 7.3, p_intervention_threshold = 32),
  `Earlier trigger` = c(p_spread_rate = 0.30, p_recovery_months = 7.3, p_intervention_threshold = 20),
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
  scale_y_continuous(limits = c(0, 75)) +
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

ggplot(sim_results, aes(x = date, y = burnt_out_staff, colour = scenario)) +
  geom_line(linewidth = 0.9) +
  geom_point(
    data = tidy_data,
    aes(x = date, y = burnt_out_staff),
    colour = "grey50", size = 1.5, alpha = 0.7, inherit.aes = FALSE
  ) +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = origin_date, y = 28,
           label = "Target: < 25 employees", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  scale_colour_manual(values = c(
    "Current policy"  = "#E74C3C",
    "Earlier trigger" = "#F39C12",
    "Faster response" = "#3498DB",
    "Both levers"     = "#27AE60"
  )) +
  labs(
    title    = "Employee Attrition — Policy Scenarios",
    subtitle = "Grey points: observed data  |  Lines: SD model under each policy",
    x        = NULL,
    y        = "Employees leaving (count)",
    colour   = "Policy scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )

ggsave(
  filename = "website-tutorials/assets/services-scenario-models-decision-analytics.png",
  width    = 7,
  height   = 5,
  units    = "in",
  dpi      = 120,
  bg       = "white"
)

# ── Equilibrium by scenario ───────────────────────────────────────────────────
#
#   Scenario          K (implied)   Equilibrium (simulated)
#   ──────────────────────────────────────────────────────────────────────
#   Current policy      70.1            ~ 70       above target  (matches K_hat)
#   Earlier trigger     43.8            ~ 44       above target
#   Faster response     38.4            ~ 38       above target
#   Both levers         24.0            ~ 24       below target of 25 ✓
#
# Note on the "Faster response" lever: p_recovery_months cannot be reduced
# below 1/p_spread_rate (= 3.33 months) without making the net flow negative
# even below the intervention threshold — the spread rate must dominate
# naturally for the S-curve to form. Reducing from 7.3 → 4.0 months
# represents a significant but achievable improvement through contractor
# resource, occupational health support, and flexible working arrangements.
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

