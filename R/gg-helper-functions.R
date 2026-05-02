library(tidyverse)

# Bumpy cloud shape used as a source/sink symbol in SD stock-and-flow diagrams.
# cx, cy: centre coordinates; w, h: half-width and half-height of the envelope.
make_cloud <- function(cx, cy, w = 0.45, h = 0.28) {
  theta <- seq(0, 2 * pi, length.out = 200)
  bump  <- 1 + 0.12 * sin(8 * theta)
  tibble(x = cx + w * bump * cos(theta), y = cy + h * bump * sin(theta))
}

# Ellipse shape used as an auxiliary/converter symbol in SD diagrams.
# cx, cy: centre coordinates; rx, ry: x and y radii.
make_ellipse <- function(cx, cy, rx = 1.4, ry = 0.42) {
  theta <- seq(0, 2 * pi, length.out = 100)
  tibble(x = cx + rx * cos(theta), y = cy + ry * sin(theta))
}
