# Autocorrelated Kernel Density Estimate (aKDE)

MoveApps

GitHub repository: https://github.com/movestore/ctmm_akde

<p align="center">
  <img alt="Screenshot of the Apps UI" src="readme_thumbnail.png" width="700">
</p>

## Description
Use a fitted continuous-time movement model (CTMM) to estimate the home
ranges of a set of tracked animals using autocorrelated kernel density
estimation (aKDE) and display them on an interactive map.

## Documentation
Autocorrelated kernel density estimates (aKDEs) are estimates of the range
distribution of range-resident animals. Unlike conventional kernel density
estimates, they take into account the autocorrelation of tracking data, using
the CTMM fitted to each animal.

This App calculates one utilization distribution (UD) per track in the input
data and plots them on a map. The isopleth level can be adjusted using the
App sliders, and the confidence bounds for each isopleth level can optionally
be displayed.

This App is part of a `ctmm` Workflow. You must run the *Fit a
Continuous-Time Movement Model (ctmm)* App before this one, as its output is
necessary to calculate the aKDE estimates.

See the [ctmm vignette on aKDEs][1] for more information on interpreting the
home range estimates.

[1]: https://cran.r-project.org/web/packages/ctmm/vignettes/akde.html

### Application scope
#### Generality of App usability
This App was developed for any taxonomic group that displays range-resident
behavior.

#### Required data properties
This App is only applicable to data that reflect range-resident behavior. Use
the *Variogram* App to evaluate whether this property holds for your data.

### Input type
`ctmm model with data`: a list with two elements:

1. A list containing the selected `ctmm` model for each animal.
2. The tracking data (an object of type `telemetry.list`).

### Output type
`ctmm UD with Data and Model`: a list with three elements:

1. `model`: the list of `ctmm` models from the input.
2. `uds`: a list containing the aKDE UD (an object of class `UD`) for each
   animal.
3. `data`: the tracking data from the input (an object of type
   `telemetry.list`).

### Artefacts
The artefacts reflect the **Isopleth level** selected in the App.

`homerange.gpkg`: a GeoPackage with the home range contours of all animals.
Each animal has three polygons: the estimate and the lower and upper bounds of
its 95% confidence interval. The `name` column identifies each polygon, e.g.
"Cilla 95% est", "Cilla 95% low" or "Cilla 95% high". The coordinates are in
the projection of the tracking data (in meters).

`akde_summary.csv`: the estimated home range area of each animal. It contains
the following columns:
  - `id`: the name of the animal.
  - `level`: the isopleth level.
  - `unit`: the unit of the home range area.
  - `low`, `est`, `high`: the estimated area and the lower and upper bounds of
    its 95% confidence interval.

`uds.zip`: a zip archive with one GeoTIFF file per animal (`<animal>.tif`)
containing its UD on a raster grid. Each cell's value represents the smallest
isopleth level whose home range contains that cell (e.g. cells inside the 50%
core area have values below 0.5). The coordinates are in the projection of the
tracking data.

### Settings
**Isopleth level**: The coverage level of the utilization distribution. This is
the smallest area in which the animal has a given probability of being found.
For example, a level of 0.5 gives the area with a 50% probability that the
animal will be found. Defaults to 0.95.

**What do you want to see?**: Which contours to draw on the map: "Lower CI",
"Estimate" and/or "Upper CI". The confidence interval contours are drawn as
dashed white lines. Defaults to "Estimate".

**Opacity**: The opacity of the filled home range estimates on the map, from 0
(transparent) to 1 (opaque). Defaults to 0.5.

**Add all animals to map** / **Remove all animals from map**: Shows or hides
the home ranges of all animals. Individual animals can be shown or hidden with
the layer menu in the top-right corner of the map.

**Store settings**: Click to store the current settings of the App for future
Workflow runs.

**Restore default settings**: Click to restore the App's default settings.

### Changes in output data
The App adds the aKDE UD of each animal to the input data (see
[Output type](#output-type)). The models and tracking data remain unchanged.

### Errors and null handling
**Contours:** If none of the options under **What do you want to see?** is
selected, no home ranges are shown on the map.

**Performance:** The UDs are calculated each time the App's window is opened.
For large data sets (many animals, or long tracks with frequent locations)
this can take a while.

**Access to the App's window:** The preceding *Fit a Continuous-Time Movement
Model (ctmm)* App can take a long time to run (up to hours). Like all Apps with
an interactive window, this App's window (the "OPEN APP UI" button) can only
be opened for 8 hours after the Workflow has run. To open it again later, the
Workflow has to be run again. To avoid fitting the models again, first pin the
Workflow to the *Fit a Continuous-Time Movement Model (ctmm)* App (menu at
the top-right corner of that App, *"Pin to this App"*). An App can only be
pinned once it has run and produced results.

### Technical details
The UDs are calculated with [`ctmm::akde()`][2], with all animals in a single
call and with the function's default settings. Each animal's UD is based on
its own fitted model.

The contours are calculated with `ctmm::SpatialPolygonsDataFrame.UD()` and the
areas with ctmm's `summary()` method for UDs, both at the selected isopleth
level. The rasters are written with ctmm's `writeRaster()` method for UDs.

The aKDE method is described in Fleming, C. H., Fagan, W. F., Mueller, T.,
Olson, K. A., Leimgruber, P., & Calabrese, J. M. (2015). Rigorous home range
estimation with movement data: A new autocorrelated kernel density estimator.
*Ecology*, 96(5), 1182–1188. https://doi.org/10.1890/14-2010.1

The `ctmm` package is described in Calabrese, J. M., Fleming, C. H., &
Gurarie, E. (2016). ctmm: An R package for analyzing animal relocation data as
a continuous-time stochastic process. *Methods in Ecology and Evolution*,
7(9), 1124–1132. https://doi.org/10.1111/2041-210X.12559

[2]: https://ctmm-initiative.github.io/ctmm/reference/akde.html
