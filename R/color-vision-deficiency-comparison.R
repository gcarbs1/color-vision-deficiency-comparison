# One palette, four ways of seeing it
#
# Draws the same streamgraph four times: with the original palette and as
# simulated for protanopia, deuteranopia and tritanopia. Under each panel, a
# strip shows the four simulated colours and the closest pair, measured with
# CIEDE2000 (ΔE). One landscape chart (16:10, 32 × 20 cm at 300 dpi) in
# `viz/`. Run from the project root:
#
#   Rscript R/color-vision-deficiency-comparison.R

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(ggplot2)
  library(ggstream)
  library(ggtext)
  library(marquee)
  library(patchwork)
  library(systemfonts)
  library(colorspace)
  library(farver)
})

if (!file.exists("R/color-vision-deficiency-comparison.R")) {
  stop("Run the script from the project root.")
}

author <- "Gabriel Carbinatto"
width_cm <- 32
height_cm <- 20
dir.create("viz", showWarnings = FALSE)


# 1. Fonts, palette and helpers ------------------------------------------------

font_dir <- file.path("assets", "fonts")
register_font(
  "Libre Baskerville",
  plain = file.path(font_dir, "LibreBaskerville-Regular.ttf"),
  bold = file.path(font_dir, "LibreBaskerville-Bold.ttf"),
  italic = file.path(font_dir, "LibreBaskerville-Italic.ttf")
)
serif <- "Libre Baskerville"

ui <- list(background = "#FFFFFF", ink = "#111111", muted = "#6B6B6B")

# The `suffrager::CarolMan` palette (paletteer), one colour per group. The
# names are how the text refers to each colour.
palette <- c(red = "#EE2617", orange = "#F2A241", green = "#558934",
             blue = "#0E54B6")
groups <- c(groupA = "red", groupB = "orange", groupC = "green",
            groupD = "blue")

text_style <- function(align = "justified-left", lineheight = 1.35) {
  classic_style(body_font = serif, lineheight = lineheight) |>
    modify_style("p", align = align, lineheight = lineheight,
                 margin = trbl(0))
}


# 2. Simulations ---------------------------------------------------------------

# Full severity (dichromacy) with the Machado, Oliveira and Fernandes (2009)
# model implemented in colorspace.
views <- tribble(
  ~view,          ~title,                        ~cones,
  "none",         "No colour vision deficiency", "All three cone types send a colour signal.",
  "protanopia",   "Protanopia",                  "No signal from the L cones, sensitive to long wavelengths (red).",
  "deuteranopia", "Deuteranopia",                "No signal from the M cones, sensitive to medium wavelengths (green).",
  "tritanopia",   "Tritanopia",                  "No signal from the S cones, sensitive to short wavelengths (blue)."
)

simulate <- function(colours, view) {
  simulated <- switch(view,
    none = colours,
    protanopia = protan(colours, severity = 1),
    deuteranopia = deutan(colours, severity = 1),
    tritanopia = tritan(colours, severity = 1)
  )
  set_names(simulated, names(colours))
}

# Smallest CIEDE2000 difference between any two of the four colours.
closest_pair <- function(colours) {
  lab <- decode_colour(colours)
  distance <- compare_colour(lab, lab, from_space = "rgb", method = "cie2000")
  distance[lower.tri(distance, diag = TRUE)] <- NA
  at <- which(distance == min(distance, na.rm = TRUE), arr.ind = TRUE)[1, ]
  tibble(first = names(colours)[at[1]], second = names(colours)[at[2]],
         delta_e = distance[at[1], at[2]])
}

views <- views |>
  mutate(
    colours = map(view, \(v) simulate(palette, v)),
    pair = map(colours, closest_pair)
  ) |>
  tidyr::unnest_wider(pair)

baseline <- filter(views, view == "none")


# 3. Panels --------------------------------------------------------------------

stream <- read_csv("data/processed/stream.csv", show_col_types = FALSE)

stream_panel <- function(colours, title, cones) {
  fills <- set_names(unname(colours[groups]), names(groups))
  ggplot(stream, aes(x = year, y = value, fill = name)) +
    geom_stream(color = ui$background, linewidth = 0.45, bw = 0.75) +
    scale_fill_manual(values = fills, guide = "none") +
    scale_x_continuous(expand = expansion(0)) +
    scale_y_continuous(expand = expansion(0)) +
    labs(title = str_glue("**{title}**"), subtitle = cones) +
    theme_void(base_family = serif) +
    theme(
      plot.title = element_markdown(family = serif, size = 13,
                                    color = ui$ink, margin = margin(b = 4)),
      plot.subtitle = element_text(family = serif, size = 9.2,
                                   color = ui$muted, margin = margin(b = 6)),
      plot.title.position = "plot"
    )
}

# Four swatches with their hex codes and, at the right, the closest pair.
swatch_strip <- function(colours, first, second, delta_e) {
  swatches <- tibble(
    x = seq_along(colours),
    fill = unname(colours),
    hex = toupper(unname(colours)),
    text = if_else(contrast_ratio(unname(colours), "#FFFFFF") >=
                     contrast_ratio(unname(colours), "#111111"),
                   "#FFFFFF", "#111111")
  )
  note <- str_glue("Closest pair: **{first}** and **{second}**, ",
                   "ΔE {format(round(delta_e, 1), nsmall = 1)}")
  ggplot(swatches) +
    geom_tile(aes(x = x, y = 0, fill = fill), width = 0.96, height = 1) +
    geom_text(aes(x = x, y = 0, label = hex, color = text),
              family = serif, size = 2.9) +
    annotate("richtext", x = 8.6, y = 0, label = note, hjust = 1,
             family = serif, size = 3.2, color = ui$ink, fill = NA,
             label.color = NA, label.padding = unit(0, "pt")) +
    scale_fill_identity() +
    scale_color_identity() +
    scale_x_continuous(limits = c(0.5, 8.6), expand = expansion(0)) +
    coord_cartesian(clip = "off") +
    theme_void()
}

panel <- function(row) {
  stream_panel(row$colours[[1]], row$title, row$cones) /
    swatch_strip(row$colours[[1]], row$first, row$second, row$delta_e) +
    plot_layout(heights = c(1, 0.13))
}

panels <- map(seq_len(nrow(views)), \(i) panel(views[i, ]))


# 4. Text and layout -----------------------------------------------------------

worst <- slice_min(filter(views, view != "none"), delta_e, n = 1)
red_green <- compare_colour(decode_colour(palette["red"]),
                            decode_colour(palette["green"]),
                            from_space = "rgb", method = "cie2000")[1, 1]

subtitle <- str_glue(
  "The same streamgraph with typical colour vision and as simulated for ",
  "the three dichromacies, in which one type of cone gives no colour ",
  "signal. Under each panel, ΔE (CIEDE2000) measures the two closest ",
  "colours: the lower it is, the harder they are to tell apart. Red and ",
  "green, **ΔE {round(red_green, 1)}** apart in the original palette, fall ",
  "to **ΔE {round(worst$delta_e, 1)}** in {str_to_lower(worst$title)}."
)

footnote <- str_glue(
  "**Data**: stream.csv example dataset, R Graph Gallery. ",
  "Palette: CarolMan, from the suffrager package

",
  "**Note**: full-severity simulations (Machado, Oliveira and Fernandes, ",
  "2009, in colorspace) approximate typical colour confusions, not each ",
  "person's perception."
)

footer <- ggplot() +
  annotate("marquee", x = 0, y = 0, label = footnote, hjust = 0, vjust = 0,
           size = 3, colour = ui$ink, family = serif, lineheight = 1,
           width = unit(25, "cm"), style = text_style("left", 1.3)) +
  annotate("text", x = 1, y = 0, label = author, hjust = 1, vjust = 0,
           family = serif, fontface = "bold", size = 3, color = ui$ink) +
  scale_x_continuous(limits = c(0, 1), expand = expansion(0)) +
  scale_y_continuous(limits = c(0, 1), expand = expansion(0)) +
  coord_cartesian(clip = "off") +
  theme_void() +
  theme(plot.margin = margin(t = 18))

# A blank column keeps the two columns of panels apart.
grid <- wrap_plots(panels[[1]], plot_spacer(), panels[[2]],
                   panels[[3]], plot_spacer(), panels[[4]],
                   ncol = 3, widths = c(1, 0.07, 1)) &
  theme(plot.margin = margin(6, 2.6, 12, 2.6))

chart <- wrap_elements(full = grid) / footer +
  plot_layout(heights = c(1, 0.04)) +
  plot_annotation(
    title = "One palette, four ways of seeing it",
    subtitle = subtitle,
    theme = theme(
      plot.background = element_rect(fill = ui$background, color = NA),
      plot.title = element_text(family = serif, size = 27, color = ui$ink,
                                margin = margin(b = 12)),
      plot.subtitle = element_marquee(
        family = serif, size = 12, colour = ui$muted, lineheight = 1,
        width = unit(1, "npc"), margin = margin(b = 14),
        style = text_style("justified-left", 1.5)
      ),
      plot.margin = margin(32, 40, 26, 40)
    )
  )

ggsave("viz/color-vision-deficiency-comparison.png", chart,
       width = width_cm, height = height_cm, units = "cm", dpi = 300,
       device = ragg::agg_png, bg = ui$background)
