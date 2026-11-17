library(showtext)
library(sysfonts)
library(colorblindr)
library(cowplot)
library(ggstream)
library(ggplot2)
library(paletteer)

font_add_google("Poppins", "Poppins")
showtext_auto()

df <- read.csv("https://raw.githubusercontent.com/holtzy/R-graph-gallery/master/DATA/stream.csv")

theme_clean_axes <- theme_void() +
  theme(
    legend.position = "none",
    plot.title = element_text(
      hjust = 0.5, size = 40, margin = margin(b = 10),
      face = "bold", family = "Poppins"
    ),
    plot.margin = margin(6, 6, 6, 6),
    text = element_text(family = "Poppins")
  )

p1 <- ggplot(df, aes(x = year, y = value, fill = name)) +
  geom_stream(color = "black", linewidth = 0.15) +
  scale_fill_paletteer_d("suffrager::CarolMan") +
  theme_clean_axes +
  ggtitle("Normal color vision")

p2 <- ggplot(df, aes(x = year, y = value, fill = name)) +
  geom_stream(color = "black", linewidth = 0.15) +
  scale_fill_paletteer_d("suffrager::CarolMan") +
  theme_clean_axes +
  ggtitle("Protanopia (simulated)")
p2 <- edit_colors(p2, protan, severity = 1)

p3 <- ggplot(df, aes(x = year, y = value, fill = name)) +
  geom_stream(color = "black", linewidth = 0.15) +
  scale_fill_paletteer_d("suffrager::CarolMan") +
  theme_clean_axes +
  ggtitle("Deuteranopia (simulated)")
p3 <- edit_colors(p3, deutan, severity = 1)

p4 <- ggplot(df, aes(x = year, y = value, fill = name)) +
  geom_stream(color = "black", linewidth = 0.15) +
  scale_fill_paletteer_d("suffrager::CarolMan") +
  theme_clean_axes +
  ggtitle("Tritanopia (simulated)")
p4 <- edit_colors(p4, tritan, severity = 1)

final_plot <- plot_grid(p1, p2, p3, p4, ncol = 2)

dir.create("viz", showWarnings = FALSE)
ggsave("viz/color-vision-deficiency-comparison.png", final_plot,
       width = 10, height = 8, dpi = 300, bg = "white")
