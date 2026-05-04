# S-Shaped Growth Structure 1 — Stock-and-Flow Diagram (new style)
# One stock (rabbit population), births inflow (R1 positive loop),
# deaths outflow driven by density-dependent deaths multiplier (B1 negative loop).
# All variables in the causal chain shown; no ellipses; geom_curve info links.

library(tidyverse)
source("R/sd-diagram-functions.R")   # provides make_cloud

flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")

births_valve_x <- 2.55
births_valve_y <- 4.0
deaths_valve_x <- 8.45
deaths_valve_y <- 4.0

ggplot() +
  # Source cloud
  geom_polygon(data = make_cloud(0.75, births_valve_y), aes(x, y),
               fill = "white", colour = "black", linewidth = 0.7) +
  # Births inflow
  annotate("segment", x = 1.2, xend = 3.85, y = births_valve_y, yend = births_valve_y,
           linewidth = 2, colour = "#4e8cd4", arrow = flow_arrow) +
  annotate("point", x = births_valve_x, y = births_valve_y, size = 5, colour = "#4e8cd4") +
  annotate("text", x = births_valve_x, y = 4.38, label = "births",
           size = 3.2, colour = "#4e8cd4") +
  # Stock
  annotate("rect", xmin = 3.85, xmax = 7.15, ymin = 3.45, ymax = 4.55,
           fill = "white", colour = "black", linewidth = 1.6) +
  annotate("rect", xmin = 3.97, xmax = 7.03, ymin = 3.57, ymax = 4.43,
           fill = "#fafaf0", colour = "black", linewidth = 0.5) +
  annotate("text", x = 5.5, y = 4.0, label = "rabbit population",
           size = 3.5, fontface = "bold") +
  # Deaths outflow
  annotate("segment", x = 7.15, xend = 9.8, y = deaths_valve_y, yend = deaths_valve_y,
           linewidth = 2, colour = "#d45b4e", arrow = flow_arrow) +
  annotate("point", x = deaths_valve_x, y = deaths_valve_y, size = 5, colour = "#d45b4e") +
  annotate("text", x = deaths_valve_x, y = 4.38, label = "deaths",
           size = 3.2, colour = "#d45b4e") +
  # Sink cloud
  geom_polygon(data = make_cloud(10.25, deaths_valve_y), aes(x, y),
               fill = "white", colour = "black", linewidth = 0.7) +

  # ── Auxiliary chain (bold text, centered below stock) ──────────────────────
  annotate("text", x = 5.5, y = 2.75, label = "population\ndensity",
           size = 3.0, fontface = "bold") +
  annotate("text", x = 5.5, y = 1.85, label = "normalized\ndensity",
           size = 3.0, fontface = "bold") +
  annotate("text", x = 5.5, y = 0.95, label = "deaths\nmultiplier",
           size = 3.0, fontface = "bold") +
  annotate("text", x = 5.5, y = 0.62, label = "(empirical lookup)",
           size = 2.5, colour = "grey40", fontface = "italic") +

  # ── Parameters (plain text) ────────────────────────────────────────────────
  annotate("text", x = 1.5, y = 2.6, label = "births\nnormal",  size = 3.0) +
  annotate("text", x = 9.1, y = 2.6, label = "average\nlifetime", size = 3.0) +
  annotate("text", x = 2.9, y = 2.15, label = "area", size = 3.0) +
  annotate("text", x = 2.9, y = 1.3,  label = "normal pop\ndensity", size = 3.0) +

  # ── Info links ─────────────────────────────────────────────────────────────
  # Vertical chain: straight segments (elements stacked directly above each other)
  annotate("segment", x = 5.5, xend = 5.5, y = 3.45, yend = 2.98,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +
  annotate("segment", x = 5.5, xend = 5.5, y = 2.52, yend = 2.08,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +
  annotate("segment", x = 5.5, xend = 5.5, y = 1.62, yend = 1.18,
           colour = "grey40", linewidth = 0.5, arrow = info_arrow) +

  # area → population density
  geom_curve(
    data = data.frame(x = 3.2, y = 2.15, xend = 4.7, yend = 2.65),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.2, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # normal pop density → normalized density
  geom_curve(
    data = data.frame(x = 3.2, y = 1.35, xend = 4.7, yend = 1.75),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.2, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # deaths multiplier → deaths valve (B1 balancing loop)
  geom_curve(
    data = data.frame(x = 6.3, y = 0.95, xend = deaths_valve_x, yend = deaths_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = 0.25, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # stock → births valve (R1 reinforcing loop)
  geom_curve(
    data = data.frame(x = 4.5, y = 3.45, xend = 2.1, yend = births_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.38, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # births normal → births valve
  geom_curve(
    data = data.frame(x = 1.9, y = 2.6, xend = births_valve_x - 0.1, yend = births_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = -0.3, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +
  # average lifetime → deaths valve
  geom_curve(
    data = data.frame(x = 8.8, y = 2.6, xend = deaths_valve_x + 0.1, yend = deaths_valve_y - 0.12),
    aes(x = x, y = y, xend = xend, yend = yend),
    curvature = 0.3, colour = "grey40", linewidth = 0.5, arrow = info_arrow
  ) +

  # ── Loop labels ────────────────────────────────────────────────────────────
  annotate("text", x = 2.7, y = 2.9, label = "R1  (+)", size = 3.8,
           colour = "#27ae60", fontface = "bold") +
  annotate("text", x = 9.3, y = 2.1, label = "B1  (−)", size = 3.8,
           colour = "#c0392b", fontface = "bold") +
  theme_void() +
  coord_cartesian(xlim = c(0, 11), ylim = c(0.3, 5.1)) +
  labs(title = "Structure 1 — stock-and-flow diagram")
