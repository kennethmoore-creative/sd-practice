library(tidyverse)
if (file.exists("R/gg-helper-functions.R")) {
  source("R/gg-helper-functions.R")
} else {
  source("../R/gg-helper-functions.R")
}

# Draws a generic first-order positive feedback stock-and-flow diagram.
# stock_label: text inside the stock rectangle
# flow_label:  text above the inflow arrow
# param_label: text at the compounding fraction information link
draw_pos_feedback <- function(stock_label, flow_label, param_label) {
  flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")
  info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")

  ggplot() +
    geom_polygon(data = make_cloud(1.2, 2.5), aes(x, y),
                 fill = "white", colour = "black", linewidth = 0.7) +
    annotate("segment", x = 1.65, xend = 4.8, y = 2.5, yend = 2.5,
             linewidth = 2, colour = "#4e8cd4", arrow = flow_arrow) +
    annotate("text", x = 3.1, y = 3.05, label = flow_label,
             size = 3.2, colour = "#4e8cd4") +
    annotate("rect", xmin = 4.8, xmax = 8.8, ymin = 2.0, ymax = 3.0,
             fill = "white", colour = "black", linewidth = 1.6) +
    annotate("rect", xmin = 4.92, xmax = 8.68, ymin = 2.12, ymax = 2.88,
             fill = "#fafaf0", colour = "black", linewidth = 0.5) +
    annotate("text", x = 6.8, y = 2.5, label = stock_label,
             size = 3.5, fontface = "bold") +
    annotate("text", x = 3.2, y = 1.3, label = param_label, size = 3.0) +
    annotate("segment", x = 3.2, xend = 3.2, y = 1.55, yend = 2.42,
             linetype = "solid", colour = "grey40", arrow = info_arrow) +
    geom_curve(data = data.frame(x = 6.8, y = 3.0, xend = 3.2, yend = 2.65),
               aes(x = x, y = y, xend = xend, yend = yend),
               curvature = 0.45, linetype = "solid", colour = "grey40",
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
  info_arrow <- arrow(length = unit(0.32, "cm"), type = "open")

  ggplot() +
    annotate("rect", xmin = 0.8, xmax = 4.8, ymin = 2.0, ymax = 3.0,
             fill = "white", colour = "black", linewidth = 1.6) +
    annotate("rect", xmin = 0.92, xmax = 4.68, ymin = 2.12, ymax = 2.88,
             fill = "#fafaf0", colour = "black", linewidth = 0.5) +
    annotate("text", x = 2.8, y = 2.5, label = stock_label,
             size = 3.5, fontface = "bold") +
    annotate("segment", x = 4.8, xend = 7.8, y = 2.5, yend = 2.5,
             linewidth = 2, colour = "#d45b4e", arrow = flow_arrow) +
    annotate("text", x = 6.3, y = 2.95, label = flow_label,
             size = 3.2, colour = "#d45b4e") +
    geom_polygon(data = make_cloud(8.5, 2.5), aes(x, y),
                 fill = "white", colour = "black", linewidth = 0.7) +
    annotate("text", x = 6.3, y = 1.3, label = param_label, size = 3.0) +
    annotate("segment", x = 6.3, xend = 6.3, y = 1.55, yend = 2.42,
             linetype = "solid", colour = "grey40", arrow = info_arrow) +
    geom_curve(data = data.frame(x = 2.8, y = 2.0, xend = 6.3, yend = 2.35),
               aes(x = x, y = y, xend = xend, yend = yend),
               curvature = 0.45, linetype = "solid", colour = "grey40",
               arrow = info_arrow) +
    annotate("text", x = 4.5, y = 1.0, label = "B1  (-)", size = 3.8,
             colour = "#c0392b", fontface = "bold") +
    theme_void() +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.5, 4.5))
}
