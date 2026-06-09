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

# ── Step 1: Data ──────────────────────────────────────────────────────────────
#
# Monthly count of staff recorded as working at reduced capacity due to burnout.
# Figures are rounded to the nearest whole number.

staff_burnout_data <- tribble(
  ~date,          ~burnt_out_staff,
  "2023-01-01",   11,
  "2023-02-01",   12,
  "2023-03-01",   17,
  "2023-04-01",   13,
  "2023-05-01",   19,
  "2023-06-01",   21,
  "2023-07-01",   24,
  "2023-08-01",   39,
  "2023-09-01",   35,
  "2023-10-01",   49,
  "2023-11-01",   57,
  "2023-12-01",   59,
  "2024-01-01",   63,
  "2024-02-01",   61,
  "2024-03-01",   59,
  "2024-04-01",   66,
  "2024-05-01",   70,
  "2024-06-01",   65,
  "2024-07-01",   69,
  "2024-08-01",   67,
  "2024-09-01",   71,
  "2024-10-01",   72,
  "2024-11-01",   68,
  "2024-12-01",   70
) |>
  mutate(date = as.Date(date), t = row_number())

# ── Step 2: Plot ──────────────────────────────────────────────────────────────

ggplot(staff_burnout_data, aes(x = date, y = burnt_out_staff)) +
  geom_line(linewidth = 0.8, colour = "#619CFF") +
  geom_point(size = 1.8, colour = "#619CFF") +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(staff_burnout_data$date), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Post-Redundancy Trend (2023–2024)",
    subtitle = "S-shaped growth: stress spreads faster than management responds; equilibrium far above target",
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

# ── Step 3: Linear regression baseline ────────────────────────────────────────

lm_fit  <- lm(burnt_out_staff ~ t, data = staff_burnout_data)
r_sq_lm <- summary(lm_fit)$r.squared

lm_fitted_curve <- tibble(
  date   = seq(min(staff_burnout_data$date), max(staff_burnout_data$date), length.out = 200),
  fitted = predict(lm_fit,
                   newdata = tibble(t = seq(1, max(staff_burnout_data$t), length.out = 200)))
)

ggplot() +
  geom_line(data  = staff_burnout_data,
            aes(x = date, y = burnt_out_staff),
            linewidth = 0.6, colour = "#619CFF", alpha = 0.5) +
  geom_point(data = staff_burnout_data,
             aes(x = date, y = burnt_out_staff),
             size = 1.5, colour = "#619CFF", alpha = 0.5) +
  geom_line(data  = lm_fitted_curve,
            aes(x = date, y = fitted),
            linewidth = 1.2, colour = "#619CFF") +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(staff_burnout_data$date), y = 27,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Linear Model Fit",
    subtitle = paste0("Linear model  |  R² = ", round(r_sq_lm, 3)),
    x        = NULL,
    y        = "Staff on reduced capacity (count)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


# ------------------------------------------------------------------------------
# SECTION 2: fit a logistic curve using nls()
# ------------------------------------------------------------------------------

# SSfpl() is a self-starting 4-parameter logistic built into base R.
# It fits the formula:  A + (B − A) / (1 + exp((xmid − t) / scal))
#
#   A    — lower asymptote (L): the level the curve starts from
#   B    — upper asymptote (K): the equilibrium the curve grows toward
#   xmid — inflection point (t0): the month of steepest growth
#   scal — growth rate scale: nls uses 1/r internally; we recover r = 1/scal
#
# "Self-starting" means SSfpl() estimates its own starting values from the
# data automatically — no manual guessing needed. nls() then fits directly
# to the raw staff counts with no rescaling or pseudo-trial tricks.

fit_nls <- nls(burnt_out_staff ~ SSfpl(t, A, B, xmid, scal), data = staff_burnout_data)

coefs  <- coef(fit_nls)
L_fit  <- coefs[["A"]]
K_fit  <- coefs[["B"]]
t0_fit <- coefs[["xmid"]]
r_fit  <- 1 / coefs[["scal"]]

tibble(
  parameter = c("K — upper asymptote", "L — lower asymptote", "r (growth rate)", "t0 (inflection month)"),
  value     = c(round(K_fit, 1), round(L_fit, 1), round(r_fit, 3), round(t0_fit, 1))
) |> print()

r_sq_nls <- cor(staff_burnout_data$burnt_out_staff, fitted(fit_nls))^2

tibble(
  model     = c("Linear", "Logistic (nls)"),
  r_squared = round(c(r_sq_lm, r_sq_nls), 3)
) |> print()

t_fine       <- seq(1, max(staff_burnout_data$t), length.out = 200)
fitted_curve <- tibble(
  date   = seq(min(staff_burnout_data$date), max(staff_burnout_data$date), length.out = 200),
  fitted = predict(fit_nls, newdata = tibble(t = t_fine))
)

ggplot() +
  geom_line(data  = staff_burnout_data,
            aes(x = date, y = burnt_out_staff),
            linewidth = 0.6, colour = "grey55", alpha = 0.7) +
  geom_point(data = staff_burnout_data,
             aes(x = date, y = burnt_out_staff),
             size = 1.5, colour = "grey55", alpha = 0.7) +
  geom_line(data  = lm_fitted_curve,
            aes(x = date, y = fitted, colour = "Linear"),
            linewidth = 0.75, linetype = "dotted") +
  geom_line(data  = fitted_curve,
            aes(x = date, y = fitted, colour = "Logistic (nls)"),
            linewidth = 1.2) +
  geom_hline(yintercept = 25, linetype = "dashed",
             colour = "grey40", linewidth = 0.5) +
  annotate("text", x = min(staff_burnout_data$date), y = 17,
           label = "Target: < 25 staff", colour = "grey40",
           size = 3, hjust = 0) +
  scale_colour_manual(values = c("Linear" = "#E74C3C", "Logistic (nls)" = "#619CFF")) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Burnout — Linear vs Logistic Fit",
    subtitle = paste0("Linear R² = ", round(r_sq_lm, 3),
                      "  |  Logistic R² = ", round(r_sq_nls, 3)),
    x        = NULL,
    y        = "Staff on reduced capacity (count)",
    colour   = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )




ggplot() +
  geom_line(data  = staff_burnout_data,
            aes(x = date, y = burnt_out_staff),
            linewidth = 0.6, colour = "grey55", alpha = 0.7) +
  geom_point(data = staff_burnout_data,
             aes(x = date, y = burnt_out_staff),
             size = 1.5, colour = "grey55", alpha = 0.7) +
  geom_line(data  = lm_fitted_curve,
            aes(x = date, y = fitted, colour = "Linear"),
            linewidth = 0.75, linetype = "dotted") +
  geom_line(data  = fitted_curve,
            aes(x = date, y = fitted, colour = "Logistic (nls)"),
            linewidth = 1.2) +
  annotate("text", x = min(staff_burnout_data$date) + diff(range(staff_burnout_data$date)) * (1/3), y = 15,
           label = paste0("Linear R² = ", round(r_sq_lm, 3),
                          "  |  Logistic R² = ", round(r_sq_nls, 3)), colour = "grey40",
           size = 6, hjust = 0) +
  scale_colour_manual(values = c("Linear" = "#E74C3C", "Logistic (nls)" = "#619CFF")) +
  scale_y_continuous(limits = c(0, 75)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Staff Attrition — Linear vs Logistic Fit",
    x        = NULL,
    y        = "Staff on reduced capacity (count)",
    colour   = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.x     = element_text(angle = 30, hjust = 1)
  )

ggsave(
  filename = "website-tutorials/assets/services-ml-statistics-predictive-models.png",
  width    = 7,
  height   = 5,
  units    = "in",
  dpi      = 120,
  bg       = "white"
)






