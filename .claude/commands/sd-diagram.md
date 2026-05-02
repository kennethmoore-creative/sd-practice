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
   **R1 (+)** for reinforcing, red bold **B1 (-)** for balancing. Number loops if
   there are more than one of each type.

---

## Single source of truth: `R/` folder

Shape helpers and reusable diagram functions live in the `R/` folder.
**Always source rather than redefine:**

```r
source("R/sd-diagram-functions.R")       # from a root .R script
source("../R/sd-diagram-functions.R")    # from website-tutorials/*.qmd
```

| File | Contains |
|------|----------|
| `R/gg-helper-functions.R` | `make_cloud`, `make_ellipse` |
| `R/sd-diagram-functions.R` | `draw_pos_feedback`, `draw_neg_feedback_simple` (sources gg-helper-functions.R) |

**To add a new reusable diagram function:** add it to `R/sd-diagram-functions.R` first,
then source it. Never define a reusable function only inside a `.qmd` chunk or `.R` script.

---

## ggplot2 implementation pattern

For one-off diagrams not covered by an existing function, use these primitives.
Arrow styles should be defined locally within the new function or inline chunk:

```r
# Arrow styles
flow_arrow <- arrow(length = unit(0.44, "cm"), type = "closed")   # main flows
info_arrow <- arrow(length = unit(0.32, "cm"), type = "open")     # information links

# Stock (double-bordered rectangle)
annotate("rect", xmin=_, xmax=_, ymin=_, ymax=_,
         fill="white", colour="black", linewidth=1.6)           # outer border
annotate("rect", xmin=_+.12, xmax=_-.12, ymin=_+.12, ymax=_-.12,
         fill="#fafaf0", colour="black", linewidth=0.5)         # inner border
annotate("text", x=cx, y=cy, label="stock name", size=3.5, fontface="bold")

# Source / sink (cloud)
geom_polygon(data=make_cloud(cx, cy), aes(x,y),
             fill="white", colour="black", linewidth=0.7)

# Flow (thick coloured arrow + label)
annotate("segment", x=_, xend=_, y=_, yend=_,
         linewidth=2, colour="<colour>", arrow=flow_arrow)
annotate("text", x=mid_x, y=label_y, label="flow name", size=3.2, colour="<colour>")

# Auxiliary / converter (ellipse)
geom_polygon(data=make_ellipse(cx, cy), aes(x,y),
             fill="white", colour="grey50", linewidth=0.6)
annotate("text", x=cx, y=cy, label="concept name", size=3)

# Information link (solid arrow)
# Straight:
annotate("segment", x=_, xend=_, y=_, yend=_,
         linetype="solid", colour="grey40", arrow=info_arrow)
# Curved (choose curvature sign so the arc bows away from the loop centre):
geom_curve(aes(x=_, y=_, xend=_, yend=_),
           curvature=+/-0.3, linetype="solid", colour="grey40", arrow=info_arrow)

# Loop labels
annotate("text", x=_, y=_, label="R1  (+)", size=3.8, colour="#27ae60", fontface="bold")
annotate("text", x=_, y=_, label="B1  (-)", size=3.8, colour="#c0392b", fontface="bold")

# Canvas
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

## Existing reusable functions

### `draw_pos_feedback` — first-order positive feedback

One stock, one inflow, one parameter. Source cloud on left, stock on right, parameter
below the flow valve, feedback arc curving above back to valve. Loop label **R1 (+)**.

**Usage:** `draw_pos_feedback("Deer\nPopulation", "Births", "Birth\nFraction")`

---

### `draw_neg_feedback_simple` — first-order negative feedback (implicit goal = 0)

One stock, one outflow, one parameter. Stock on left, sink cloud on right, parameter
below the flow valve, feedback arc curving below back to valve. Loop label **B1 (-)**.
Use this for decay/death structures where the goal is implicitly zero.

**Usage:** `draw_neg_feedback_simple("Mule\nPopulation", "Death Rate", "Death\nFraction")`

For negative feedback with an **explicit goal** (e.g. company downsizing), add an
auxiliary ellipse for the gap and wire up two separate parameter labels — see
`website-tutorials/tut-03-first-order-negative-feedback.qmd` for the full inline pattern.
