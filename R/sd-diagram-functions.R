library(tidyverse)
if (file.exists("R/gg-helper-functions.R")) {
  source("R/gg-helper-functions.R")
} else {
  source("../R/gg-helper-functions.R")
}

# ------------------------------------------------------------------------------
# Reusable diagram functions — simple first-order structures only (tut-01 to
# tut-04). These functions predate the current style guide and are kept for
# backward compatibility with those tutorials.
#
# For all other diagrams (multi-stock, oscillating, epidemic, etc.) write the
# ggplot code inline in the .qmd chunk. Follow the SD Stock-and-Flow Diagram
# Style Guide in CLAUDE.md, which specifies:
#   - No ellipses: auxiliaries and parameters are plain annotate("text")
#   - Valves: annotate("point", size=5, colour="#4e8cd4"), after the segment
#   - Valve positions: named variables declared before ggplot() and reused by
#     the flow segment, the valve point, and all incoming info links
#   - Info links: geom_curve() with arrow=info_arrow throughout
#   - All auxiliaries and parameters shown
#   - fig-height scaled proportionally when ylim span changes
#   - Bi-flows: use arrow(ends="both", ...) if and only if the flow can reverse
#     direction (e.g. net flows in oscillating systems). Unidirectional inflows
#     and outflows always use the default ends="last".
# ------------------------------------------------------------------------------

# Draws a generic first-order positive feedback stock-and-flow diagram.
# stock_label: text inside the stock rectangle
# flow_label:  text above the inflow arrow
# param_label: text at the compounding fraction information link
draw_pos_feedback <- function(stock_label, flow_label, param_label) {
  flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
  info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")

  valve_x <- 3.2   # midpoint of inflow arrow (x = 1.65 to x = 4.8)
  valve_y <- 2.5

  ggplot() +
    geom_polygon(data = make_cloud(1.2, 2.5), aes(x, y),
                 fill = "white", colour = "black", linewidth = 0.7) +
    annotate("segment", x = 1.65, xend = 4.8, y = valve_y, yend = valve_y,
             linewidth = 2, colour = "#4e8cd4", arrow = flow_arrow) +
    annotate("point", x = valve_x, y = valve_y, size = 5, colour = "#4e8cd4") +
    annotate("text", x = 3.1, y = 3.05, label = flow_label,
             size = 3.2, colour = "#4e8cd4") +
    annotate("rect", xmin = 4.8, xmax = 8.8, ymin = 2.0, ymax = 3.0,
             fill = "white", colour = "black", linewidth = 1.6) +
    annotate("rect", xmin = 4.92, xmax = 8.68, ymin = 2.12, ymax = 2.88,
             fill = "#fafaf0", colour = "black", linewidth = 0.5) +
    annotate("text", x = 6.8, y = 2.5, label = stock_label,
             size = 3.5, fontface = "bold") +
    annotate("text", x = valve_x, y = 1.3, label = param_label, size = 3.0) +
    geom_curve(
      data = data.frame(x = valve_x, y = 1.55, xend = valve_x, yend = 2.4),
      aes(x = x, y = y, xend = xend, yend = yend),
      curvature = 0.2, colour = "grey40", linewidth = 0.5,
      arrow = info_arrow
    ) +
    geom_curve(data = data.frame(x = 6.8, y = 3.0, xend = valve_x, yend = 2.65),
               aes(x = x, y = y, xend = xend, yend = yend),
               curvature = 0.45, colour = "grey40",
               arrow = info_arrow) +
    annotate("text", x = 5.0, y = 3.75, label = "R1  (+)", size = 3.8,
             colour = "#27ae60", fontface = "bold") +
    theme_void() +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.5, 4.5))
}

# Draws a generic first-order negative feedback stock-and-flow diagram
# (simple form: stock, outflow, and a single draining parameter).
# stock_label: text inside the stock rectangle
# flow_label:  text above the outflow arrow
# param_label: text at the draining fraction information link
draw_neg_feedback_simple <- function(stock_label, flow_label, param_label) {
  flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
  info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")

  valve_x <- 6.3   # midpoint of outflow arrow (x = 4.8 to x = 7.8)
  valve_y <- 2.5

  ggplot() +
    annotate("rect", xmin = 0.8, xmax = 4.8, ymin = 2.0, ymax = 3.0,
             fill = "white", colour = "black", linewidth = 1.6) +
    annotate("rect", xmin = 0.92, xmax = 4.68, ymin = 2.12, ymax = 2.88,
             fill = "#fafaf0", colour = "black", linewidth = 0.5) +
    annotate("text", x = 2.8, y = 2.5, label = stock_label,
             size = 3.5, fontface = "bold") +
    annotate("segment", x = 4.8, xend = 7.8, y = valve_y, yend = valve_y,
             linewidth = 2, colour = "#d45b4e", arrow = flow_arrow) +
    annotate("point", x = valve_x, y = valve_y, size = 5, colour = "#d45b4e") +
    annotate("text", x = valve_x, y = 2.95, label = flow_label,
             size = 3.2, colour = "#d45b4e") +
    geom_polygon(data = make_cloud(8.5, 2.5), aes(x, y),
                 fill = "white", colour = "black", linewidth = 0.7) +
    annotate("text", x = valve_x, y = 1.3, label = param_label, size = 3.0) +
    geom_curve(
      data = data.frame(x = valve_x, y = 1.55, xend = valve_x, yend = 2.4),
      aes(x = x, y = y, xend = xend, yend = yend),
      curvature = 0.2, colour = "grey40", linewidth = 0.5,
      arrow = info_arrow
    ) +
    geom_curve(data = data.frame(x = 2.8, y = 2.0, xend = valve_x, yend = 2.35),
               aes(x = x, y = y, xend = xend, yend = yend),
               curvature = 0.45, colour = "grey40",
               arrow = info_arrow) +
    annotate("text", x = 4.5, y = 1.0, label = "B1  (-)", size = 3.8,
             colour = "#c0392b", fontface = "bold") +
    theme_void() +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.5, 4.5))
}
