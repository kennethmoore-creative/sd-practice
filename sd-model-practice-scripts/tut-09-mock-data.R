library(tidyverse)
library(lubridate)

# ── Scenario ──────────────────────────────────────────────────────────────────
#
# A multi-region call centre is tracking its abandoned call rate (% of inbound
# calls disconnected before being answered).
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
#   - B1 kicks in too late (management responds around month 14, not month 8)
#   - The implicit equilibrium baked into current staffing policy is too high
#     (~35–40% vs an acceptable target of < 10%)
#
# Organisational levers:
#   (a) WHEN to trigger the staffing / policy response  → timing of B1
#   (b) WHAT target abandoned rate the policy aims for  → equilibrium level
#
# ─────────────────────────────────────────────────────────────────────────────


# ------------------------------------------------------------------------------
# SECTION 1: create and explore mock data
# ------------------------------------------------------------------------------

set.seed(42)

logistic <- function(t, K, r, t0) K / (1 + exp(-r * (t - t0)))

n_months <- 24
t        <- seq_len(n_months)
dates    <- seq(as.Date("2023-01-01"), by = "month", length.out = n_months)
periods  <- format(dates, "%b-%y")

# Region-level parameters: K = equilibrium (%), r = growth rate, t0 = inflection month
regions <- list(
  North = list(K = 38, r = 0.32, t0 = 14),
  South = list(K = 34, r = 0.28, t0 = 16),
  East  = list(K = 41, r = 0.36, t0 = 13),
  West  = list(K = 33, r = 0.30, t0 = 15)
)

# ── Step 1: Generate data in wide format ──────────────────────────────────────
# share of inbound calls that were disconnected before being
# answered, for each region in each month

# This mimics the standard BI-tool or Excel pivot-table export an analyst
# would receive — rows = regions, columns = time periods. Not immediately
# ready for plotting.


wide_data <- imap_dfr(regions, function(p, name) {
  signal <- logistic(t, p$K, p$r, p$t0)
  tibble(
    Region = name,
    period = factor(periods, levels = periods),
    value  = pmax(round(signal + rnorm(n_months, 0, 2.0), 1), 0.5)
  )
}) |>
  pivot_wider(names_from = period, values_from = value)

print(wide_data)

# ── Step 2: Reshape to tidy (long) format ─────────────────────────────────────

tidy_data <- wide_data |>
  pivot_longer(-Region, names_to = "period", values_to = "abandoned_pct") |>
  mutate(date = as.Date(paste0("01-", period), format = "%d-%b-%y")) |>
  arrange(Region, date)

# ── Step 3: Plot ──────────────────────────────────────────────────────────────

ggplot(tidy_data, aes(x = date, y = abandoned_pct, colour = Region)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  geom_hline(yintercept = 10, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 12,
           label = "Target: < 10%", colour = "grey40", size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 50),
                     labels = function(x) paste0(x, "%")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Call Centre Abandoned Call Rate — Regional Trend (2023–2024)",
    subtitle = "S-shaped growth: balancing feedback kicks in too late; equilibrium settles far above target",
    x        = NULL,
    y        = "Abandoned Call Rate (%)",
    colour   = "Region"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )


# ------------------------------------------------------------------------------
# SECTION 2: fit data to logistic curves using binomial glm
# ------------------------------------------------------------------------------

# ── Why we need to rescale ────────────────────────────────────────────────────
# glm(family = binomial) assumes the response is bounded in [0, 1], treating
# 1.0 as the upper asymptote (K = 100 %). Our data settles around 33–41 %, so
# a naive fit pushes the inflection point (t0) far outside the observation
# window and underestimates the growth rate (r).
#
# Fix: estimate K per region as the average of the top 5 observed values, then
# rescale the data to [0, 1] before fitting. The logistic identity:
#   K / (1 + exp(−r(t − t0)))  ÷ K  =  1 / (1 + exp(−r(t − t0)))
# shows that r and t0 are unchanged by the scaling — only K is factored out.
# After fitting, reverse-scale the fitted curve back to percentage units.

N <- 1000  # fictional trial count: gives the GLM stable binomial weights

fit_region <- function(df) {
  df     <- arrange(df, date)
  t_seq  <- seq_len(nrow(df))
  y      <- df$abandoned_pct

  # Step 1: estimate K as average of top-5 observed values
  K_hat  <- mean(sort(y, decreasing = TRUE)[1:5])

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
  # logit(p) = b0 + b1*t  →  b1 = r,  t0 = −b0/b1
  r_fit  <- b1
  t0_fit <- -b0 / b1

  # Step 5: compute smooth fitted curve in original % units
  t_fine   <- seq(1, max(t_seq), length.out = 200)
  y_fitted <- plogis(b0 + b1 * t_fine) * K_hat

  list(K_hat = K_hat, r_fit = r_fit, t0_fit = t0_fit,
       t_fine = t_fine, y_fitted = y_fitted)
}

# Split tidy_data by region (group_split sorts alphabetically)
fits <- tidy_data |>
  group_by(Region) |>
  group_split() |>
  setNames(sort(names(regions))) |>
  lapply(fit_region)

# ── Compare fitted vs. true parameters ────────────────────────────────────────

param_comparison <- imap_dfr(fits, function(f, region) {
  true_p <- regions[[region]]
  tibble(
    Region  = region,
    K_true  = true_p$K,  K_hat   = round(f$K_hat, 1),
    r_true  = true_p$r,  r_fit   = round(f$r_fit, 3),
    t0_true = true_p$t0, t0_fit  = round(f$t0_fit, 1)
  )
})

print(param_comparison)

# ── Plot: observed data + fitted curves ───────────────────────────────────────

date_range <- range(tidy_data$date)

fitted_curves <- imap_dfr(fits, function(f, region) {
  tibble(
    Region = region,
    date   = seq(date_range[1], date_range[2], length.out = 200),
    fitted = f$y_fitted
  )
})

ggplot() +
  geom_line(data  = tidy_data,
            aes(x = date, y = abandoned_pct, colour = Region),
            linewidth = 0.6, alpha = 0.45) +
  geom_point(data = tidy_data,
             aes(x = date, y = abandoned_pct, colour = Region),
             size = 1.2, alpha = 0.45) +
  geom_line(data  = fitted_curves,
            aes(x = date, y = fitted, colour = Region),
            linewidth = 1.1) +
  geom_hline(yintercept = 10, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(tidy_data$date), y = 12,
           label = "Target: < 10%", colour = "grey40", size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 50),
                     labels = function(x) paste0(x, "%")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Call Centre Abandoned Call Rate — Fitted Logistic Curves",
    subtitle = "Faint: observed data  |  Solid: rescaled-binomial GLM fit",
    x        = NULL,
    y        = "Abandoned Call Rate (%)",
    colour   = "Region"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )

















