library(knitr)
library(tidyverse)
library(ggrepel)
library(scales)
library(glue)
library(lpSolve)

load("sd-model-practice-scripts/data/dea_data_01.rda")
load("sd-model-practice-scripts/data/dea_base_results.rda")
load("sd-model-practice-scripts/data/optimise_dmu_output.rda")


# ── Review base DEA results ───────────────────────────────────────────────────

dea_base_results %>%
  mutate(value = round(value, 3)) %>%
  spread(key = "dmu", value = "value") %>%
  print()


# ── Prepare data for values analysis ─────────────────────────────────────────

# isolate value weights from DEA output
results_weights <- dea_base_results %>%
  filter(variable != "Optimal Efficiency") %>%
  mutate(variable = str_remove(variable, "Weight "),
         dmu = as.character(dmu)) %>%
  rename(opt_weight = value) %>%
  arrange(dmu, variable)

glimpse(results_weights)

# reshape initial data to long format and join with weights
dea_data_long <- dea_data_01 %>%
  pivot_longer(x_sqrft:y_certs, names_to = "variable", values_to = "value") %>%
  arrange(dmu, variable)

dea_all_data <- dea_data_long %>%
  left_join(results_weights) %>%
  separate(variable, c("type", "variable"), sep = "_")

glimpse(dea_all_data)


# ── Production function analysis ─────────────────────────────────────────────

# normalise weights so inputs sum to 100% and outputs sum to 100% per org
weight_emphasis <- dea_all_data %>%
  group_by(dmu, type) %>%
  mutate(emphasis = opt_weight / sum(opt_weight)) %>%
  ungroup() %>%
  select(-opt_weight, -value)

# view Org A
print(filter(weight_emphasis, dmu == "Org_A"))

# plot operating models for all orgs
plot_emphasis <- function(df) {
  df %>%
    ggplot(aes(x = variable, y = emphasis)) +
    geom_segment(aes(x = variable, xend = variable, y = 0, yend = emphasis),
                 color = "black", size = 0.5) +
    geom_point(aes(color = type), size = 3, shape = "circle") +
    coord_flip() +
    facet_wrap(~ dmu, scales = "free",
               labeller = labeller(dmu = function(x) paste(x, "Model", sep = " "))) +
    scale_color_discrete(labels = c("Inputs", "Outputs")) +
    scale_y_continuous(labels = function(x) scales::percent(x, accuracy = 1L),
                       breaks = c(0.5, 1),
                       limits = c(0, 1.1)) +
    theme(legend.title  = element_blank(),
          axis.title.y  = element_blank()) +
    labs(title = "Ideal operating models as identified by DEA",
         y     = "Emphasis for optimisation")
}

plot_emphasis(weight_emphasis)


# ── Recall optimal efficiency scores ─────────────────────────────────────────

dea_base_results %>%
  mutate(value = round(value, 3)) %>%
  spread(key = "dmu", value = "value") %>%
  filter(variable == "Optimal Efficiency") %>%
  print()


# ── Compute productivity under each org's value weighting scheme ──────────────

alt_scores <- function(org, df) {
  N <- length(unique(df$dmu))

  org_scheme <- df %>%
    filter(dmu == org) %>%
    .$opt_weight

  df %>%
    mutate(opt_weight = rep(org_scheme, N),
           scores     = value * opt_weight) %>%
    group_by(dmu, type) %>%
    summarise(index = sum(scores), .groups = "drop") %>%
    pivot_wider(names_from = type, values_from = index) %>%
    mutate(prod_index = y / x,
           scheme     = paste(org, "scheme", sep = "_")) %>%
    select(scheme, everything())
}

dmu_names <- unique(dea_all_data$dmu)
all_scores <- map_dfr(dmu_names, alt_scores, dea_all_data)

glimpse(all_scores)


# ── Efficiency matrix ─────────────────────────────────────────────────────────

efficiency_schemes_matrix <- all_scores %>%
  select(-c(x, y)) %>%
  group_by(scheme) %>%
  mutate(TE = prod_index / max(prod_index)) %>%
  ungroup() %>%
  mutate(TE     = round(TE, 2),
         scheme = str_replace_all(scheme, c(
           "Org_A_scheme" = "Scheme_A",
           "Org_B_scheme" = "Scheme_B",
           "Org_C_scheme" = "Scheme_C",
           "Org_D_scheme" = "Scheme_D",
           "Org_E_scheme" = "Scheme_E",
           "Org_F_scheme" = "Scheme_F"
         ))) %>%
  select(-prod_index) %>%
  pivot_wider(names_from = scheme, values_from = TE)

print(efficiency_schemes_matrix)


# ── Production frontier visualisation ────────────────────────────────────────

plot_frontiers <- function(sch, df) {
  data <- df %>%
    filter(scheme == sch) %>%
    mutate(TE = prod_index / max(prod_index))

  frontier_slope <- data %>%
    filter(TE == max(TE)) %>%
    filter(y  == max(y)) %>%
    mutate(slope = y / x) %>%
    .$slope

  data %>%
    ggplot(aes(x = x, y = y)) +
    geom_abline(intercept = 0, slope = frontier_slope,
                colour = "#94a3b8", linewidth = 0.8, linetype = "dashed") +
    geom_point(aes(fill = dmu), shape = 21, size = 4.5,
               colour = "white", stroke = 0.8) +
    geom_text_repel(
      aes(label = glue("{str_replace(dmu, '_', ' ')}\nTE = {round(TE, 2)}")),
      size           = 3.8,
      colour         = "grey30",
      lineheight     = 1.3,
      box.padding    = 0.6,
      point.padding  = 0.4,
      segment.colour = "grey60",
      segment.size   = 0.35
    ) +
    scale_fill_brewer(palette = "Set2") +
    scale_y_continuous(limits = c(min(data$y) - 0.2 * max(data$y),
                                  max(data$y) + 0.2 * max(data$y))) +
    scale_x_continuous(limits = c(min(data$x) - 0.2 * max(data$x),
                                  max(data$x) + 0.2 * max(data$x))) +
    theme_minimal(base_size = 14) +
    theme(
      legend.position  = "none",
      panel.grid.minor = element_blank(),
      axis.title       = element_text(size = 12, colour = "grey40"),
      plot.title       = element_text(face = "bold", size = 15)
    ) +
    labs(title = glue("Optimal Frontier — {str_replace_all(sch, '_', ' ')}"),
         y     = "Output index",
         x     = "Input index")
}

schemes_list   <- unique(all_scores$scheme)
frontier_plots <- map(schemes_list, plot_frontiers, all_scores)
names(frontier_plots) <- schemes_list

# view key schemes
frontier_plots$Org_C_scheme
frontier_plots$Org_D_scheme
frontier_plots$Org_B_scheme

ggsave(
  filename = "website-tutorials/assets/services-automation-optimisation.png",
  plot     = frontier_plots$Org_B_scheme,
  width    = 7,
  height   = 5,
  units    = "in",
  dpi      = 120,
  bg       = "white"
)

# ── Rerun DEA with minimum weight constraint ──────────────────────────────────

dea_base_results %>%
  mutate(value = round(value, 3)) %>%
  spread(key = "dmu", value = "value") %>%
  print()

dmu_indicies <- 1:nrow(dea_data_01)

dea_new_results <- map_dfr(dmu_indicies, optimise_dmu_output,
                            df         = dea_data_01,
                            min_weight = 0.001)

results_weights_new <- dea_new_results %>%
  filter(variable != "Optimal Efficiency") %>%
  mutate(variable = str_remove(variable, "Weight "),
         dmu      = as.character(dmu)) %>%
  rename(opt_weight = value) %>%
  arrange(dmu, variable)

dea_all_data_new <- dea_data_long %>%
  left_join(results_weights_new) %>%
  separate(variable, c("type", "variable"), sep = "_")

weight_emphasis_new <- dea_all_data_new %>%
  group_by(dmu, type) %>%
  mutate(emphasis = opt_weight / sum(opt_weight)) %>%
  ungroup() %>%
  select(-opt_weight, -value)

plot_emphasis(weight_emphasis_new)

# compute scores and plot frontiers under new weights
all_scores_new     <- map_dfr(dmu_names, alt_scores, dea_all_data_new)
frontier_plots_new <- map(schemes_list, plot_frontiers, all_scores_new)
names(frontier_plots_new) <- schemes_list

frontier_plots_new$Org_E_scheme
