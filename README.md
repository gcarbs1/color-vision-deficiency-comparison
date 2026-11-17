# Color vision deficiency comparison

## Summary

Draws the same streamgraph four times: once with its original palette and three times as it would look with each of the main types of dichromacy. The result is a single chart, `viz/color-vision-deficiency-comparison.png`:

- **Normal color vision.** The original palette, `suffrager::CarolMan`.
- **Protanopia.** No working long-wavelength (red) cones.
- **Deuteranopia.** No working medium-wavelength (green) cones.
- **Tritanopia.** No working short-wavelength (blue) cones.

Under protanopia and deuteranopia the red, orange and green layers collapse into similar olive tones, while blue stays distinct. Under tritanopia the palette shifts to reds and teals.

![Color vision deficiency comparison](viz/color-vision-deficiency-comparison.png)

## Method

- **Data.** The `stream.csv` example dataset from the [R Graph Gallery](https://r-graph-gallery.com/), read directly from its repository.
- **Chart.** A streamgraph built with ggstream, with a thin black outline between layers.
- **Simulation.** `colorblindr::edit_colors()` replaces every colour in the finished plot with its simulated version at full severity, using the protan, deutan and tritan transforms from colorspace.

## Structure

- `R/color-vision-deficiency-comparison.R`: the four panels, combined with cowplot.
- `viz/`: final chart.

## Running

The script runs from the project root. ggstream and colorblindr are installed from GitHub:

```bash
Rscript -e 'install.packages(c("colorspace", "cowplot", "ggplot2", "paletteer", "remotes", "showtext", "sysfonts"))'
Rscript -e 'remotes::install_github(c("davidsjoberg/ggstream", "clauswilke/colorblindr"))'
Rscript R/color-vision-deficiency-comparison.R
```

## References

- Machado, G. M., Oliveira, M. M. and Fernandes, L. A. F. (2009). [A physiologically-based model for simulation of color vision deficiency](https://doi.org/10.1109/TVCG.2009.113).
- Wilke, C. O. [colorblindr: simulate colorblindness in R figures](https://github.com/clauswilke/colorblindr).
