# Through four eyes
#
# A streamgraph of four groups, wrapped into a ring around a pupil so that
# it reads as an iris, drawn four times: with no colour vision deficiency
# and as simulated for protanopia, deuteranopia and tritanopia. Under each
# eye, the four colours as seen and the closest pair, measured with the
# CIEDE2000 colour difference (ΔE).
#
# One landscape chart (16:10, 32 × 20 cm at 300 dpi) in `viz/`. Run from
# the project root:
#
#   Rscript R/color-vision-deficiency-comparison.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(ggplot2)
  library(ggtext)
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
set.seed(7)


# 1. Fonts and palette ---------------------------------------------------------

font_dir <- file.path("assets", "fonts")
register_font("Instrument Serif",
              plain = file.path(font_dir, "InstrumentSerif-Regular.ttf"),
              italic = file.path(font_dir, "InstrumentSerif-Italic.ttf"))
register_font("IBM Plex Mono",
              plain = file.path(font_dir, "IBMPlexMono-Regular.ttf"),
              bold = file.path(font_dir, "IBMPlexMono-Medium.ttf"))
register_font("IBM Plex Mono Light",
              plain = file.path(font_dir, "IBMPlexMono-Light.ttf"))
serif <- "Instrument Serif"
mono <- "IBM Plex Mono"
mono_light <- "IBM Plex Mono Light"

ui <- list(
  night = "#0C0C0E",
  ink = "#EDE9E1",
  muted = "#8F8B84",
  rule = "#3A3936",
  pupil = "#030303"
)

# The `suffrager::CarolMan` palette (paletteer). Names are how the text
# refers to each colour.
palette <- c(red = "#EE2617", orange = "#F2A241", green = "#558934",
             blue = "#0E54B6")
groups <- c(groupA = "red", groupB = "orange", groupC = "green",
            groupD = "blue")


# 2. Simulations and colour differences ----------------------------------------

# Full severity (dichromacy) with the Machado, Oliveira and Fernandes (2009)
# model implemented in colorspace.
views <- tribble(
  ~view,          ~title,                        ~cones,
  "none",         "No colour vision deficiency", "L, M and S cones",
  "protanopia",   "Protanopia",                  "no L cones · long, red",
  "deuteranopia", "Deuteranopia",                "no M cones · medium, green",
  "tritanopia",   "Tritanopia",                  "no S cones · short, blue"
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

delta_e <- function(a, b) {
  compare_colour(decode_colour(a), decode_colour(b), from_space = "rgb",
                 method = "cie2000")[1, 1]
}

# Smallest CIEDE2000 difference between any two of the four colours.
closest_pair <- function(colours) {
  pairs <- combn(names(colours), 2, simplify = FALSE)
  map_dfr(pairs, \(p) tibble(first = p[1], second = p[2],
                             delta_e = delta_e(colours[p[1]],
                                               colours[p[2]]))) |>
    slice_min(delta_e, n = 1, with_ties = FALSE)
}

views <- views |>
  mutate(
    colours = map(view, \(v) simulate(palette, v)),
    pair = map(colours, closest_pair),
    centre_x = (row_number() - 1) * 2.75
  ) |>
  unnest_wider(pair)


# 3. The iris: a cyclic streamgraph in polar coordinates -----------------------

stream <- read_csv("data/processed/stream.csv", show_col_types = FALSE)

# Each group is smoothed with a periodic spline, so the last period joins
# the first and the ring closes. Layers are stacked symmetrically around
# zero, as in a streamgraph.
n_angles <- 360
theta <- seq(0, 2 * pi, length.out = n_angles + 1)
smooth_group <- function(values) {
  s <- spline(seq_along(c(values, values[1])), c(values, values[1]),
              method = "periodic", n = n_angles + 1)
  pmax(s$y, 0.4)
}

layers <- stream |>
  arrange(name, year) |>
  group_by(name) |>
  summarise(value = list(smooth_group(value)), .groups = "drop") |>
  arrange(desc(name))                 # groupD at the pupil, groupA outside

thickness <- do.call(cbind, layers$value)
total <- rowSums(thickness)
upper <- t(apply(thickness, 1, cumsum)) - total / 2
lower <- upper - thickness

# Radii: the stream's centre line sits at `r_mid`; its spread fills the
# iris between the pupil and the limbus.
r_pupil <- 0.30
r_outer <- 1
r_mid <- 0.66
radial_scale <- (r_outer - r_mid) / max(total / 2) * 0.97

iris_layers <- map_dfr(seq_len(nrow(layers)), function(i) {
  r_top <- r_mid + upper[, i] * radial_scale
  r_bottom <- r_mid + lower[, i] * radial_scale
  tibble(
    name = layers$name[i],
    angle = c(theta, rev(theta)),
    r = c(r_top, rev(r_bottom))
  )
}) |>
  mutate(x = r * sin(angle), y = r * cos(angle))

# The stream's inner edge, used to fill the gap down to the pupil with a
# dark tone of the innermost colour, like the zone around a real pupil.
inner_edge <- tibble(angle = theta,
                     r = r_mid + lower[, 1] * radial_scale)

# Fibres: thin radial strokes, a little irregular, over the colour.
n_fibres <- 420
fibres <- tibble(
  id = seq_len(n_fibres),
  angle = runif(n_fibres, 0, 2 * pi),
  r0 = r_pupil + runif(n_fibres, 0, 0.05),
  r1 = r_outer - runif(n_fibres, 0, 0.18),
  tone = sample(c("#000000", "#FFFFFF"), n_fibres, TRUE, prob = c(0.7, 0.3)),
  alpha = runif(n_fibres, 0.05, 0.16),
  bend = runif(n_fibres, -0.05, 0.05)
)
fibre_paths <- fibres |>
  mutate(step = list(seq(0, 1, length.out = 6))) |>
  unnest(step) |>
  mutate(r = r0 + (r1 - r0) * step,
         a = angle + bend * sin(step * pi),
         x = r * sin(a), y = r * cos(a))

circle <- function(r, n = 240, cx = 0, cy = 0) {
  a <- seq(0, 2 * pi, length.out = n)
  tibble(x = cx + r * sin(a), y = cy + r * cos(a))
}

collar <- bind_rows(
  tibble(angle = theta, r = r_pupil),
  tibble(angle = rev(inner_edge$angle), r = rev(inner_edge$r))
) |> mutate(x = r * sin(angle), y = r * cos(angle))

base_radii <- seq(r_outer, r_pupil, length.out = 36)
base_tone <- function(fills, k) {
  inner <- darken(fills[["groupD"]], 0.45)
  outer <- darken(fills[["groupA"]], 0.62)
  share <- (base_radii[k] - r_pupil) / (r_outer - r_pupil)
  hex(mixcolor(share, hex2RGB(inner), hex2RGB(outer)))
}

draw_eye <- function(colours, cx) {
  fills <- set_names(unname(colours[groups]), names(groups))
  shift <- function(d) mutate(d, x = x + cx)
  list(
    # Soft glow behind the eye.
    map(seq(1.32, 1.04, length.out = 8), \(r)
      geom_polygon(data = shift(circle(r)), aes(x, y),
                   fill = fills[["groupB"]], alpha = 0.018)),
    # Base of the iris: dark tones of the innermost and outermost colours,
    # blended from the pupil to the limbus, under the stream.
    map(seq_along(base_radii), \(k)
      geom_polygon(data = shift(circle(base_radii[k])), aes(x, y),
                   fill = base_tone(fills, k))),
    geom_polygon(data = shift(mutate(iris_layers, fill = fills[name])),
                 aes(x, y, group = name, fill = fill), color = NA),
    geom_path(data = shift(fibre_paths),
              aes(x, y, group = id, color = tone, alpha = alpha),
              linewidth = 0.16),
    # Limbal ring: a dark edge that fades inwards.
    map(seq(0, 0.06, length.out = 7), \(d)
      geom_path(data = shift(circle(r_outer - d)), aes(x, y),
                color = "#000000", alpha = 0.16, linewidth = 0.9)),
    geom_path(data = shift(circle(r_outer)), aes(x, y),
              color = "#000000", linewidth = 1.1),
    # Pupil and catchlight.
    geom_polygon(data = shift(circle(r_pupil)), aes(x, y), fill = ui$pupil),
    geom_polygon(data = shift(circle(0.075, cx = -0.13, cy = 0.13)),
                 aes(x, y), fill = "#FFFFFF", alpha = 0.85),
    geom_polygon(data = shift(circle(0.03, cx = 0.1, cy = -0.08)),
                 aes(x, y), fill = "#FFFFFF", alpha = 0.45)
  )
}

eyes <- map2(views$colours, views$centre_x, draw_eye)


# 4. Labels under each eye -----------------------------------------------------

label_y <- -1.32
swatch_y <- label_y - 0.62
meter_y <- swatch_y - 0.42
meter_max <- 65
meter_width <- 1.7

swatches <- views |>
  select(view, centre_x, colours) |>
  mutate(colours = map(colours, \(c) tibble(colour = names(c),
                                             hex = unname(c),
                                             k = seq_along(c)))) |>
  unnest(colours) |>
  mutate(x = centre_x + (k - 2.5) * 0.44)

baseline <- filter(views, view == "none")
meters <- views |>
  mutate(
    x0 = centre_x - meter_width / 2,
    x1 = centre_x + meter_width / 2,
    marker = x0 + pmin(delta_e, meter_max) / meter_max * meter_width,
    reference = x0 + baseline$delta_e / meter_max * meter_width,
    reading = str_glue("{first} ↔ {second}   ΔE ",
                       "{sprintf('%.1f', delta_e)}")
  )
worst <- slice_min(filter(views, view != "none"), delta_e, n = 1)
red_green <- delta_e(palette["red"], palette["green"])


# 5. Text ----------------------------------------------------------------------

title <- "The same four colours, <i>through four eyes</i>"
deck <- str_glue(
  "A streamgraph wrapped around a pupil, seen with typical colour vision and ",
  "as simulated for the three dichromacies, in which one type of cone gives ",
  "no colour signal. Under each eye, the closest pair of colours and their ",
  "CIEDE2000 difference: the lower ΔE is, the harder they are to tell ",
  "apart. Red and green, ΔE {sprintf('%.1f', red_green)} apart for ",
  "typical vision, fall to ΔE {sprintf('%.1f', worst$delta_e)} in ",
  "{str_to_lower(worst$title)}."
)
footnote <- str_glue(
  "DATA  stream.csv, R Graph Gallery  ·  PALETTE  CarolMan (suffrager)",
  "  ·  Full-severity simulations: Machado, Oliveira & Fernandes (2009), ",
  "colorspace\nMETER  dot = closest pair in that view, ",
  "tick = closest pair with typical vision."
)


# 6. Chart ---------------------------------------------------------------------

x_limits <- c(-1.25, max(views$centre_x) + 1.25)
y_limits <- c(-3.05, 2.85)

chart <- ggplot() +
  eyes +
  # Name and cones.
  geom_text(data = views,
            aes(x = centre_x, y = label_y, label = title),
            family = serif, fontface = "italic", size = 6.2, color = ui$ink,
            vjust = 1) +
  geom_text(data = views,
            aes(x = centre_x, y = label_y - 0.3, label = str_to_upper(cones)),
            family = mono_light, size = 2.25, color = ui$muted, vjust = 1) +
  # The four colours as seen.
  geom_point(data = swatches, aes(x = x, y = swatch_y, color = hex),
             size = 5.2) +
  geom_text(data = swatches,
            aes(x = x, y = swatch_y - 0.17, label = str_to_upper(hex)),
            family = mono_light, size = 1.75, color = ui$muted) +
  # ΔE meter: the tick marks typical vision, the dot this view.
  geom_segment(data = meters,
               aes(x = x0, xend = x1, y = meter_y, yend = meter_y),
               color = ui$rule, linewidth = 0.5) +
  geom_segment(data = meters,
               aes(x = reference, xend = reference,
                   y = meter_y - 0.05, yend = meter_y + 0.05),
               color = ui$muted, linewidth = 0.4) +
  geom_text(data = meters, aes(x = x0 - 0.05, y = meter_y, label = "0"),
            family = mono_light, size = 1.8, color = ui$muted, hjust = 1) +
  geom_text(data = meters, aes(x = x1 + 0.05, y = meter_y,
                               label = meter_max),
            family = mono_light, size = 1.8, color = ui$muted, hjust = 0) +
  geom_point(data = meters, aes(x = marker, y = meter_y),
             color = ui$ink, size = 2.2) +
  geom_text(data = meters, aes(x = centre_x, y = meter_y - 0.13,
                               label = str_to_upper(reading)),
            family = mono, size = 2.2, color = ui$ink, vjust = 1) +
  # Title block.
  annotate("richtext", x = x_limits[1], y = y_limits[2], label = title,
           family = serif, size = 15, color = ui$ink, hjust = 0, vjust = 1,
           fill = NA, label.color = NA, label.padding = unit(0, "pt")) +
  annotate("textbox", x = x_limits[1], y = y_limits[2] - 0.62, label = deck,
           family = serif, size = 4.6, color = ui$muted, hjust = 0, vjust = 1,
           width = unit(27, "cm"), fill = NA, box.color = NA,
           box.padding = unit(0, "pt"), lineheight = 1.25) +
  # Footer.
  annotate("text", x = x_limits[1], y = y_limits[1], label = footnote,
           family = mono_light, size = 1.95, color = ui$muted, hjust = 0,
           vjust = 0, lineheight = 1.5) +
  annotate("text", x = x_limits[2], y = y_limits[1],
           label = str_to_upper(author), family = mono, size = 2.1,
           color = ui$ink, hjust = 1, vjust = 0) +
  scale_fill_identity() +
  scale_color_identity() +
  scale_alpha_identity() +
  coord_equal(xlim = x_limits, ylim = y_limits, expand = FALSE,
              clip = "off") +
  theme_void() +
  theme(
    plot.background = element_rect(fill = ui$night, color = NA),
    plot.margin = margin(36, 44, 26, 44)
  )

ggsave("viz/color-vision-deficiency-comparison.png", chart,
       width = width_cm, height = height_cm, units = "cm", dpi = 300,
       device = ragg::agg_png, bg = ui$night)
