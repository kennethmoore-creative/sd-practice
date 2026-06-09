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
info_arrow <- arrow(length = unit(0.26, "cm"), type = "open")     # information links

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

# Auxiliary / converter (bold plain text — no ellipse)
annotate("text", x=cx, y=cy, label="concept name", size=3, fontface="bold")

# Information link (solid arrow)
# Straight:
annotate("segment", x=_, xend=_, y=_, yend=_,
         colour="grey40", arrow=info_arrow)
# Curved (choose curvature sign so the arc bows away from the loop centre):
geom_curve(data=data.frame(x=_, y=_, xend=_, yend=_),
           aes(x=x, y=y, xend=xend, yend=yend),
           curvature=+/-0.3, colour="grey40", linewidth=0.5, arrow=info_arrow)

# IMPORTANT — arrows must not criss-cross at a valve:
# Each arrow must START and END on the same side of the valve.
# • An arrow coming from the LEFT  → xend = valve_x - 0.1
# • An arrow coming from the RIGHT → xend = valve_x + 0.1
# Mixing sides (starting right, ending left) causes arrows to cross each other.

# IMPORTANT — never draw an arrow through text:
# Stop the arrowhead at the near edge of any label it would otherwise cross.
# • Arrow arriving from ABOVE a flow label (label_y ≈ 3.65):  yend ~ label_y + 0.25
# • Arrow arriving from BELOW a flow label (label_y ≈ 2.38):  yend ~ label_y - 0.20
# Apply the same logic for any other text the arrow path crosses.

# IMPORTANT — prefer geom_curve over annotate("segment") for info links:
# Use annotate("segment") ONLY when elements are stacked directly above/below
# each other (e.g. a vertical auxiliary chain). Even near-vertical connectors
# (e.g. an auxiliary node just below a valve) should use geom_curve — a slight
# bow separates the arrowhead cleanly from the surrounding text.

# Loop labels
annotate("text", x=_, y=_, label="R1  (+)", size=3.8, colour="#27ae60", fontface="bold")
annotate("text", x=_, y=_, label="B1  (-)", size=3.8, colour="#c0392b", fontface="bold")

# Canvas
theme_void() +
coord_cartesian(xlim=c(0, 11), ylim=c(0.3, 5.1)) +
labs(title="Model name — stock-and-flow diagram")
```

## Connecting arrows to stock boundaries

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

For negative feedback with an **explicit goal** (e.g. company downsizing), add a
bold auxiliary text label for the gap and wire up two separate parameter labels — see
`website-tutorials/tut-03-first-order-negative-feedback.qmd` for the full inline pattern.

---

## Single-stock S-shaped growth layout

Reference files: `sd-model-practice-scripts/s1_rabbit_diagram.R` and
`website-tutorials/tut-05-s-shaped-growth.qmd`.

**When to use:** one stock, one inflow (positive/reinforcing loop), one outflow driven
by a density-dependent multiplier (negative/balancing loop). Two competing feedback loops
produce S-shaped growth.

### Canvas
`fig-width=9`, `fig-height=4.5`, `xlim=c(0,11)`, `ylim=c(0.3,5.1)`

### Horizontal flow line at `y=4`

```
source cloud → births inflow → [stock] → deaths outflow → sink cloud
               valve at x=2.55          valve at x=8.45
```

Stock: `xmin=3.85`, `xmax=7.15`, center `(5.5, 4.0)`. Declare two named valve pairs:

```r
births_valve_x <- 2.55;  births_valve_y <- 4.0
deaths_valve_x <- 8.45;  deaths_valve_y <- 4.0
```

### Vertical auxiliary chain at `x=5.5` (below stock)

| y    | Element | Style |
|------|---------|-------|
| 2.75 | population density | bold text |
| 1.85 | normalized density | bold text |
| 0.95 | deaths multiplier  | bold text |
| 0.62 | (empirical lookup) | italic, `colour="grey40"`, `size=2.5` |

Links along this chain: `annotate("segment")` straight down — elements are stacked
directly above each other and a curve cannot render cleanly here.

### Parameters and their info links

| Label | Position | Link target | `geom_curve` curvature |
|-------|----------|-------------|------------------------|
| births normal    | `(1.5, 2.6)`   | births valve       | `–0.3` |
| average lifetime | `(9.1, 2.6)`   | deaths valve       | `+0.3` |
| area             | `(2.9, 2.15)`  | population density | `–0.2` |
| normal pop density | `(2.9, 1.3)` | normalized density | `–0.2` |

**Long parameter labels on the right side:** if the label text is wider than "average\nlifetime" (e.g. "baseline average\nlifetime"), push the x position to ≥ 10 to avoid crowding any auxiliary nodes in the x=7.5–9 zone. The info arrow origin moves with it.

### Intermediate auxiliary nodes

When the model inserts a calculated converter between a chain terminus and a valve (e.g. `effective lifetime` sitting between `deaths multiplier` and the dying valve), place the node at approximately `(8.2, y)` on the right side. Its two connectors:

- **Chain → auxiliary**: `geom_curve`, curvature chosen to bow away from the centre
- **Auxiliary → valve**: `geom_curve` (not `annotate("segment")`), slight curvature so the arrowhead arrives cleanly without passing through the valve label text

### Feedback arcs (loop-closing info links)

- **R1**: `geom_curve` from `(4.5, 3.45)` to `(2.1, births_valve_y–0.12)`, `curvature=–0.38`
- **B1**: `geom_curve` from `(6.3, 0.95)` to `(deaths_valve_x, deaths_valve_y–0.12)`, `curvature=+0.25`

### Loop labels

Default positions work when the diagram is uncluttered:

- `R1  (+)` at `(2.7, 2.9)` — `colour="#27ae60"`, `fontface="bold"`, `size=3.8`
- `B1  (−)` at `(9.3, 2.1)` — `colour="#c0392b"`, `fontface="bold"`, `size=3.8`

**Crowding rule:** loop labels must sit in clear white space, not inside a node cluster. When auxiliary nodes or long parameter labels fill the right side (x > 7.5), move B1 leftward into open space (e.g. x ≈ 7–7.5) and adjust y so it does not overlap R1. Similarly, if R1's default position is near a shifted B1, move R1 upward (e.g. y ≈ 3.3).
