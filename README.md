# One palette, four ways of seeing it

## Summary

Draws the same streamgraph four times: with no colour vision deficiency and as simulated for the three dichromacies, in which one type of cone gives no colour signal. Under each panel, a strip shows the four colours as they are seen and the closest pair, measured with the CIEDE2000 colour difference (ΔE). The result is a single landscape chart (16:10), `viz/color-vision-deficiency-comparison.png`:

- **No colour vision deficiency.** The closest pair is red and orange, ΔE 30.7.
- **Protanopia** (no L cones). Red, orange and green turn into olive tones; red and green fall to ΔE 12.5.
- **Deuteranopia** (no M cones). The same collapse, stronger: red and green at ΔE 9.8, against 60.8 in the original palette.
- **Tritanopia** (no S cones). Green and blue become two teals, ΔE 16.3.

![One palette, four ways of seeing it](viz/color-vision-deficiency-comparison.png)

## Method

- **Data.** The `stream.csv` example dataset from the [R Graph Gallery](https://r-graph-gallery.com/): four groups over ten periods.
- **Palette.** CarolMan, from the suffrager package (available through paletteer): `#EE2617`, `#F2A241`, `#558934`, `#0E54B6`.
- **Simulation.** `protan()`, `deutan()` and `tritan()` from colorspace at full severity, which implement the Machado, Oliveira and Fernandes (2009) model. Simulations approximate typical colour confusions, not the perception of each person.
- **Colour difference.** CIEDE2000 between every pair of the four simulated colours, computed with farver. Each strip reports the smallest one.

## Structure

- `R/color-vision-deficiency-comparison.R`: simulations, colour differences and the chart, with ggplot2, ggstream, patchwork, ggtext and marquee.
- `data/processed/stream.csv`: the example dataset.
- `assets/fonts/`: Libre Baskerville, with its OFL licence.
- `viz/`: final chart.

## Running

The script runs from the project root. ggstream is installed from GitHub:

```bash
Rscript -e 'install.packages(c("colorspace", "dplyr", "farver", "ggplot2", "ggtext", "marquee", "patchwork", "purrr", "ragg", "readr", "remotes", "stringr", "systemfonts", "tidyr"))'
Rscript -e 'remotes::install_github("davidsjoberg/ggstream")'
Rscript R/color-vision-deficiency-comparison.R
```

## References

- Machado, G. M., Oliveira, M. M. and Fernandes, L. A. F. (2009). [A physiologically-based model for simulation of color vision deficiency](https://doi.org/10.1109/TVCG.2009.113).
- Sharma, G., Wu, W. and Dalal, E. N. (2005). [The CIEDE2000 color-difference formula](https://doi.org/10.1002/col.20070).
