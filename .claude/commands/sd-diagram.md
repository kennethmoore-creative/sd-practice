# SD Stock-and-Flow Diagram (ggplot2)

Draw a stock-and-flow diagram for a system dynamics model using ggplot2.
The diagram is a **storytelling tool**, not a formal model specification.
Its job is to build intuition before the reader encounters the code.

## Design principles

1. **Always include stock-and-flow elements** — double-bordered rectangle for each stock,
   cloud polygons for sources/sinks, thick arrows for flows.

2. **Include all variables needed to close the critical feedback loops** — trace every
   loop that drives the model's key behavior and include each node in that chain
   (stocks, auxiliaries, calculated values). Use plain conceptual language for labels,
   not R variable names (e.g. "population density", not `a_normalized_density`).

3. **Discard marginal parameters** — omit input parameters that only set baseline rates
   or scale values without fundamentally changing model behavior. Keep the diagram
   uncluttered.

4. **Orient arrows to make loops visually apparent** — use `geom_curve()` with a
   curvature sign chosen so each feedback arc bows *outward* from the loop centre,
   helping the reader's eye trace the circle.

5. **Label every feedback loop** — annotate each loop with its polarity: green bold
   **R1 (+)** for reinforcing, red bold **B1 (−)** for balancing. Number loops if
   there are more than one of each type.

---

## ggplot2 implementation pattern

```r
# ── Shape helpers ──────────────────────────────────────────────────────────────
make_cloud <- function(cx, cy, w = 0.45, h = 0.28) {
  theta <- seq(0, 2 * pi, length.out = 200)
  bump  <- 1 + 0.12 * sin(8 * theta)
  tibble(x = cx + w * bump * cos(theta), y = cy + h * bump * sin(theta))
}
make_ellipse <- function(cx, cy, rx = 1.6, ry = 0.35) {
  theta <- seq(0, 2 * pi, length.out = 100)
  tibble(x = cx + rx * cos(theta), y = cy + ry * sin(theta))
}

# ── Arrow styles ───────────────────────────────────────────────────────────────
flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")   # main flows
info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")     # information links

# ── Stock (double-bordered rectangle) ─────────────────────────────────────────
annotate("rect", xmin=_, xmax=_, ymin=_, ymax=_,
         fill="white", colour="black", linewidth=1.6)           # outer border
annotate("rect", xmin=_+.12, xmax=_-.12, ymin=_+.12, ymax=_-.12,
         fill="#fafaf0", colour="black", linewidth=0.5)         # inner border
annotate("text", x=cx, y=cy, label="stock name", size=3.5, fontface="bold")

# ── Source / sink (cloud) ─────────────────────────────────────────────────────
geom_polygon(data=make_cloud(cx, cy), aes(x,y),
             fill="white", colour="black", linewidth=0.7)

# ── Flow (thick coloured arrow + label) ───────────────────────────────────────
annotate("segment", x=_, xend=_, y=_, yend=_,
         linewidth=2, colour="<colour>", arrow=flow_arrow)
annotate("text", x=mid_x, y=label_y, label="flow name", size=3.2, colour="<colour>")

# ── Auxiliary / converter (ellipse) ───────────────────────────────────────────
geom_polygon(data=make_ellipse(cx, cy), aes(x,y),
             fill="white", colour="grey50", linewidth=0.6)
annotate("text", x=cx, y=cy, label="concept name", size=3)

# ── Information link (solid arrow) ────────────────────────────────────────────
# Straight:
annotate("segment", x=_, xend=_, y=_, yend=_,
         linetype="solid", colour="grey40", arrow=info_arrow)
# Curved (choose curvature sign so the arc bows away from the loop centre):
geom_curve(aes(x=_, y=_, xend=_, yend=_),
           curvature=±0.3, linetype="solid", colour="grey40", arrow=info_arrow)

# ── Loop labels ────────────────────────────────────────────────────────────────
annotate("text", x=_, y=_, label="R1  (+)", size=3.8, colour="#27ae60", fontface="bold")
annotate("text", x=_, y=_, label="B1  (−)", size=3.8, colour="#c0392b", fontface="bold")

# ── Canvas ─────────────────────────────────────────────────────────────────────
theme_void() +
coord_cartesian(xlim=c(0, 11), ylim=c(0.3, 5.1)) +
labs(title="Model name — stock-and-flow diagram")
```

## Connecting arrows to shape boundaries

When connecting a straight segment to an ellipse, terminate at the boundary, not the centre:
- Top:    `yend = cy + ry`
- Bottom: `yend = cy - ry`
- Right:  `xend = cx + rx`
- Left:   `xend = cx - rx`

For the double-bordered stock rectangle, connect flows and info links to the **outer** border edges.

## Colour conventions

| Element | Colour |
|---|---|
| Inflow (births, growth) | `#4e8cd4` (blue) |
| Outflow (deaths, loss)  | `#d45b4e` (red)  |
| Information links       | `grey40` solid   |
| Reinforcing loop label  | `#27ae60` (green) bold |
| Balancing loop label    | `#c0392b` (red) bold |
| Stock fill              | `#fafaf0` (off-white) |
| Auxiliary fill          | `white` |

---

## Reusable diagram functions

These functions cover the two most common first-order structures. Paste them into the
setup chunk alongside `make_cloud`, `flow_arrow`, and `info_arrow`.

### `draw_pos_feedback` — first-order positive feedback

One stock, one inflow, one parameter. Source cloud on left, stock on right, parameter
below the flow valve, feedback arc curving above back to valve. Loop label **R1 (+)**.

```r
draw_pos_feedback <- function(stock_label, flow_label, param_label) {
  ggplot() +
    geom_polygon(data = make_cloud(1.2, 2.5), aes(x, y),
                 fill = "white", colour = "black", linewidth = 0.7) +
    annotate("segment", x = 1.65, xend = 4.8, y = 2.5, yend = 2.5,
             linewidth = 2, colour = "#4e8cd4", arrow = flow_arrow) +
    annotate("text", x = 3.2, y = 2.95, label = flow_label,
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
    geom_curve(data = data.frame(x = 6.8, y = 3.0, xend = 3.2, yend = 2.35),
               aes(x = x, y = y, xend = xend, yend = yend),
               curvature = 0.45, linetype = "dashed", colour = "grey40",
               arrow = info_arrow) +
    annotate("text", x = 5.0, y = 1.7, label = "R1  (+)", size = 3.8,
             colour = "#27ae60", fontface = "bold") +
    theme_void() +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.5, 4.5))
}
```

**Usage:** `draw_pos_feedback("Deer\nPopulation", "Births", "Birth\nFraction")`

---

### `draw_neg_feedback_simple` — first-order negative feedback (implicit goal = 0)

One stock, one outflow, one parameter. Stock on left, sink cloud on right, parameter
below the flow valve, feedback arc curving below back to valve. Loop label **B1 (−)**.
Use this for decay/death structures where the goal is implicitly zero.

```r
draw_neg_feedback_simple <- function(stock_label, flow_label, param_label) {
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
               curvature = 0.45, linetype = "dashed", colour = "grey40",
               arrow = info_arrow) +
    annotate("text", x = 4.5, y = 1.0, label = "B1  (-)", size = 3.8,
             colour = "#c0392b", fontface = "bold") +
    theme_void() +
    coord_cartesian(xlim = c(0, 10), ylim = c(0.5, 4.5))
}
```

**Usage:** `draw_neg_feedback_simple("Mule\nPopulation", "Death Rate", "Death\nFraction")`

For negative feedback with an **explicit goal** (e.g. company downsizing), add an
auxiliary ellipse for the gap and wire up two separate parameter labels — see
`website-tutorials/first-order-negative-feedback.qmd` for the full inline pattern.
